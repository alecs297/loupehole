#include "LHHookBackend.h"

#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <string.h>

typedef void (*MSHookFunctionType)(void *target, void *replacement, void **original);
typedef void (*MSHookMessageExType)(Class targetClass, SEL selector, void *replacement, void **original);

typedef struct LHImportedSymbolBinding {
    const char *symbol;
    void *replacement;
    void **original;
} LHImportedSymbolBinding;

typedef struct LHTheosBackendContext {
    MSHookFunctionType hookFunction;
    MSHookMessageExType hookMessage;
    uint32_t registeredNoOpCount;
} LHTheosBackendContext;

static LHImportedSymbolBinding LHImportedSymbolBindings[128];
static size_t LHImportedSymbolBindingCount;
static bool LHImportedSymbolCallbackRegistered;

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

/** Captures the original imported symbol pointer before rebinding. */
static void LHImportedSymbolStoreOriginal(const LHImportedSymbolBinding *binding, void *current) {
    if (binding->original != 0 && *binding->original == 0 && current != binding->replacement) {
        *binding->original = current;
    }
}

/** Writes an import pointer after temporarily relaxing page protections. */
static bool LHImportedSymbolWritePointer(void **slot, void *replacement, bool restoreReadOnly) {
    if (slot == 0 || *slot == replacement) {
        return false;
    }

    vm_size_t pageSize = 0;
    host_page_size(mach_host_self(), &pageSize);
    if (pageSize == 0) {
        pageSize = 16384;
    }

    vm_address_t page = (vm_address_t)slot & ~((vm_address_t)pageSize - 1);
    if (vm_protect(mach_task_self(), page, pageSize, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) {
        return false;
    }

    *slot = replacement;

    if (restoreReadOnly) {
        (void)vm_protect(mach_task_self(), page, pageSize, false, VM_PROT_READ);
    }
    return true;
}

/** Rebinds matching indirect symbol pointers within one Mach-O section. */
static bool LHImportedSymbolRebindSection(const struct section_64 *section,
                                          const struct nlist_64 *symbolTable,
                                          uint32_t symbolCount,
                                          const char *stringTable,
                                          const uint32_t *indirectSymbolTable,
                                          intptr_t slide,
                                          const LHImportedSymbolBinding *binding) {
    if (section == 0 || symbolTable == 0 || stringTable == 0 || indirectSymbolTable == 0 || binding == 0) {
        return false;
    }

    uint32_t sectionType = section->flags & SECTION_TYPE;
    if (sectionType != S_LAZY_SYMBOL_POINTERS && sectionType != S_NON_LAZY_SYMBOL_POINTERS) {
        return false;
    }

    bool restoreReadOnly = strncmp(section->segname, "__DATA_CONST", sizeof(section->segname)) == 0 ||
                           strncmp(section->segname, "__AUTH_CONST", sizeof(section->segname)) == 0;
    void **indirectPointers = (void **)(slide + section->addr);
    size_t pointerCount = section->size / sizeof(void *);
    bool rebound = false;

    for (size_t i = 0; i < pointerCount; i++) {
        uint32_t symbolIndex = indirectSymbolTable[section->reserved1 + i];
        if ((symbolIndex & INDIRECT_SYMBOL_ABS) != 0 ||
            (symbolIndex & INDIRECT_SYMBOL_LOCAL) != 0 ||
            symbolIndex >= symbolCount) {
            continue;
        }

        const char *symbolName = stringTable + symbolTable[symbolIndex].n_un.n_strx;
        if (!LHImportedSymbolNameMatches(symbolName, binding->symbol)) {
            continue;
        }

        LHImportedSymbolStoreOriginal(binding, indirectPointers[i]);
        rebound = LHImportedSymbolWritePointer(&indirectPointers[i], binding->replacement, restoreReadOnly) || rebound;
    }

    return rebound;
}

/** Rebinds matching imported symbols in one loaded Mach-O image. */
static bool LHImportedSymbolRebindImage(const struct mach_header *header,
                                        intptr_t slide,
                                        const LHImportedSymbolBinding *binding) {
    if (header == 0 || binding == 0 || header->magic != MH_MAGIC_64) {
        return false;
    }

    const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;
    const struct load_command *command = (const struct load_command *)(header64 + 1);
    const struct segment_command_64 *linkeditSegment = 0;
    const struct symtab_command *symtab = 0;
    const struct dysymtab_command *dysymtab = 0;

    for (uint32_t i = 0; i < header64->ncmds; i++) {
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            if (strncmp(segment->segname, SEG_LINKEDIT, sizeof(segment->segname)) == 0) {
                linkeditSegment = segment;
            }
        } else if (command->cmd == LC_SYMTAB) {
            symtab = (const struct symtab_command *)command;
        } else if (command->cmd == LC_DYSYMTAB) {
            dysymtab = (const struct dysymtab_command *)command;
        }
        command = (const struct load_command *)((const uint8_t *)command + command->cmdsize);
    }

    if (linkeditSegment == 0 || symtab == 0 || dysymtab == 0) {
        return false;
    }

    uintptr_t linkeditBase = (uintptr_t)slide + linkeditSegment->vmaddr - linkeditSegment->fileoff;
    const struct nlist_64 *symbolTable = (const struct nlist_64 *)(linkeditBase + symtab->symoff);
    const char *stringTable = (const char *)(linkeditBase + symtab->stroff);
    const uint32_t *indirectSymbolTable = (const uint32_t *)(linkeditBase + dysymtab->indirectsymoff);

    command = (const struct load_command *)(header64 + 1);
    bool rebound = false;
    for (uint32_t i = 0; i < header64->ncmds; i++) {
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            const struct section_64 *sections = (const struct section_64 *)(segment + 1);
            for (uint32_t sectionIndex = 0; sectionIndex < segment->nsects; sectionIndex++) {
                rebound = LHImportedSymbolRebindSection(&sections[sectionIndex],
                                                        symbolTable,
                                                        symtab->nsyms,
                                                        stringTable,
                                                        indirectSymbolTable,
                                                        slide,
                                                        binding) || rebound;
            }
        }
        command = (const struct load_command *)((const uint8_t *)command + command->cmdsize);
    }

    return rebound;
}

/** Rebind callback invoked for images loaded after registration. */
static void LHImportedSymbolRebindImageCallback(const struct mach_header *header, intptr_t slide) {
    for (size_t i = 0; i < LHImportedSymbolBindingCount; i++) {
        (void)LHImportedSymbolRebindImage(header, slide, &LHImportedSymbolBindings[i]);
    }
}

/** Rebinds an imported symbol across every image currently loaded. */
static bool LHImportedSymbolRebindExistingImages(const LHImportedSymbolBinding *binding) {
    bool rebound = false;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        rebound = LHImportedSymbolRebindImage(_dyld_get_image_header(i),
                                              _dyld_get_image_vmaddr_slide(i),
                                              binding) || rebound;
    }
    return rebound;
}

/** MobileSubstrate function-hook adapter. */
static bool LHTheosHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || context->hookFunction == 0 || target == 0 || replacement == 0) {
        return false;
    }

    context->hookFunction(target, replacement, original);
    return true;
}

/** Imported-symbol hook adapter backed by local Mach-O rebinding. */
static bool LHTheosHookImportedSymbol(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    (void)backend;
    if (symbol == 0 || symbol[0] == '\0' || replacement == 0 || LHImportedSymbolBindingCount >= (sizeof(LHImportedSymbolBindings) / sizeof(LHImportedSymbolBindings[0]))) {
        return false;
    }

    LHImportedSymbolBinding binding = {
        .symbol = symbol,
        .replacement = replacement,
        .original = original
    };
    LHImportedSymbolBindings[LHImportedSymbolBindingCount++] = binding;

    bool rebound = LHImportedSymbolRebindExistingImages(&binding);
    if (!LHImportedSymbolCallbackRegistered) {
        _dyld_register_func_for_add_image(LHImportedSymbolRebindImageCallback);
        LHImportedSymbolCallbackRegistered = true;
    }
    return rebound;
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
