---
name: nmk-source-management
description: "Guide for adding and removing source files in the NMK build system. Use when: (1) adding a new .cc/.c source file to a module, (2) removing/deleting a source file from compilation, (3) creating a new library or program target, (4) understanding Makefile structure for MAC/RLC/L2App/nrmactest/rlctest modules. Triggers on: 'add source file', 'remove source file', 'new file to build', 'delete file from build', 'Makefile', 'build registration'."
---

# NMK Source File Management

## Core Principle

The NMK build system uses **explicit source file listing** — no auto-discovery. Every `.cc`/`.c` file must be manually registered in the module's Makefile to be compiled. If a file is not listed, it will NOT be compiled. If a deleted file is still listed, the build will fail.

## Makefile Locations

Source code lives in `src/duapp/<module>/src/`, but build rules are in a separate tree:

| Module | Makefile Path | Source Dir (`VPATH`) |
|--------|--------------|----------------------|
| MAC | `src/components/callp/mac/Makefile` | `src/duapp/mac/src` |
| RLC | `src/components/callp/rlc/Makefile` | `src/duapp/rlc/src` + `src/duapp/l2app/src` |
| L2App | `src/components/callp/l2app/Makefile` | `src/duapp/l2app/src` |
| macphy | `src/components/callp/macphy/Makefile` | `src/duapp/macphy/src` |
| nrMacTest | `src/components/callp/nrmactest/Makefile` | `src/duapp/nrmactest/src` |
| rlcTest | `src/components/callp/rlctest/Makefile` | `src/duapp/rlctest/src` |

## Source Registration Variables

Two variable patterns depending on target type:

### For Libraries (`.so` / `.a`)

```makefile
LIBRARIES := mac macphy          # Declare library names
mac_LIBSRCS := \                 # List source files for 'mac' library
  macCommon.cc \
  rach.cc \
  ...
  newFile.cc
```

### For Programs (executables)

```makefile
PROGRAMS := nrMacTest            # Declare program names
nrMacTest_SRCS := \              # List source files for 'nrMacTest' program
  nrMacPhySimulator.cc \
  nrMacTestDuEnv.cc \
  ...
  newTestFile.cc
```

### Variable Naming Convention

| Target Type | Name Variable | Source Variable | Flags | Dependencies |
|-------------|--------------|-----------------|-------|-------------|
| Shared lib | `LIBRARIES` | `<name>_LIBSRCS` | `<name>_CPPFLAGS`, `<name>_CXXFLAGS`, `<name>_CFLAGS` | `<name>_LIBLIBS` |
| Static lib | `STATIC_LIBRARIES` | `<name>_LIBSRCS` | same as above | same |
| Program | `PROGRAMS` | `<name>_SRCS` | `<name>_CPPFLAGS`, `<name>_CXXFLAGS`, `<name>_CFLAGS` | `<name>_LIBS`, `<name>_LDFLAGS` |

## How to Add a New Source File

### Step 1: Create the source file

Place it in the module's source directory:
- Headers: `src/duapp/<module>/export/` (public) or `src/duapp/<module>/src/` (internal)
- Implementation: `src/duapp/<module>/src/`

### Step 2: Register in Makefile

Edit the module's Makefile and append the filename to the appropriate `_LIBSRCS` or `_SRCS` variable.

**Example — add `nrMacNewFeature.cc` to MAC library:**

```makefile
# In src/components/callp/mac/Makefile
mac_LIBSRCS := \
  macCommon.cc \
  ...
  nrMacUeHarqManager.cc \
  nrMacNewFeature.cc              # <-- append here
```

**Example — add `nrMacNewFeatureTest.cc` to nrMacTest program:**

```makefile
# In src/components/callp/nrmactest/Makefile
nrMacTest_SRCS := nrMacPhySimulator.cc \
    ...
    nrMacNewFeatureTest.cc        # <-- append here
```

### Step 3: Add include paths (if needed)

If the new file depends on headers from other modules not already included, add `-I` paths to the module's `_CPPFLAGS`:

```makefile
mac_CPPFLAGS := $(_MAC_INCLUDES) -I$(TOPDIR)/some/new/path ...
```

Or extend the `_INCLUDES` variable if the module uses one (e.g., `_MAC_INCLUDES`, `_RLC_EXTERNAL_INCLUDES`, `_MAC_TEST_EXTERNAL_INCLUDES`).

### Step 4: Rebuild

Use the `build-sync` skill to push code and build on the remote server. Refer to memory (`MEMORY.md` → `## Build Server`) for connection details.

## How to Remove a Source File

### Step 1: Remove from Makefile

Delete the filename from `_LIBSRCS` or `_SRCS` in the module's Makefile. Watch for trailing backslash `\` continuations — ensure the line before the removed entry still has correct continuation.

**Before (removing `obsoleteFile.cc`):**
```makefile
mac_LIBSRCS := \
  fileA.cc \
  obsoleteFile.cc \
  fileB.cc
```

**After:**
```makefile
mac_LIBSRCS := \
  fileA.cc \
  fileB.cc
```

**Edge case — removing the last entry:**
```makefile
# Before:
mac_LIBSRCS := \
  fileA.cc \
  lastFile.cc

# After (remove trailing backslash from new last line):
mac_LIBSRCS := \
  fileA.cc
```

### Step 2: Delete the source file (optional but recommended)

Remove the `.cc`/`.h` files from `src/duapp/<module>/src/` and/or `src/duapp/<module>/export/`.

### Step 3: Remove references in other source files

Check for `#include` directives or function calls referencing the removed file. Grep for the filename and any symbols it exported.

## How to Add a New Library Target

To create a new library within an existing module's Makefile:

```makefile
# 1. Add to LIBRARIES list
LIBRARIES := mac macphy newlib

# 2. Define source files
newlib_LIBSRCS := \
  newlibFile1.cc \
  newlibFile2.cc

# 3. Define compiler flags
newlib_CPPFLAGS := $(_MAC_INCLUDES) -Werror
newlib_CXXFLAGS := -Wno-deprecated -Werror

# 4. Define dependencies (other libraries to link against)
newlib_LIBLIBS := mac

# 5. Set version
newlib_SOVERSION := 1.0
```

Output: `components/rootfs/lib/libnewlib.so.1.0` with symlinks `libnewlib.so.1` and `libnewlib.so`.

## How to Add a New Program Target

```makefile
# 1. Add to PROGRAMS list
PROGRAMS := nrMacTest newProg

# 2. Define source files
newProg_SRCS := \
  newProgMain.cc \
  newProgHelper.cc

# 3. Define compiler flags
newProg_CPPFLAGS := $(_MAC_TEST_EXTERNAL_INCLUDES)
newProg_CXXFLAGS := -Wno-error

# 4. Define library dependencies
newProg_LIBS := mac rlc
newProg_LDFLAGS := -lpthread
```

Output: `components/rootfs/bin/newProg`.

## Build System Internals (Reference)

### Template Expansion in `rules.mk`

The shared `src/nmk/rules.mk` uses `define`/`endef` templates that are instantiated via `$(foreach)` + `$(eval)`:

1. `LIB_VAR_CAT` — merges arch-specific variables (e.g., `arm64_mac_CXXFLAGS`)
2. `LIBRARY_VAR` — generates object file lists: `_<name>_ALL_SOLIBOBJS`, `_<name>_CSOLIBOBJS`, `_<name>_CXXSOLIBOBJS`
3. `LIBRARY_RULES` — generates `.cc → .o` and `.c → .o` pattern rules per library
4. Linking rule — all `.o` files linked into `lib<name>.so.<version>` with `-shared`

Object file derivation:
```
<name>_LIBSRCS = foo.cc bar.c
→ _<name>_ALL_SOLIBOBJS = foo.o bar.o
→ _<name>_CXXSOLIBOBJS = foo.o   (compiled with CXX)
→ _<name>_CSOLIBOBJS = bar.o     (compiled with CC)
```

### VPATH Mechanism

`VPATH` tells Make where to find source files. Only filenames (not paths) go in `_LIBSRCS`/`_SRCS`:

```makefile
VPATH := $(TOPDIR)/duapp/mac/src
mac_LIBSRCS := macCommon.cc    # Make finds $(TOPDIR)/duapp/mac/src/macCommon.cc via VPATH
```

Multiple source directories use colon-separated `VPATH`:
```makefile
VPATH = $(TOPDIR)/duapp/rlc/src:$(TOPDIR)/duapp/l2app/src
```

### Compressed Compilation (MAC only)

When `CONFIG_COMPRESS_COMPILE=y`, all MAC sources are combined into a single `allSrc.cc` via `#include` directives, compiled as one translation unit. This is handled automatically — no action needed when adding/removing files, as the script reads from `mac_LIBSRCS`.

### Conditional Compilation

Some modules use config flags for conditional source inclusion:

```makefile
ifeq ($(CONFIG_WIRESHARK_PDU),y)
    LIBRARIES += macrlcpdu
    macrlcpdu_LIBSRCS := mac_rlc_pdu.c
endif
```

## Checklist: Adding a Source File

- [ ] Source file created in `src/duapp/<module>/src/`
- [ ] Header (if any) placed in `export/` (public) or `src/` (internal)
- [ ] Filename added to `_LIBSRCS` or `_SRCS` in `src/components/callp/<module>/Makefile`
- [ ] Include paths added if referencing new external headers
- [ ] Build succeeds on build server (use `build-sync` skill)
- [ ] No new compiler warnings with `-Werror`

## Checklist: Removing a Source File

- [ ] Filename removed from `_LIBSRCS` or `_SRCS` in Makefile
- [ ] Backslash continuations `\` are correct after removal
- [ ] Source `.cc`/`.h` files deleted
- [ ] All `#include` references to removed headers cleaned up
- [ ] All function/class references to removed symbols cleaned up
- [ ] Build succeeds on build server (use `build-sync` skill)

## Important Notes

- **Makefile changes on build server are handled automatically**: When deleting source files locally, you do NOT need to manually edit the Makefile on the build server. The `build-sync` push operation syncs Makefiles from local to server, so the build server's Makefile will be updated during the normal push+build flow.
