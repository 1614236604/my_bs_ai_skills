---
name: nrmactest-generator
description: "Guide and templates for writing nrMacTest test cases for NTN 5G-NR DU MAC layer. Use when creating new unit tests for MAC scheduling, HARQ, resource allocation, PUCCH/PUSCH, link adaptation, UE attachment, DL/UL traffic, multi-UE scenarios, handover, reestablishment, RedCap UE, CA, or NTN-specific tests (K-offset, extended HARQ). Triggers on: 'write mac test', 'add nrmactest', 'unit test for MAC', 'nrmactest', 'MAC test case'."
---

# nrMacTest Generator

## Test Framework

Uses **UnitTest++** (NOT gtest):

```cpp
#include "UnitTest++.h"
SUITE(SuiteName) {
TEST(TestName) { CHECK(condition); }
TEST_FIXTURE(FixtureClass, TestName) { CHECK_EQUAL(expected, actual); }
}
```

## Test Lifecycle

Every test must start with `UnitTestRCBufferPool::getInstance()->initialize()`.

```
1. UnitTestRCBufferPool::getInstance()->initialize()
2. NrMacTestDuEnv env  (or NrMacTestDuCaEnv for CA)
3. Configure: env.configDataPtr() -> modify ConfigDataT
4. env.startDu()
5. Create UE: env.createUeSimulator() -> ue->startAttach()
6. Drive TTIs: phy->buildAndSendSlotInd() in loop
7. Verify: CHECK(ue->attached())
8. Optional: enable traffic, inject data, control HARQ/SR
```

## Core Components

### NrMacTestDuEnv — DU Environment

```cpp
NrMacTestDuEnv env(uint8_t numPhys=1);
ConfigDataT* config = env.configDataPtr();
NrMacConfigExtender* ext = env.configDataExtender();
env.setLoggerLevel(7);
env.startDu();
NrMacPhySimulator* phy = env.phySimulator();
NrMacOdiMgr* odi = env.odiMgr();
env.triggerAllCCSynced();
static void NrMacTestDuEnv::fr2DefaultSet(ConfigDataT*); // FR2 defaults
```

UE creation variants:
```cpp
env.createUeSimulator(const char* capability=NULL, UeType ueType=DEFAULT_UE);
env.createRedCapUeSimulator(const char* capability=NULL);
env.createReestaUeSimualtor(srcUe);        // Reestablishment
env.createInterCellHoUeSimualtor(srcUe);   // Inter-cell HO
env.createIntraCellHoUeSimualtor(srcUe);   // Intra-cell HO
env.createInterCellRedCapHoUeSimualtor(srcUe);
env.createIntraCellRedCapHoUeSimualtor(srcUe);
env.createInterCellNrdcUeSimualtor(srcUe); // NR-DC
```

### NrMacTestDuCaEnv — CA Environment

Extends NrMacTestDuEnv for Carrier Aggregation:
```cpp
NrMacTestDuCaEnv caEnv;
caEnv.startDu();
caEnv.switchCell(uint8_t cellId);
```

### NrMacUeSimulator — UE Lifecycle

```cpp
ue->startAttach();
ue->startAttach(int cRnti);       // With specific C-RNTI
ue->detach();
ue->attached();                    // Check attachment status
ue->cRnti();                      // Get assigned C-RNTI
ue->testSimulatorId();

// Data injection
ue->injectDlData(uint8_t lcid, uint8_t* buf, uint32_t len);
ue->injectRcDlData(uint8_t flowId, uint32_t sduNum, uint32_t sduLen);
ue->injectUlBsr(uint8_t lcgId, uint32_t bsrIndex);
ue->srRequired();

// Transmission control
NrMacTestTransmissionController* tc = ue->ueTransmissionController();
tc->setSrPositive(carrier);  / tc->setSrNegative(carrier);
tc->setHarqAck(carrier);     / tc->setHarqNack(carrier);

// RedCap / HO / Reesta
ue->setUeType(UeType);
ue->setReestaEnabled(bool);
ue->setHoEnabled(int hoRnti, int hoPid);
ue->setNrdcEnabled(int nrdcRnti, int nrdcPid);
ue->cleanAllFapiEvent();
```

### NrMacPhySimulator — PHY Simulator

```cpp
phy->buildAndSendSlotInd(bool needUpdateSlotInd=true);
phy->currentSlotInd();
phy->allocateTestSimulatorId();
phy->registerEvent(eventType, hook);
phy->deregisterAllEvent(simId);
```

### NrMacOdiMgr — Test Control (Critical)

```cpp
NrMacOdiMgr* odi = env.odiMgr();

// Traffic control
odi->setDlPaddingTrafficEnable(bool);
odi->setUlPaddingTrafficEnable(bool);
odi->setPdschFixedRbNumber(int);
odi->setPuschFixedRbNumber(int);
odi->setCrSchedulingAloneEnable(bool);

// MCS forcing
odi->setDlForceMcs(int);
odi->setPuschMinMcsIndex(int);

// HARQ control
odi->forceHarqAcked();
odi->triggerAperiodicCqi(int crnti);

// Performance monitoring
odi->setPmEnable(bool);
odi->setPmReportEnable(bool);
```

### Event Hook System

Register callbacks for FAPI events via `NrMacTestEventHook`:
```cpp
class MyHook : public NrMacTestEventHook {
    void callback(void* args) override { /* handle event */ }
};
// Event types: FAPI_EVENT_SLOT, FAPI_EVENT_RACH, FAPI_EVENT_DL_DCI,
// FAPI_EVENT_DLSCH, FAPI_EVENT_UL_DCI, FAPI_EVENT_ULSCH, FAPI_EVENT_UCI, etc.
```

### Test Utility Functions

```cpp
UnitTestResetMacThought();
UnitTestShowMacThought(uint32_t seconds);
UnitTestShowUeThought(uint32_t crnti, uint32_t seconds);
UnitTestForceUeUlMcs(UeProfileT*, uint8_t mcs);
UnitTestForceUeDlMcs(UeProfileT*, uint8_t mcs);
```

## NTN Configuration

```cpp
config->kCellOffset = 20;
config->nrOfHarqProcessExt = 32;
config->ulHarqMode[0] = 0;  // modeB
config->ulHarqMode[1] = 1;  // modeA
config->dlHarqFeedbackDisable[0] = 0xffffffff;
config->taEnable = true;
config->taNAvg = 20;
config->taFilter = 2;
```

Presets: `setupConfiguration_ntn()` (FR2 120K, band n512), `setupConfiguration_ntn_30k()` (FR1 30K, band n255) — defined in `nrMacTestDemo.cc`.

## File Placement

- Source: `src/duapp/nrmactest/src/<testName>.cc`
- Build: add .cc to `src/components/callp/nrmactest/Makefile`

## Templates

See [references/nrmactest-templates.md](references/nrmactest-templates.md) for complete test templates.

For detailed API of flow classes, FAPI builder, message types, see source headers in `src/duapp/nrmactest/src/`.

## File Header

```cpp
/**
*****************************************************************************
* @file  <filename>.cc
* @brief <description>
*
* Maintained by: Layer2/MAC
*
* Copyright 2026 SAGERAN. All Rights Reserved.
*
* CONFIDENTIALITY AND LIMITED USE
*****************************************************************************
*/
```
