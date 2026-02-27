# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a 5G-NR wireless protocol stack implementation focused on the DU (Distributed Unit) layer for NTN (Non-Terrestrial Network) scenarios (LEO/GEO satellite). The codebase is owned by SAGERAN. We only have DU layer access — MAC, RLC, L2App, and interfaces.

## Development Environment

- **Local machine**: Code editing only. The root CMakeLists.txt provides IDE indexing (clangd), not actual build rules.
- **Build server**: Configured via memory (IP, user, path). First-time setup prompts user — see `build-sync` skill.
- **Build system**: Makefile-based (NMK build system), NOT CMake
- **Languages**: C99 / C++11
- **Test framework**: UnitTest++ (not gtest)

## Build Commands (on build server)

**IMPORTANT**: Only `duapp/` and `components/callp/` are allowed to be synced — never sync the entire `src/` tree. Never use `--delete` to avoid removing files on either side. `components/callp/` only syncs Makefile files.

Sync and build operations are handled by the `build-sync` skill. Key rules:

- **Push (local → server)**: `duapp/` full sync + `callp/` Makefile-only sync
- **Pull (server → local)**: ONLY when user explicitly requests it, NEVER autonomous
- **Build**: `make -j8 do_strip=1` — **NEVER** use `make clean`, `make clean_<mod>`, or any clean-related commands
- **No --delete**: Never use `rsync --delete`

Build configuration flags are in `src/.config` (auto-generated, do not edit directly). Key flags: `CONFIG_NTN=1`, `CONFIG_SIMULATION=y`, `CONFIG_UNITTEST=y`, `CONFIG_NRMACTEST=y`, `CONFIG_RLCTEST=y`.

## Running Tests (on build server)

Test execution is handled by the `build-sync` skill. Tests use UnitTest++ syntax: `TEST(Name) { ... }`, `TEST_FIXTURE(Fixture, Name) { ... }`.

## Architecture

```
src/duapp/
├── mac/          # MAC layer — scheduling, resource mgmt, HARQ, link adaptation
├── rlc/          # RLC layer — AM/UM/TM modes, flow mgmt, SDU processing
├── l2app/        # L2 application — orchestrates MAC+RLC, control actions
├── interfaces/   # DU-to-CP/CU interface definitions
├── macphy/       # MAC-PHY interface (FAPI-based)
├── nrmactest/    # NR MAC unit tests + PHY simulator
└── rlctest/      # RLC unit tests + fixtures
```

Build rules for each module live under `src/components/callp/<module>/Makefile`, not alongside the source.

### MAC Layer (`src/duapp/mac/`)

The largest module (~200 headers, 30+ .cc files). Key manager classes:
- **Scheduling**: `NrMacPuschSchedulingMgr`, `NrMacPdschSchedulingMgr`, `NrMacChannelSchedulingMgr`
- **Resource allocation**: `NrMacChannelAllocationMgr`, `dlRsrcMgr`
- **HARQ**: `NrMacUeHarqManager`
- **Link adaptation**: `NrMacDownlinkLinkAdapter`, `NrMacUplinkLinkAdapter`
- **UE management**: `NrMacUeConfigMgr`, `NrMacCommonUeMgr`, `NrMacAdmissionControlMgr`
- **DRX/CSI**: `NrMacConnDrxSchedulingMgr`, `NrMacCsiSchedulingMgr`

Builds into `libmac.so` and `libmacphy.so`.

### RLC Layer (`src/duapp/rlc/`)

~100 headers, 66 .cc files. Key classes:
- `RlcAmDownlink`/`RlcAmUplink` — Acknowledged mode
- `RlcUmDownlink`/`RlcUmUplink` — Unacknowledged mode
- `RlcTmPcchDownlink`/`RlcTrDownlink` — Transparent mode
- `NtnEphemerisMgr` — NTN satellite ephemeris management
- `L2CellImpl` — Cell-level RLC implementation

### MAC-RLC Interface

Defined via virtual interface pattern in `macRlcIntf.h`. Communication uses message queues for thread safety.

## Critical Constraint: No malloc/free in MAC TTI Thread

The MAC (TTI) thread has strict real-time requirements. During TTI execution:
- **PROHIBITED**: `malloc`, `free`, `new`, `delete`, or any heap allocation
- **PROHIBITED**: C++ STL container operations that allocate (e.g. `std::vector::push_back` that triggers reallocation, `std::map::insert`, `std::string` construction)
- **REQUIRED**: Pre-allocated buffers, object pools, fixed-size arrays
- **Principle**: Trade bounded memory for deterministic timing

This applies to all code paths reachable from the TTI processing loop in the MAC scheduler.

## NTN-Specific Features

Key NTN adaptations throughout the codebase:
- **K-offset**: Propagation delay compensation in PUSCH/PDSCH scheduling
- **Extended HARQ**: `nrOfHarqProcessExt` for longer satellite RTT
- **UL HARQ mode**: Per-bitmap configuration (`ulHarqMode`)
- **Cell barred NTN R17**: `cellbarredNtnR17Info`
- **Ephemeris management**: `NtnEphemerisMgr` in RLC layer
- **PUSCH MCS control**: Two-phase algorithm (cold-start + steady-state) with BLER-based adaptation for long-delay compensation — see `docs/ntn_pusch_mcs_control_design.md`

## NR MAC Test Framework (`src/duapp/nrmactest/`)

The nrMacTest framework simulates a full DU environment for MAC testing:
- `NrMacTestDuEnv` / `NrMacTestDuCaEnv` — DU environment setup (single-cell / CA)
- `NrMacPhySimulator` — PHY layer simulator
- `NrMacTestPhyController` — PHY behavior control
- `NrMacTestFapiBuilder` — FAPI message construction
- `NrMacUeSimulator` — UE behavior simulation
- Flow classes (`nrTestMacBsrFlow`, `nrTestMacCeFlow`, etc.) — traffic pattern generation

## Code Conventions

- Headers use `.h`, implementations use `.cc`
- Public/export headers in `<module>/export/`, internal headers in `<module>/src/`
- Configuration via OAM (Operations & Maintenance) through `macConfigurator`
- NTN config extensions in `nrMacConfigExtender.h`
