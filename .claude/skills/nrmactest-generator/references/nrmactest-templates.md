# nrMacTest Templates

## Template 1: Basic UE Attachment

```cpp
/*lint -save*/
/*lint -emacro(1712, TEST_FIXTURE)*/
/*lint -emacro(1502, TEST_FIXTURE)*/
/*lint -emacro(1725, TEST_FIXTURE)*/
/*lint -libh*/

#include <stdio.h>
#include "UnitTest++.h"
#include "nrMacTestDuEnv.h"
#include "nrMacUeSimulator.h"

SUITE(MyTestSuite)
{

TEST(SingleUeAttach)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;
    config->ulHarqMode[0] = 0;
    config->ulHarqMode[1] = 1;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    NrMacUeSimulator* ue = env.createUeSimulator();
    ue->startAttach();

    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();

    CHECK(ue->attached());
}

}
```

## Template 2: DL/UL Traffic

```cpp
SUITE(TrafficTest)
{

TEST(DlUlPaddingTraffic)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    NrMacOdiMgr* odi = env.odiMgr();
    odi->setCrSchedulingAloneEnable(false);

    NrMacUeSimulator* ue = env.createUeSimulator();
    ue->startAttach();

    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();
    CHECK(ue->attached());

    odi->setDlPaddingTrafficEnable(true);
    odi->setPdschFixedRbNumber(273);
    odi->setUlPaddingTrafficEnable(true);
    odi->setPuschFixedRbNumber(273);

    for (int i = 0; i < 8000; i++)
        phy->buildAndSendSlotInd();
}

}
```

## Template 3: Multi-UE

```cpp
#include <list>

SUITE(MultiUeTest)
{

TEST(MultipleUeAttach)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    std::list<NrMacUeSimulator*> ueList;
    int numUe = 4;
    for (int i = 0; i < numUe; i++)
    {
        NrMacUeSimulator* ue = env.createUeSimulator();
        ue->startAttach();
        ueList.push_back(ue);
    }

    for (int i = 0; i < numUe * 1000; i++)
        phy->buildAndSendSlotInd();

    for (std::list<NrMacUeSimulator*>::iterator it = ueList.begin();
         it != ueList.end(); it++)
        CHECK((*it)->attached());
}

}
```

## Template 4: Component Unit Test with Fixture

```cpp
#include "UnitTest++.h"
#include "nrMacTestDuEnv.h"
#include "nrMacConfigExtender.h"

class MyComponentFixture : public UnitTest::Fixture
{
public:
    ConfigDataT m_config;
    NrMacConfigExtender* m_configExtender;

    MyComponentFixture()
    {
        NrMacTestDuEnv::fr2DefaultSet(&m_config);
        m_configExtender = new NrMacConfigExtender(&m_config);
    }
    ~MyComponentFixture() { delete m_configExtender; }

    void resetConfig(int kCellOffset)
    {
        NrMacTestDuEnv::fr2DefaultSet(&m_config);
        m_config.kCellOffset = static_cast<uint16_t>(kCellOffset);
        delete m_configExtender;
        m_configExtender = new NrMacConfigExtender(&m_config);
    }
};

SUITE(MyComponentTest)
{
TEST_FIXTURE(MyComponentFixture, BasicFunctionality)
{
    // Use m_configExtender to init and test component
    CHECK(/* condition */);
}
}
```

## Template 5: Handover

```cpp
SUITE(HandoverTest)
{

TEST(InterCellHandover)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    NrMacUeSimulator* srcUe = env.createUeSimulator();
    srcUe->startAttach();
    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();
    CHECK(srcUe->attached());

    NrMacUeSimulator* hoUe = env.createInterCellHoUeSimualtor(srcUe);
    hoUe->startAttach();
    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();
    CHECK(hoUe->attached());
}

}
```

## Template 6: RedCap UE

```cpp
SUITE(RedCapTest)
{

TEST(RedCapUeAttach)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    NrMacUeSimulator* ue = env.createRedCapUeSimulator();
    ue->startAttach();

    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();

    CHECK(ue->attached());
    CHECK_EQUAL(REDCAP_UE, ue->getUeType());
}

}
```

## Template 7: HARQ/SR Transmission Control

```cpp
SUITE(HarqControlTest)
{

TEST(ForceHarqNack)
{
    UnitTestRCBufferPool::getInstance()->initialize();

    NrMacTestDuEnv env;
    ConfigDataT* config = env.configDataPtr();
    config->kCellOffset = 20;
    config->nrOfHarqProcessExt = 32;

    NrMacPhySimulator* phy = env.phySimulator();
    env.startDu();

    NrMacUeSimulator* ue = env.createUeSimulator();
    ue->startAttach();

    for (int i = 0; i < 1000; i++)
        phy->buildAndSendSlotInd();
    CHECK(ue->attached());

    // Force HARQ NACK to test retransmission
    NrMacTestTransmissionController* tc = ue->ueTransmissionController();
    tc->setHarqNack(NrMacTestTransmissionController::CARRIER_PCC);

    for (int i = 0; i < 500; i++)
        phy->buildAndSendSlotInd();
}

}
```

## NTN Configuration Presets

### FR2 NTN (120kHz SCS, band n512)
From `setupConfiguration_ntn()` in `nrMacTestDemo.cc`:
- `operatingBand = 512`, SCS_120K, BW 100MHz
- `kCellOffset = 20`, `nrOfHarqProcessExt = 32`

### FR1 NTN (30kHz SCS, band n255)
From `setupConfiguration_ntn_30k()` in `nrMacTestDemo.cc`:
- `operatingBand = 255`, SCS_30K, BW 20MHz
- `kCellOffset = 20`, `nrOfHarqProcessExt = 32`

### Key NTN Config Fields
```cpp
config->kCellOffset = 20;
config->nrOfHarqProcessExt = 32;
config->ulHarqMode[0] = 0;                   // modeB
config->ulHarqMode[1] = 1;                   // modeA
config->dlHarqFeedbackDisable[0] = 0xffffffff;
config->taEnable = true;
config->taNAvg = 20;
config->taFilter = 2;
config->taAlfa = 0;
config->taTupdate = 1;
config->taOutOfSyncRange = 4;
config->taOutOfSyncTimer = 16;
```
