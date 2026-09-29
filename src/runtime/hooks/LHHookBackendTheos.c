#include "LHHookBackend.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <libkern/OSByteOrder.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/fat.h>
#include <mach-o/fixup-chains.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <stddef.h>
#include <pthread.h>
#include <stdatomic.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

typedef void (*MSHookFunctionType)(void *target, void *replacement, void **original);
typedef void (*MSHookMessageExType)(Class targetClass, SEL selector, void *replacement, void **original);

typedef struct LHImportedSymbolBinding {
    char symbol[128];
    void *target;
    void *replacement;
    void *next;
    bool direct;
    _Atomic bool rebound;
} LHImportedSymbolBinding;

typedef struct LHDirectFunctionBinding {
    void *target;
    void *replacement;
    void *next;
} LHDirectFunctionBinding;

typedef struct LHTheosBackendContext {
    MSHookFunctionType hookFunction;
    MSHookMessageExType hookMessage;
    uint32_t registeredNoOpCount;
} LHTheosBackendContext;

static LHImportedSymbolBinding LHImportedSymbolBindings[128];
static _Atomic size_t LHImportedSymbolBindingCount;
static LHDirectFunctionBinding LHDirectFunctionBindings[128];
static size_t LHDirectFunctionBindingCount;
static bool LHImportedSymbolCallbackRegistered;
static _Thread_local bool LHImportedSymbolRescanning;
static pthread_mutex_t LHImportedSymbolWriteLock = PTHREAD_MUTEX_INITIALIZER;

/** Resolves MobileSubstrate entry points for the shared backend context. */
static LHTheosBackendContext LHTheosBackendSharedContext(void) {
    LHTheosBackendContext context = { 0 };
    context.hookFunction = (MSHookFunctionType)dlsym(RTLD_DEFAULT, "MSHookFunction");
    context.hookMessage = (MSHookMessageExType)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    return context;
}

/** Compares import-table symbol names while tolerating Mach-O leading underscores. */
static bool LHImportedSymbolNameMatches(const char *candidate, const char *expected) {
    if (candidate == 0 || expected == 0) {
        return false;
    }

    if (candidate[0] == '_') {
        candidate++;
    }
    return strcmp(candidate, expected) == 0;
}

/** Import-only adapters wrap the exported entry point, including its direct hooks. */
static LHImportedSymbolBinding *LHImportedSymbolFindBinding(const char *name) {
    size_t count = atomic_load_explicit(&LHImportedSymbolBindingCount, memory_order_acquire);
    LHImportedSymbolBinding *direct = 0;
    while (count != 0) {
        LHImportedSymbolBinding *binding = &LHImportedSymbolBindings[--count];
        if (LHImportedSymbolNameMatches(name, binding->symbol)) {
            if (!binding->direct) {
                return binding;
            }
            if (direct == 0) {
                direct = binding;
            }
        }
    }
    return direct;
}

/** Changes data pointers only, restoring the page's actual prior permissions. */
static bool LHImportedSymbolWritePointerLocked(void **slot, void *replacement) {
    if (slot == 0 || replacement == 0 || ((uintptr_t)slot % _Alignof(void *)) != 0) {
        return false;
    }

    vm_address_t region = (vm_address_t)slot;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t result = vm_region_64(mach_task_self(), &region, &regionSize,
                                         VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info,
                                         &infoCount, &object);
    if (object != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), object);
    }
    if (result != KERN_SUCCESS || region > (vm_address_t)slot ||
        (vm_address_t)slot - region > regionSize ||
        sizeof(void *) > regionSize - ((vm_address_t)slot - region) ||
        (info.protection & VM_PROT_READ) == 0 || (info.protection & VM_PROT_EXECUTE) != 0) {
        return false;
    }

    void *current = atomic_load_explicit((_Atomic(void *) *)slot, memory_order_acquire);
    if (current == replacement) {
        return true;
    }
    if (current == 0 || vm_page_size == 0) {
        return false;
    }

    vm_address_t page = (vm_address_t)slot & ~((vm_address_t)vm_page_size - 1);
    bool writable = (info.protection & VM_PROT_WRITE) != 0;
    if (!writable && vm_protect(mach_task_self(), page, vm_page_size, false,
                                     info.protection | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) {
        return false;
    }
    atomic_store_explicit((_Atomic(void *) *)slot, replacement, memory_order_release);
    if (!writable && vm_protect(mach_task_self(), page, vm_page_size, false,
                                     info.protection) != KERN_SUCCESS) {
        atomic_store_explicit((_Atomic(void *) *)slot, current, memory_order_release);
        (void)vm_protect(mach_task_self(), page, vm_page_size, false, info.protection);
        return false;
    }
    return true;
}

static bool LHImportedSymbolWritePointer(void **slot, void *replacement) {
    pthread_mutex_lock(&LHImportedSymbolWriteLock);
    bool written = LHImportedSymbolWritePointerLocked(slot, replacement);
    pthread_mutex_unlock(&LHImportedSymbolWriteLock);
    return written;
}

static bool LHImportedSymbolRange(uint64_t offset, uint64_t length, uint64_t size) {
    return offset <= size && length <= size - offset;
}

typedef struct LHImportedSymbolImage {
    const struct mach_header_64 *header;
    const struct segment_command_64 *segments[64];
    size_t segmentCount;
    const struct segment_command_64 *linkedit;
    const struct symtab_command *symtab;
    const struct dysymtab_command *dysymtab;
    const struct dyld_info_command *dyldInfo;
    const struct linkedit_data_command *fixups;
    const struct encryption_info_command_64 *encryption;
    intptr_t slide;
} LHImportedSymbolImage;

static bool LHImportedSymbolReadImage(const struct mach_header *header, intptr_t slide,
                                       LHImportedSymbolImage *image) {
    if (header == 0 || header->magic != MH_MAGIC_64) {
        return false;
    }
    const struct mach_header_64 *h = (const struct mach_header_64 *)header;
    if (h->sizeofcmds > 1024 * 1024 || h->ncmds > h->sizeofcmds / sizeof(struct load_command)) {
        return false;
    }
    *image = (LHImportedSymbolImage){ .header = h, .slide = slide };
    const uint8_t *commands = (const uint8_t *)(h + 1);
    size_t offset = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (!LHImportedSymbolRange(offset, sizeof(struct load_command), h->sizeofcmds)) {
            return false;
        }
        const struct load_command *command = (const struct load_command *)(commands + offset);
        if (command->cmdsize < sizeof(*command) || (command->cmdsize & 7) != 0 ||
            !LHImportedSymbolRange(offset, command->cmdsize, h->sizeofcmds)) {
            return false;
        }
        switch (command->cmd) {
            case LC_SEGMENT_64: {
                if (command->cmdsize < sizeof(struct segment_command_64) || image->segmentCount == 64) {
                    return false;
                }
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (!LHImportedSymbolRange(sizeof(*segment), (uint64_t)segment->nsects * sizeof(struct section_64), command->cmdsize) ||
                    segment->filesize > segment->vmsize || segment->vmaddr > UINTPTR_MAX - segment->vmsize) {
                    return false;
                }
                image->segments[image->segmentCount++] = segment;
                if (strncmp(segment->segname, SEG_LINKEDIT, sizeof(segment->segname)) == 0) {
                    image->linkedit = segment;
                }
                break;
            }
            case LC_SYMTAB:
                if (command->cmdsize < sizeof(struct symtab_command)) return false;
                image->symtab = (const struct symtab_command *)command;
                break;
            case LC_DYSYMTAB:
                if (command->cmdsize < sizeof(struct dysymtab_command)) return false;
                image->dysymtab = (const struct dysymtab_command *)command;
                break;
            case LC_DYLD_INFO:
            case LC_DYLD_INFO_ONLY:
                if (command->cmdsize < sizeof(struct dyld_info_command)) return false;
                image->dyldInfo = (const struct dyld_info_command *)command;
                break;
            case LC_DYLD_CHAINED_FIXUPS:
                if (command->cmdsize < sizeof(struct linkedit_data_command)) return false;
                image->fixups = (const struct linkedit_data_command *)command;
                break;
            case LC_ENCRYPTION_INFO_64:
                if (command->cmdsize < sizeof(struct encryption_info_command_64)) return false;
                image->encryption = (const struct encryption_info_command_64 *)command;
                break;
            default:
                break;
        }
        offset += command->cmdsize;
    }
    return offset == h->sizeofcmds;
}

static const uint8_t *LHImportedSymbolLinkedit(const LHImportedSymbolImage *image,
                                              uint32_t offset, uint64_t size) {
    if (image->linkedit == 0 || offset < image->linkedit->fileoff ||
        !LHImportedSymbolRange(offset - image->linkedit->fileoff, size, image->linkedit->filesize)) {
        return 0;
    }
    return (const uint8_t *)((uintptr_t)image->slide + image->linkedit->vmaddr + offset - image->linkedit->fileoff);
}

static bool LHImportedSymbolRebindSlot(const char *name, void **slot) {
    LHImportedSymbolBinding *binding = LHImportedSymbolFindBinding(name);
    if (binding == 0 || !LHImportedSymbolWritePointer(slot, binding->direct ? binding->target : binding->replacement)) return false;
    atomic_store_explicit(&binding->rebound, true, memory_order_relaxed);
    return true;
}

static bool LHImportedSymbolRebindIndirect(const LHImportedSymbolImage *image) {
    if (image->symtab == 0 || image->dysymtab == 0) {
        return false;
    }
    const struct symtab_command *sym = image->symtab;
    const struct dysymtab_command *dysym = image->dysymtab;
    const uint8_t *symbols = LHImportedSymbolLinkedit(image, sym->symoff, (uint64_t)sym->nsyms * sizeof(struct nlist_64));
    const char *strings = (const char *)LHImportedSymbolLinkedit(image, sym->stroff, sym->strsize);
    const uint8_t *indices = LHImportedSymbolLinkedit(image, dysym->indirectsymoff, (uint64_t)dysym->nindirectsyms * sizeof(uint32_t));
    if (symbols == 0 || strings == 0 || indices == 0) {
        return false;
    }
    bool rebound = false;
    for (size_t s = 0; s < image->segmentCount; s++) {
        const struct segment_command_64 *segment = image->segments[s];
        if ((segment->initprot & VM_PROT_EXECUTE) != 0 || strncmp(segment->segname, "__AUTH", 6) == 0) continue;
        const struct section_64 *sections = (const struct section_64 *)(segment + 1);
        for (uint32_t j = 0; j < segment->nsects; j++) {
            const struct section_64 *section = &sections[j];
            uint32_t type = section->flags & SECTION_TYPE;
            if ((type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS) ||
                section->addr < segment->vmaddr || section->size % sizeof(void *) != 0 ||
                !LHImportedSymbolRange(section->addr - segment->vmaddr, section->size, segment->vmsize)) continue;
            size_t count = section->size / sizeof(void *);
            if (!LHImportedSymbolRange(section->reserved1, count, dysym->nindirectsyms)) continue;
            void **slots = (void **)((uintptr_t)image->slide + section->addr);
            for (size_t i = 0; i < count; i++) {
                uint32_t index;
                memcpy(&index, indices + ((size_t)section->reserved1 + i) * sizeof(index), sizeof(index));
                if ((index & (INDIRECT_SYMBOL_ABS | INDIRECT_SYMBOL_LOCAL)) != 0 || index >= sym->nsyms) continue;
                struct nlist_64 symbol;
                memcpy(&symbol, symbols + (size_t)index * sizeof(symbol), sizeof(symbol));
                uint32_t nameOffset = symbol.n_un.n_strx;
                if (nameOffset >= sym->strsize || memchr(strings + nameOffset, 0, sym->strsize - nameOffset) == 0) continue;
                rebound = LHImportedSymbolRebindSlot(strings + nameOffset, &slots[i]) || rebound;
            }
        }
    }
    return rebound;
}

static bool LHImportedSymbolReadLEB(const uint8_t **cursor, const uint8_t *end,
                                    uint64_t *value, bool signedValue) {
    *value = 0;
    for (unsigned shift = 0; shift < 64 && *cursor < end; shift += 7) {
        uint8_t byte = *(*cursor)++;
        if (shift == 63 && (byte & 0x7f) > (signedValue ? 0x7f : 1)) return false;
        if (shift == 63 && signedValue && (byte & 0x7f) != 0 && (byte & 0x7f) != 0x7f) return false;
        *value |= (uint64_t)(byte & 0x7f) << shift;
        if ((byte & 0x80) == 0) {
            if (signedValue && (byte & 0x40) != 0 && shift < 57) *value |= UINT64_MAX << (shift + 7);
            return true;
        }
    }
    return false;
}

/** Classic bind streams also describe imports outside indirect-pointer sections. */
static bool LHImportedSymbolRebindOpcodes(const LHImportedSymbolImage *image,
                                          uint32_t fileOffset, uint32_t size, bool lazy) {
    const uint8_t *cursor = LHImportedSymbolLinkedit(image, fileOffset, size);
    if (cursor == 0 || size == 0) return false;
    const uint8_t *end = cursor + size;
    const char *name = 0;
    size_t segmentIndex = SIZE_MAX;
    uint64_t offset = 0, addend = 0;
    uint8_t type = BIND_TYPE_POINTER;
    bool rebound = false;
    while (cursor < end) {
        uint8_t byte = *cursor++;
        uint8_t opcode = byte & BIND_OPCODE_MASK;
        uint8_t immediate = byte & BIND_IMMEDIATE_MASK;
        uint64_t value = 0, count = 1, skip = 0;
        switch (opcode) {
            case BIND_OPCODE_DONE:
                if (!lazy) return rebound;
                name = 0; segmentIndex = SIZE_MAX; offset = 0; addend = 0; type = BIND_TYPE_POINTER;
                continue;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                continue;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                if (!LHImportedSymbolReadLEB(&cursor, end, &value, false)) return rebound;
                continue;
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM: {
                const uint8_t *terminator = memchr(cursor, 0, (size_t)(end - cursor));
                if (terminator == 0) return rebound;
                name = (const char *)cursor;
                cursor = terminator + 1;
                continue;
            }
            case BIND_OPCODE_SET_TYPE_IMM:
                type = immediate;
                continue;
            case BIND_OPCODE_SET_ADDEND_SLEB:
                if (!LHImportedSymbolReadLEB(&cursor, end, &addend, true)) return rebound;
                continue;
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
                segmentIndex = immediate;
                if (!LHImportedSymbolReadLEB(&cursor, end, &offset, false)) return rebound;
                continue;
            case BIND_OPCODE_ADD_ADDR_ULEB:
                if (!LHImportedSymbolReadLEB(&cursor, end, &value, false) || offset > UINT64_MAX - value) return rebound;
                offset += value;
                continue;
            case BIND_OPCODE_DO_BIND:
                break;
            case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                if (!LHImportedSymbolReadLEB(&cursor, end, &skip, false)) return rebound;
                break;
            case BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED:
                skip = immediate * sizeof(void *);
                break;
            case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB:
                if (!LHImportedSymbolReadLEB(&cursor, end, &count, false) ||
                    !LHImportedSymbolReadLEB(&cursor, end, &skip, false)) return rebound;
                break;
            default:
                return rebound; /* Threaded arm64e binding requires pointer authentication. */
        }
        if (segmentIndex >= image->segmentCount || skip > UINT64_MAX - sizeof(void *)) return rebound;
        const struct segment_command_64 *segment = image->segments[segmentIndex];
        uint64_t stride = sizeof(void *) + skip;
        if (offset > segment->vmsize || (count != 0 &&
            (segment->vmsize - offset < sizeof(void *) ||
             count - 1 > (segment->vmsize - offset - sizeof(void *)) / stride))) return rebound;
        for (uint64_t i = 0; i < count; i++) {
            if (name != 0 && type == BIND_TYPE_POINTER && addend == 0 &&
                (segment->initprot & VM_PROT_EXECUTE) == 0 && strncmp(segment->segname, "__AUTH", 6) != 0) {
                void **slot = (void **)((uintptr_t)image->slide + segment->vmaddr + offset);
                rebound = LHImportedSymbolRebindSlot(name, slot) || rebound;
            }
            if (offset > UINT64_MAX - stride) return rebound;
            offset += stride;
        }
    }
    return rebound;
}

/** Match the exact Mach-O slice, including load commands, before using file chains. */
static const uint8_t *LHImportedSymbolFileSlice(const uint8_t *file, size_t size,
                                               const struct mach_header_64 *header, size_t *sliceSize) {
    if (size < sizeof(uint32_t)) return 0;
    uint32_t magic;
    memcpy(&magic, file, sizeof(magic));
    if (magic == MH_MAGIC_64) {
        size_t headerSize = sizeof(*header) + header->sizeofcmds;
        if (!LHImportedSymbolRange(0, headerSize, size) || memcmp(file, header, headerSize) != 0) return 0;
        *sliceSize = size;
        return file;
    }
    bool fat64 = magic == FAT_MAGIC_64 || magic == FAT_CIGAM_64;
    bool swapped = magic == FAT_CIGAM || magic == FAT_CIGAM_64;
    if ((!fat64 && magic != FAT_MAGIC && magic != FAT_CIGAM) || size < sizeof(struct fat_header)) return 0;
    const struct fat_header *fat = (const struct fat_header *)file;
    uint32_t count = swapped ? OSSwapInt32(fat->nfat_arch) : fat->nfat_arch;
    size_t entrySize = fat64 ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
    if (!LHImportedSymbolRange(sizeof(*fat), (uint64_t)count * entrySize, size)) return 0;
    for (uint32_t i = 0; i < count; i++) {
        const uint8_t *entry = file + sizeof(*fat) + (size_t)i * entrySize;
        uint64_t offset, length;
        if (fat64) {
            struct fat_arch_64 arch;
            memcpy(&arch, entry, sizeof(arch));
            offset = swapped ? OSSwapInt64(arch.offset) : arch.offset;
            length = swapped ? OSSwapInt64(arch.size) : arch.size;
        } else {
            struct fat_arch arch;
            memcpy(&arch, entry, sizeof(arch));
            offset = swapped ? OSSwapInt32(arch.offset) : arch.offset;
            length = swapped ? OSSwapInt32(arch.size) : arch.size;
        }
        if (!LHImportedSymbolRange(offset, length, size) || length < sizeof(*header)) continue;
        size_t headerSize = sizeof(*header) + header->sizeofcmds;
        if (LHImportedSymbolRange(0, headerSize, length) && memcmp(file + offset, header, headerSize) == 0) {
            *sliceSize = (size_t)length;
            return file + offset;
        }
    }
    return 0;
}

static bool LHImportedSymbolChainName(const uint8_t *data, size_t size,
                                       const struct dyld_chained_fixups_header *fixups,
                                       uint32_t ordinal, const char **name) {
    size_t entrySize;
    switch (fixups->imports_format) {
        case DYLD_CHAINED_IMPORT: entrySize = 4; break;
        case DYLD_CHAINED_IMPORT_ADDEND: entrySize = 8; break;
        case DYLD_CHAINED_IMPORT_ADDEND64: entrySize = 16; break;
        default: return false;
    }
    uint64_t entryOffset = (uint64_t)fixups->imports_offset + (uint64_t)ordinal * entrySize;
    if (ordinal >= fixups->imports_count || !LHImportedSymbolRange(entryOffset, entrySize, size)) return false;
    uint64_t nameOffset;
    if (entrySize == 16) {
        uint64_t bits, addend;
        memcpy(&bits, data + entryOffset, 8);
        memcpy(&addend, data + entryOffset + 8, 8);
        if (addend != 0) return false;
        nameOffset = bits >> 32;
    } else {
        uint32_t bits;
        memcpy(&bits, data + entryOffset, 4);
        if (entrySize == 8) {
            int32_t addend;
            memcpy(&addend, data + entryOffset + 4, 4);
            if (addend != 0) return false;
        }
        nameOffset = bits >> 9;
    }
    nameOffset += fixups->symbols_offset;
    if (nameOffset >= size || memchr(data + nameOffset, 0, size - (size_t)nameOffset) == 0) return false;
    *name = (const char *)data + nameOffset;
    return true;
}

static bool LHImportedSymbolRebindChain(const LHImportedSymbolImage *image,
                                        const uint8_t *file, size_t fileSize,
                                        const struct segment_command_64 *segment,
                                        uint64_t pageOffset, uint16_t start, uint16_t pageSize,
                                        const uint8_t *data, size_t dataSize,
                                        const struct dyld_chained_fixups_header *fixups) {
    bool rebound = false;
    uint64_t offset = start;
    while (LHImportedSymbolRange(offset, sizeof(uint64_t), pageSize)) {
        uint64_t segmentOffset = pageOffset + offset;
        if (!LHImportedSymbolRange(segmentOffset, 8, segment->filesize) ||
            !LHImportedSymbolRange(segment->fileoff, segment->filesize, fileSize)) break;
        uint64_t fileOffset = segment->fileoff + segmentOffset;
        if (image->encryption != 0 && image->encryption->cryptid != 0 &&
            fileOffset < (uint64_t)image->encryption->cryptoff + image->encryption->cryptsize &&
            fileOffset + 8 > image->encryption->cryptoff) break;
        uint64_t bits;
        memcpy(&bits, file + fileOffset, 8);
        if ((bits >> 63) != 0 && ((bits >> 24) & 0x7ffffff) == 0) {
            const char *name;
            if (LHImportedSymbolChainName(data, dataSize, fixups, bits & 0xffffff, &name)) {
                void **slot = (void **)((uintptr_t)image->slide + segment->vmaddr + segmentOffset);
                rebound = LHImportedSymbolRebindSlot(name, slot) || rebound;
            }
        }
        uint64_t next = (bits >> 51) & 0xfff;
        if (next == 0) break;
        offset += next * 4;
    }
    return rebound;
}

/** Live pointers no longer contain chain links; traverse the verified file instead. */
static bool LHImportedSymbolRebindChainedFile(const LHImportedSymbolImage *image,
                                              const uint8_t *file, size_t fileSize) {
    const struct linkedit_data_command *command = image->fixups;
    if (command == 0 || !LHImportedSymbolRange(command->dataoff, command->datasize, fileSize) ||
        command->datasize < sizeof(struct dyld_chained_fixups_header)) return false;
    const uint8_t *data = file + command->dataoff;
    size_t size = command->datasize;
    struct dyld_chained_fixups_header fixups;
    memcpy(&fixups, data, sizeof(fixups));
    size_t importSize;
    switch (fixups.imports_format) {
        case DYLD_CHAINED_IMPORT: importSize = 4; break;
        case DYLD_CHAINED_IMPORT_ADDEND: importSize = 8; break;
        case DYLD_CHAINED_IMPORT_ADDEND64: importSize = 16; break;
        default: return false;
    }
    if (fixups.fixups_version != 0 || fixups.symbols_format != 0 ||
        fixups.starts_offset < sizeof(fixups) || fixups.symbols_offset > size ||
        !LHImportedSymbolRange(fixups.imports_offset, (uint64_t)fixups.imports_count * importSize, fixups.symbols_offset) ||
        !LHImportedSymbolRange(fixups.starts_offset, sizeof(uint32_t), fixups.imports_offset)) return false;
    uint32_t segmentCount;
    memcpy(&segmentCount, data + fixups.starts_offset, 4);
    if (segmentCount > image->segmentCount ||
        !LHImportedSymbolRange(fixups.starts_offset, 4 + (uint64_t)segmentCount * 4, fixups.imports_offset)) return false;
    bool rebound = false;
    for (uint32_t s = 0; s < segmentCount; s++) {
        uint32_t relative;
        memcpy(&relative, data + fixups.starts_offset + 4 + (size_t)s * 4, 4);
        if (relative == 0) continue;
        uint64_t offset = (uint64_t)fixups.starts_offset + relative;
        size_t prefix = offsetof(struct dyld_chained_starts_in_segment, page_start);
        if (relative < 4 + (uint64_t)segmentCount * 4 ||
            !LHImportedSymbolRange(offset, prefix, fixups.imports_offset)) continue;
        struct dyld_chained_starts_in_segment starts = { 0 };
        memcpy(&starts, data + offset, prefix);
        const struct segment_command_64 *segment = image->segments[s];
        if ((starts.pointer_format != DYLD_CHAINED_PTR_64 && starts.pointer_format != DYLD_CHAINED_PTR_64_OFFSET) ||
            (starts.page_size != 4096 && starts.page_size != 16384) ||
            starts.size < prefix || (starts.size - prefix) % 2 != 0 ||
            !LHImportedSymbolRange(offset, starts.size, fixups.imports_offset) ||
            !LHImportedSymbolRange(prefix, (uint64_t)starts.page_count * 2, starts.size) ||
            starts.page_count > segment->vmsize / starts.page_size + (segment->vmsize % starts.page_size != 0) ||
            (segment->initprot & VM_PROT_EXECUTE) != 0 ||
            (uintptr_t)image->header != (uintptr_t)image->slide + segment->vmaddr - starts.segment_offset) continue;
        size_t startCount = (starts.size - prefix) / 2;
        for (uint32_t p = 0; p < starts.page_count; p++) {
            uint16_t start;
            memcpy(&start, data + offset + prefix + (size_t)p * 2, 2);
            if (start == DYLD_CHAINED_PTR_START_NONE) continue;
            uint64_t pageOffset = (uint64_t)p * starts.page_size;
            if ((start & DYLD_CHAINED_PTR_START_MULTI) == 0) {
                rebound = LHImportedSymbolRebindChain(image, file, fileSize, segment, pageOffset, start,
                                                       starts.page_size, data, size, &fixups) || rebound;
            } else {
                size_t index = start & ~DYLD_CHAINED_PTR_START_MULTI;
                while (index < startCount) {
                    memcpy(&start, data + offset + prefix + index++ * 2, 2);
                    rebound = LHImportedSymbolRebindChain(image, file, fileSize, segment, pageOffset,
                                                           start & ~DYLD_CHAINED_PTR_START_LAST,
                                                           starts.page_size, data, size, &fixups) || rebound;
                    if ((start & DYLD_CHAINED_PTR_START_LAST) != 0) break;
                }
            }
        }
    }
    return rebound;
}

static bool LHImportedSymbolRebindChained(const LHImportedSymbolImage *image) {
    if ((image->header->flags & MH_DYLIB_IN_CACHE) != 0) return false;
    Dl_info info;
    if (dladdr(image->header, &info) == 0 || info.dli_fname == 0) return false;
    int fd = open(info.dli_fname, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return false;
    struct stat status;
    if (fstat(fd, &status) != 0 || !S_ISREG(status.st_mode) || status.st_size <= 0 || (uint64_t)status.st_size > SIZE_MAX) {
        close(fd);
        return false;
    }
    size_t size = (size_t)status.st_size;
    const uint8_t *file = mmap(0, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (file == MAP_FAILED) return false;
    size_t sliceSize = 0;
    const uint8_t *slice = LHImportedSymbolFileSlice(file, size, image->header, &sliceSize);
    bool rebound = slice != 0 && LHImportedSymbolRebindChainedFile(image, slice, sliceSize);
    munmap((void *)file, size);
    return rebound;
}

static bool LHImportedSymbolRebindImage(const struct mach_header *header, intptr_t slide) {
    LHImportedSymbolImage image;
    if (!LHImportedSymbolReadImage(header, slide, &image)) return false;
    if (image.fixups != 0) return LHImportedSymbolRebindChained(&image);
    bool rebound = LHImportedSymbolRebindIndirect(&image);
    if (image.dyldInfo != 0) {
        rebound = LHImportedSymbolRebindOpcodes(&image, image.dyldInfo->bind_off, image.dyldInfo->bind_size, false) || rebound;
        rebound = LHImportedSymbolRebindOpcodes(&image, image.dyldInfo->weak_bind_off, image.dyldInfo->weak_bind_size, false) || rebound;
        rebound = LHImportedSymbolRebindOpcodes(&image, image.dyldInfo->lazy_bind_off, image.dyldInfo->lazy_bind_size, true) || rebound;
    }
    return rebound;
}

/** dyld invokes this after fixups, including for already loaded images at registration. */
static void LHImportedSymbolRebindImageCallback(const struct mach_header *header, intptr_t slide) {
    (void)LHImportedSymbolRebindImage(header, slide);
}

/** Registration supplies a dyld-locked snapshot; these bounded callbacks then sleep. */
static void LHImportedSymbolRescanImageCallback(const struct mach_header *header, intptr_t slide) {
    if (LHImportedSymbolRescanning) (void)LHImportedSymbolRebindImage(header, slide);
}

/** MobileSubstrate function-hook adapter. */
static bool LHTheosHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || context->hookFunction == 0 || target == 0 || replacement == 0 || target == replacement) {
        return false;
    }
    for (size_t i = 0; i < LHDirectFunctionBindingCount; i++) {
        const LHDirectFunctionBinding *existing = &LHDirectFunctionBindings[i];
        if (existing->target == target && existing->replacement == replacement) {
            if (original != 0 && *original == 0) *original = existing->next;
            return true;
        }
    }
    if (LHDirectFunctionBindingCount == sizeof(LHDirectFunctionBindings) / sizeof(LHDirectFunctionBindings[0])) return false;
    context->hookFunction(target, replacement, original);
    LHDirectFunctionBindings[LHDirectFunctionBindingCount++] = (LHDirectFunctionBinding){ target, replacement, original != 0 ? *original : 0 };
    return true;
}

/** Imported-symbol hook adapter backed by local Mach-O rebinding. */
static bool LHTheosHookImportedSymbol(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    (void)backend;
    size_t count = atomic_load_explicit(&LHImportedSymbolBindingCount, memory_order_acquire);
    if (symbol == 0 || symbol[0] == '\0' || replacement == 0 ||
        strlen(symbol) >= sizeof(LHImportedSymbolBindings[0].symbol)) {
        return false;
    }
    for (size_t i = 0; i < count; i++) {
        LHImportedSymbolBinding *existing = &LHImportedSymbolBindings[i];
        if (strcmp(symbol, existing->symbol) == 0 && replacement == existing->replacement) {
            if (original != 0 && *original == 0) *original = existing->next;
            return existing->direct || atomic_load_explicit(&existing->rebound, memory_order_relaxed);
        }
    }
    if (count >= sizeof(LHImportedSymbolBindings) / sizeof(LHImportedSymbolBindings[0])) return false;
    void *target = dlsym(RTLD_DEFAULT, symbol);
    if (target == 0 || target == replacement) return false;
    bool direct = false;
    for (size_t i = 0; i < LHDirectFunctionBindingCount; i++) {
        if (LHDirectFunctionBindings[i].target == target && LHDirectFunctionBindings[i].replacement == replacement) direct = true;
    }
    const LHImportedSymbolBinding *previous = 0;
    for (size_t i = count; i != 0; i--) {
        const LHImportedSymbolBinding *candidate = &LHImportedSymbolBindings[i - 1];
        if (!candidate->direct && strcmp(symbol, candidate->symbol) == 0) {
            previous = candidate;
            break;
        }
    }
    /* Preserve substrate trampolines: replacing one with an import adapter can cycle. */
    if (!direct && original != 0 && (*original == 0 || *original == target)) {
        *original = previous != 0 ? previous->replacement : target;
    }
    LHImportedSymbolBinding *binding = &LHImportedSymbolBindings[count];
    *binding = (LHImportedSymbolBinding){ .target = target, .replacement = replacement,
                                         .next = original != 0 ? *original : 0, .direct = direct };
    memcpy(binding->symbol, symbol, strlen(symbol) + 1);
    atomic_store_explicit(&LHImportedSymbolBindingCount, count + 1, memory_order_release);
    if (!LHImportedSymbolCallbackRegistered) {
        LHImportedSymbolCallbackRegistered = true;
        _dyld_register_func_for_add_image(LHImportedSymbolRebindImageCallback);
    } else {
        bool rescanning = LHImportedSymbolRescanning;
        LHImportedSymbolRescanning = true;
        _dyld_register_func_for_add_image(LHImportedSymbolRescanImageCallback);
        LHImportedSymbolRescanning = rescanning;
    }
    return direct || atomic_load_explicit(&binding->rebound, memory_order_relaxed);
}

/** MobileSubstrate Objective-C method-hook adapter. */
static bool LHTheosHookMessage(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || context->hookMessage == 0 || targetClass == 0 || selector == 0 || replacement == 0) {
        return false;
    }

    context->hookMessage(targetClass, selector, replacement, original);
    return true;
}

/** Records a no-op installation for an enabled module with no active hook. */
static bool LHTheosRegisterNoOp(LHHookBackend *backend, uint32_t moduleID) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || moduleID == 0) {
        return false;
    }

    context->registeredNoOpCount++;
    return true;
}

/** Creates a hook backend backed by Theos/MobileSubstrate primitives. */
LHHookBackend LHHookBackendCreateTheos(void) {
    static LHTheosBackendContext context;
    static bool initialized;
    if (!initialized) {
        context = LHTheosBackendSharedContext();
        initialized = true;
    }

    static const LHHookBackendVTable vtable = {
        .hookFunction = LHTheosHookFunction,
        .hookImportedSymbol = LHTheosHookImportedSymbol,
        .hookMessage = LHTheosHookMessage,
        .registerNoOp = LHTheosRegisterNoOp
    };

    LHHookBackend backend = {
        .vtable = &vtable,
        .context = &context
    };
    return backend;
}
