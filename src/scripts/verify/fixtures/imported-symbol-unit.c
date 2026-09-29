#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <mach/mach.h>

static bool LHFailWrite;
static bool LHFailRestore;
static kern_return_t LHFixtureProtect(vm_map_t task, vm_address_t address,
                                      vm_size_t size, boolean_t maximum, vm_prot_t protection);
#define vm_protect LHFixtureProtect
#include "../../../runtime/hooks/LHHookBackendTheos.c"
#undef vm_protect

static kern_return_t LHFixtureProtect(vm_map_t task, vm_address_t address,
                                      vm_size_t size, boolean_t maximum, vm_prot_t protection) {
    if (LHFailWrite && (protection & VM_PROT_WRITE) != 0) return KERN_PROTECTION_FAILURE;
    if (LHFailRestore && (protection & VM_PROT_WRITE) == 0) {
        LHFailRestore = false;
        return KERN_PROTECTION_FAILURE;
    }
    return vm_protect(task, address, size, maximum, protection);
}

static int LHOriginal(void) { return 1; }
static int LHReplacement(void) { return 2; }

static vm_prot_t LHProtection(const void *pointer) {
    vm_address_t region = (vm_address_t)pointer;
    vm_size_t size;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    assert(vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64,
                          (vm_region_info_t)&info, &count, &object) == KERN_SUCCESS);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
    return info.protection;
}

static void LHCheckPointerWrites(void) {
    void **page = mmap(0, vm_page_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    assert(page != MAP_FAILED);
    page[0] = (void *)LHOriginal;
    assert(LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(page[0] == (void *)LHReplacement);
    assert(LHProtection(page) == (VM_PROT_READ | VM_PROT_WRITE));
    page[0] = (void *)LHOriginal;
    assert(mprotect(page, vm_page_size, PROT_READ) == 0);
    LHFailWrite = true;
    assert(!LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(page[0] == (void *)LHOriginal && LHProtection(page) == VM_PROT_READ);
    LHFailWrite = false;
    LHFailRestore = true;
    assert(!LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(page[0] == (void *)LHOriginal && LHProtection(page) == VM_PROT_READ);
    assert(LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(page[0] == (void *)LHReplacement && LHProtection(page) == VM_PROT_READ);
    assert(LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(!LHImportedSymbolWritePointer((void **)((uint8_t *)page + 1), (void *)LHReplacement));
    assert(mprotect(page, vm_page_size, PROT_NONE) == 0);
    assert(!LHImportedSymbolWritePointer(page, (void *)LHOriginal));
    assert(mprotect(page, vm_page_size, PROT_READ | PROT_WRITE) == 0);
    page[0] = 0;
    assert(!LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(mprotect(page, vm_page_size, PROT_READ | PROT_EXEC) == 0);
    assert(!LHImportedSymbolWritePointer(page, (void *)LHReplacement));
    assert(munmap(page, vm_page_size) == 0);
}

typedef struct LHFixtureImage {
    uint8_t *memory;
    size_t size;
    struct mach_header_64 *header;
    struct segment_command_64 *data;
    struct symtab_command *symtab;
    struct dysymtab_command *dysymtab;
    struct linkedit_data_command *fixups;
    struct dyld_info_command *dyldInfo;
} LHFixtureImage;

static void *LHAddCommand(LHFixtureImage *fixture, uint32_t type, uint32_t size) {
    struct load_command *command = (struct load_command *)((uint8_t *)(fixture->header + 1) + fixture->header->sizeofcmds);
    command->cmd = type;
    command->cmdsize = size;
    fixture->header->ncmds++;
    fixture->header->sizeofcmds += size;
    return command;
}

static LHFixtureImage LHMakeImage(bool chained) {
    LHFixtureImage fixture = { .size = vm_page_size * 3 };
    fixture.memory = mmap(0, fixture.size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    assert(fixture.memory != MAP_FAILED);
    fixture.header = (struct mach_header_64 *)fixture.memory;
    fixture.header->magic = MH_MAGIC_64;
    fixture.header->cputype = CPU_TYPE_ARM64;
    fixture.header->filetype = MH_DYLIB;
    struct segment_command_64 *text = LHAddCommand(&fixture, LC_SEGMENT_64, sizeof(*text));
    memcpy(text->segname, "__TEXT", 7);
    text->vmaddr = (uintptr_t)fixture.memory;
    text->vmsize = vm_page_size;
    text->filesize = vm_page_size;
    text->initprot = VM_PROT_READ | VM_PROT_EXECUTE;
    fixture.data = LHAddCommand(&fixture, LC_SEGMENT_64, sizeof(*fixture.data) + sizeof(struct section_64));
    memcpy(fixture.data->segname, "__DATA", 7);
    fixture.data->vmaddr = (uintptr_t)fixture.memory + vm_page_size;
    fixture.data->vmsize = vm_page_size;
    fixture.data->fileoff = vm_page_size;
    fixture.data->filesize = vm_page_size;
    fixture.data->initprot = VM_PROT_READ | VM_PROT_WRITE;
    fixture.data->nsects = 1;
    struct section_64 *section = (struct section_64 *)(fixture.data + 1);
    memcpy(section->segname, "__DATA", 7);
    memcpy(section->sectname, "__nl_symbol_ptr", 16);
    section->addr = fixture.data->vmaddr;
    section->size = sizeof(void *);
    section->flags = S_NON_LAZY_SYMBOL_POINTERS;
    struct segment_command_64 *linkedit = LHAddCommand(&fixture, LC_SEGMENT_64, sizeof(*linkedit));
    memcpy(linkedit->segname, SEG_LINKEDIT, sizeof(SEG_LINKEDIT));
    linkedit->vmaddr = (uintptr_t)fixture.memory + vm_page_size * 2;
    linkedit->vmsize = vm_page_size;
    linkedit->fileoff = vm_page_size * 2;
    linkedit->filesize = vm_page_size;
    if (chained) {
        fixture.fixups = LHAddCommand(&fixture, LC_DYLD_CHAINED_FIXUPS, sizeof(*fixture.fixups));
        fixture.fixups->dataoff = vm_page_size * 2;
        fixture.fixups->datasize = 256;
    } else {
        fixture.symtab = LHAddCommand(&fixture, LC_SYMTAB, sizeof(*fixture.symtab));
        fixture.symtab->symoff = vm_page_size * 2;
        fixture.symtab->nsyms = 1;
        fixture.symtab->stroff = vm_page_size * 2 + 32;
        fixture.symtab->strsize = 32;
        fixture.dysymtab = LHAddCommand(&fixture, LC_DYSYMTAB, sizeof(*fixture.dysymtab));
        fixture.dysymtab->indirectsymoff = vm_page_size * 2 + 64;
        fixture.dysymtab->nindirectsyms = 1;
        fixture.dyldInfo = LHAddCommand(&fixture, LC_DYLD_INFO_ONLY, sizeof(*fixture.dyldInfo));
        struct nlist_64 *symbol = (struct nlist_64 *)(fixture.memory + fixture.symtab->symoff);
        symbol->n_un.n_strx = 1;
        memcpy(fixture.memory + fixture.symtab->stroff + 1, "_test_symbol", 13);
    }
    *(void **)(fixture.memory + vm_page_size) = (void *)LHOriginal;
    return fixture;
}

static void LHResetSlot(LHFixtureImage *fixture) {
    assert(mprotect(fixture->memory + vm_page_size, vm_page_size, PROT_READ | PROT_WRITE) == 0);
    *(void **)(fixture->memory + vm_page_size) = (void *)LHOriginal;
}

static void LHCheckIndirect(void) {
    LHFixtureImage fixture = LHMakeImage(false);
    assert(mprotect(fixture.memory + vm_page_size, vm_page_size, PROT_READ) == 0);
    assert(LHImportedSymbolRebindImage((const struct mach_header *)fixture.header, 0));
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHReplacement);
    assert(LHProtection(fixture.memory + vm_page_size) == VM_PROT_READ);
    LHResetSlot(&fixture);
    struct section_64 *section = (struct section_64 *)(fixture.data + 1);
    section->reserved1 = UINT32_MAX;
    assert(!LHImportedSymbolRebindImage((const struct mach_header *)fixture.header, 0));
    section->reserved1 = 0;
    fixture.symtab->stroff = UINT32_MAX;
    assert(!LHImportedSymbolRebindImage((const struct mach_header *)fixture.header, 0));
    fixture.symtab->stroff = vm_page_size * 2 + 32;
    memset(fixture.memory + fixture.symtab->stroff, 'x', fixture.symtab->strsize);
    assert(!LHImportedSymbolRebindImage((const struct mach_header *)fixture.header, 0));
    memcpy(fixture.memory + fixture.symtab->stroff + 1, "_test_symbol", 13);
    fixture.data->cmdsize = 0;
    assert(!LHImportedSymbolRebindImage((const struct mach_header *)fixture.header, 0));
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHOriginal);
    munmap(fixture.memory, fixture.size);
}

static void LHCheckOpcodes(void) {
    LHFixtureImage fixture = LHMakeImage(false);
    LHImportedSymbolImage image;
    assert(LHImportedSymbolReadImage((const struct mach_header *)fixture.header, 0, &image));
    /* Binds a normal data pointer with no indirect section association. */
    const uint8_t stream[] = {
        BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM, '_','t','e','s','t','_','s','y','m','b','o','l',0,
        BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1, 0,
        BIND_OPCODE_DO_BIND, BIND_OPCODE_DONE
    };
    uint32_t offset = vm_page_size * 2 + 128;
    memcpy(fixture.memory + offset, stream, sizeof(stream));
    assert(LHImportedSymbolRebindOpcodes(&image, offset, sizeof(stream), false));
    LHResetSlot(&fixture);
    fixture.memory[offset + sizeof(stream) - 2] = BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB;
    memset(fixture.memory + offset + sizeof(stream) - 1, 0xff, 16);
    assert(!LHImportedSymbolRebindOpcodes(&image, offset, sizeof(stream) + 15, false));
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHOriginal);
    assert(!LHImportedSymbolRebindOpcodes(&image, UINT32_MAX, 32, false));
    const uint8_t overflow[] = {0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x02};
    const uint8_t *cursor = overflow;
    uint64_t value;
    assert(!LHImportedSymbolReadLEB(&cursor, overflow + sizeof(overflow), &value, false));
    cursor = overflow;
    assert(!LHImportedSymbolReadLEB(&cursor, overflow + sizeof(overflow), &value, true));
    munmap(fixture.memory, fixture.size);
}

static uint8_t *LHMakeChainFile(const LHFixtureImage *fixture) {
    uint8_t *file = malloc(fixture->size);
    assert(file != 0);
    memcpy(file, fixture->memory, fixture->size);
    uint8_t *data = file + fixture->fixups->dataoff;
    struct dyld_chained_fixups_header *fixups = (struct dyld_chained_fixups_header *)data;
    fixups->starts_offset = 32;
    fixups->imports_offset = 96;
    fixups->symbols_offset = 128;
    fixups->imports_count = 1;
    fixups->imports_format = DYLD_CHAINED_IMPORT;
    struct dyld_chained_starts_in_image *starts = (struct dyld_chained_starts_in_image *)(data + 32);
    starts->seg_count = 3;
    starts->seg_info_offset[1] = 16;
    struct dyld_chained_starts_in_segment *segment = (struct dyld_chained_starts_in_segment *)(data + 48);
    segment->size = offsetof(struct dyld_chained_starts_in_segment, page_start) + 2;
    segment->page_size = 16384;
    segment->pointer_format = DYLD_CHAINED_PTR_64_OFFSET;
    segment->segment_offset = vm_page_size;
    segment->page_count = 1;
    segment->page_start[0] = 0;
    memcpy(data + 128, "_test_symbol", 13);
    uint64_t bits = UINT64_C(1) << 63;
    memcpy(file + vm_page_size, &bits, 8);
    return file;
}

static void LHCheckChains(void) {
    LHFixtureImage fixture = LHMakeImage(true);
    LHImportedSymbolImage image;
    assert(LHImportedSymbolReadImage((const struct mach_header *)fixture.header, 0, &image));
    uint8_t *file = LHMakeChainFile(&fixture);
    size_t sliceSize;
    assert(LHImportedSymbolFileSlice(file, fixture.size, fixture.header, &sliceSize) == file);
    assert(sliceSize == fixture.size);
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHReplacement);
    LHResetSlot(&fixture);
    struct dyld_chained_fixups_header *fixups = (struct dyld_chained_fixups_header *)(file + fixture.fixups->dataoff);
    struct dyld_chained_starts_in_segment *starts = (struct dyld_chained_starts_in_segment *)((uint8_t *)fixups + 48);
    starts->pointer_format = DYLD_CHAINED_PTR_ARM64E_USERLAND;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    starts->pointer_format = DYLD_CHAINED_PTR_64;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    LHResetSlot(&fixture);
    starts->page_size = 4096;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    LHResetSlot(&fixture);
    starts->page_size = 16384;
    /* Multi-start pages and a rebase leading to a bind both retain their file links. */
    starts->size += 4;
    starts->page_start[0] = DYLD_CHAINED_PTR_START_MULTI | 1;
    uint16_t extraStarts[] = {0, DYLD_CHAINED_PTR_START_LAST | 16};
    memcpy((uint8_t *)starts + offsetof(struct dyld_chained_starts_in_segment, page_start) + 2, extraStarts, 4);
    uint64_t bits = UINT64_C(1) << 63;
    memcpy(file + vm_page_size + 16, &bits, 8);
    *(void **)(fixture.memory + vm_page_size + 16) = (void *)LHOriginal;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    assert(*(void **)(fixture.memory + vm_page_size + 16) == (void *)LHReplacement);
    LHResetSlot(&fixture);
    starts->page_start[0] = 0;
    bits = UINT64_C(4) << 51;
    memcpy(file + vm_page_size, &bits, 8);
    *(void **)(fixture.memory + vm_page_size + 16) = (void *)LHOriginal;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHOriginal);
    assert(*(void **)(fixture.memory + vm_page_size + 16) == (void *)LHReplacement);
    bits = UINT64_C(1) << 63;
    memcpy(file + vm_page_size, &bits, 8);
    starts->size -= 4;
    LHResetSlot(&fixture);
    fixups->imports_format = DYLD_CHAINED_IMPORT_ADDEND;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    LHResetSlot(&fixture);
    int32_t addend = 1;
    memcpy((uint8_t *)fixups + 100, &addend, 4);
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    memset((uint8_t *)fixups + 96, 0, 16);
    fixups->imports_format = DYLD_CHAINED_IMPORT_ADDEND64;
    assert(LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    LHResetSlot(&fixture);
    fixups->symbols_offset = UINT32_MAX;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    fixups->symbols_offset = 128;
    fixups->starts_offset = UINT32_MAX;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    fixups->starts_offset = 32;
    starts->page_start[0] = DYLD_CHAINED_PTR_START_MULTI | 1000;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    starts->page_start[0] = 0;
    fixups->symbols_format = 1;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    fixups->symbols_format = 0;
    fixups->imports_offset = 64;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.size));
    fixups->imports_offset = 96;
    assert(!LHImportedSymbolRebindChainedFile(&image, file, fixture.fixups->dataoff + 1));
    ((struct mach_header_64 *)file)->cpusubtype = 1;
    assert(LHImportedSymbolFileSlice(file, fixture.size, fixture.header, &sliceSize) == 0);
    ((struct mach_header_64 *)file)->cpusubtype = 0;
    size_t fatSize = fixture.size + 4096;
    uint8_t *fat = calloc(1, fatSize);
    assert(fat != 0);
    struct fat_header *fatHeader = (struct fat_header *)fat;
    fatHeader->magic = FAT_CIGAM;
    fatHeader->nfat_arch = OSSwapInt32(1);
    struct fat_arch *arch = (struct fat_arch *)(fatHeader + 1);
    arch->offset = OSSwapInt32(4096);
    arch->size = OSSwapInt32((uint32_t)fixture.size);
    memcpy(fat + 4096, file, fixture.size);
    assert(LHImportedSymbolFileSlice(fat, fatSize, fixture.header, &sliceSize) == fat + 4096);
    arch->offset = OSSwapInt32(UINT32_MAX);
    assert(LHImportedSymbolFileSlice(fat, fatSize, fixture.header, &sliceSize) == 0);
    assert(*(void **)(fixture.memory + vm_page_size) == (void *)LHOriginal);
    free(fat);
    free(file);
    munmap(fixture.memory, fixture.size);
}

int main(void) {
    LHCheckPointerWrites();
    LHImportedSymbolBindings[0] = (LHImportedSymbolBinding){ .target = (void *)LHOriginal, .replacement = (void *)LHReplacement };
    memcpy(LHImportedSymbolBindings[0].symbol, "test_symbol", 12);
    atomic_store(&LHImportedSymbolBindingCount, 1);
    LHCheckIndirect();
    LHCheckOpcodes();
    LHCheckChains();
    puts("Bounded parsers, file identity, unsupported fixups, and pointer protection failures passed.");
    return 0;
}
