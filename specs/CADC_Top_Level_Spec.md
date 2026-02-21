# CADC Top-Level Integration Specification

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Function | Top-level CADC FPGA system integrating all modules |
| Architecture | Multi-processor, microprogrammed, pipelined |
| Modules | PMU, PDU, SLF, RAS, SL, ROM+Sequencer, I/O Bridge, Timing Generator |

### 2. System Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │              CADC TOP LEVEL                        │
                    │                                                     │
  Sensor Inputs ───►│  ┌──────────┐     ┌─────┐     ┌─────┐             │
                    │  │ I/O      │◄───►│ SL  │◄───►│ SLF │             │
  Display Out   ◄──│  │ Bridge   │     │     │     │(ALU)│             │
                    │  └──────────┘     │     │     └──┬──┘             │
  Servo Out     ◄──│                   │     │        │                 │
                    │  ┌──────────┐     │     │     ┌──┴──┐             │
                    │  │ PMU      │◄───►│     │◄───►│ RAS │             │
                    │  │(Multiply)│     │     │     │     │             │
                    │  └──────────┘     │     │     └─────┘             │
                    │                   │     │                         │
                    │  ┌──────────┐     │     │                         │
                    │  │ PDU      │◄───►│     │                         │
                    │  │(Divide)  │     └─────┘                         │
                    │  └──────────┘        ▲                            │
                    │                      │                            │
                    │  ┌──────────────────┐│                            │
                    │  │ Control ROM +    ││                            │
                    │  │ Sequencer        │┘                            │
                    │  │ + Timing Gen     │                             │
                    │  └──────────────────┘                             │
                    │                                                     │
                    │  ┌──────────────────┐                             │
                    │  │ Data ROM         │                             │
                    │  └──────────────────┘                             │
                    └─────────────────────────────────────────────────────┘
```

### 3. Data Flow

#### 3.1 Computation Cycle (per Operation)
Each operation (OP) consists of two word times (WA + WO):

**WA (Word A) — Compute Phase:**
1. Sequencer fetches microinstruction from Control ROM
2. Control signals decoded and distributed to all modules
3. SL routes selected source to SLF (ALU) input
4. SLF performs ALU operation, updates ACC/TMP/flags
5. PMU/PDU start if commanded (continue in background)

**WO (Word O) — Transfer Phase:**
1. Sequencer fetches next microinstruction
2. Results from ACC/TMP/PMU/PDU routed via SL to destinations
3. RAS writes if commanded (store intermediate results)
4. I/O Bridge reads/writes if commanded
5. Prepare for next WA

#### 3.2 Pipelining
The CADC employs pipelining where:
- While one result is being computed (current OP), the previous result is being transferred
- PMU/PDU operations span multiple OPs — the sequencer uses wait/busy to synchronize
- This pipelining provides significant throughput improvement

### 4. Timing Generator Sub-Module

#### 4.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk_master` | Input | 1 | 5 MHz master oscillator (or FPGA clock) |
| `rst` | Input | 1 | System reset |
| `phi1` | Output | 1 | Phase 1 clock (375 kHz) |
| `phi2` | Output | 1 | Phase 2 clock (375 kHz) |
| `bit_count` | Output | 5 | Current bit time (T0–T19) |
| `word_type` | Output | 1 | '0'=WA, '1'=WO |
| `word_mark` | Output | 1 | Pulse at T18 of every word |
| `op_count` | Output | 10 | Current operation number (0–511) |
| `frame_mark` | Output | 1 | Pulse at end of final OP |

#### 4.2 VHDL Entity

```vhdl
entity timing_generator is
    port (
        clk_master : in  std_logic;
        rst        : in  std_logic;
        phi1       : out std_logic;
        phi2       : out std_logic;
        bit_count  : out std_logic_vector(4 downto 0);
        word_type  : out std_logic;
        word_mark  : out std_logic;
        op_count   : out std_logic_vector(9 downto 0);
        frame_mark : out std_logic
    );
end entity timing_generator;
```

#### 4.3 Timing Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| TIM-F-001 | Shall divide master clock to produce Φ1, Φ2 at 375 kHz | Must |
| TIM-F-002 | Φ1 and Φ2 shall be non-overlapping | Must |
| TIM-F-003 | Shall count 20 bit times per word (T0–T19) | Must |
| TIM-F-004 | Shall alternate between WA and WO word types | Must |
| TIM-F-005 | Shall count 512 operations per frame | Must |
| TIM-F-006 | Shall generate word_mark at T18 of every word | Must |
| TIM-F-007 | Shall generate frame_mark at end of OP 511 | Must |
| TIM-F-008 | Reset shall clear all counters and start from T0/WA/OP0 | Must |

### 5. Top-Level Integration

#### 5.1 VHDL Entity

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cadc_top is
    port (
        -- Clock and Reset
        clk_master     : in  std_logic;          -- 5 MHz or FPGA clock
        rst            : in  std_logic;
        
        -- Sensor Inputs (from ADCs)
        sensor_ps      : in  std_logic_vector(19 downto 0);
        sensor_qc      : in  std_logic_vector(19 downto 0);
        sensor_tat     : in  std_logic_vector(19 downto 0);
        sensor_analog  : in  std_logic_vector(19 downto 0);
        sensor_digital : in  std_logic_vector(19 downto 0);
        
        -- Display Outputs (to DACs)
        out_mach       : out std_logic_vector(19 downto 0);
        out_alt        : out std_logic_vector(19 downto 0);
        out_airspd     : out std_logic_vector(19 downto 0);
        out_vspd       : out std_logic_vector(19 downto 0);
        
        -- Servo Outputs (to actuators)
        out_wing       : out std_logic_vector(19 downto 0);
        out_flap       : out std_logic_vector(19 downto 0);
        out_glove      : out std_logic_vector(19 downto 0);
        
        -- Status
        bit_status     : out std_logic;           -- Built-in test pass/fail
        channel_active : in  std_logic;           -- Redundancy control
        fail_detect    : out std_logic            -- Failure indicator
    );
end entity cadc_top;
```

#### 5.2 Internal Signal Interconnections

```
Control ROM/Sequencer → (decoded control signals) → All modules
Timing Generator → (phi1, phi2, bit_count, word_mark, frame_mark) → Sequencer
SL.acc_in → SLF.acc_in
SLF.acc_out → SL.src_acc
SLF.tmp_out → SL.src_tmp
SLF.flag_z/n/c → Sequencer.flag_z/n/c
RAS.read_data → SL.src_ras
SL.ras_wr_data → RAS.write_data
PMU.result → SL.src_pmu
PMU.busy → Sequencer.pmu_busy
SL.acc_in (from src_pmu/src_ras) → PMU.operand_a (via SL routing)
PDU.quotient → SL.src_pdu_q
PDU.remainder → SL.src_pdu_r
PDU.busy → Sequencer.pdu_busy
I/O Bridge.io_data_out → SL.src_io_in
SL.io_out → I/O Bridge.io_data_in
Data ROM.data → SL.src_const
```

### 6. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| TOP-F-001 | Shall instantiate and interconnect all 7 modules | Must |
| TOP-F-002 | Shall implement the timing generator | Must |
| TOP-F-003 | Shall execute 512 operations per frame | Must |
| TOP-F-004 | Shall complete one frame in ≤ 60 ms | Must |
| TOP-F-005 | All inter-module data paths shall be 20 bits wide | Must |
| TOP-F-006 | Shall support multiple PMU instances for parallel computation | Should |
| TOP-F-007 | Shall support redundant dual-channel operation | Should |
| TOP-F-008 | Shall provide system reset that initializes all modules | Must |
| TOP-F-009 | External I/O timing shall be compatible with sensor/actuator specs | Should |
| TOP-F-010 | FPGA resource utilization shall be documented | Should |

### 7. Verification Tests

#### 7.1 Integration Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| TOP-T-001 | System reset | All modules reach known state |
| TOP-T-002 | First instruction fetch | Sequencer fetches from ROM address 0 |
| TOP-T-003 | Simple ADD operation | Load ACC, add value, verify result |
| TOP-T-004 | Multiply flow | Load PMU operands via SL, start PMU, wait, read result |
| TOP-T-005 | Divide flow | Load PDU operands, start PDU, wait, read quotient |
| TOP-T-006 | RAS store/load | Write ACC to RAS, read back, compare |
| TOP-T-007 | I/O read sensor | Read sensor via I/O Bridge, route to ACC |
| TOP-T-008 | I/O write display | Compute result, route to display output |
| TOP-T-009 | Full frame execution | Run all 512 OPs, verify frame_mark generation |

#### 7.2 End-to-End Function Tests

| Test ID | Description | Input | Expected Output |
|---------|-------------|-------|-----------------|
| TOP-T-020 | Standard atmosphere altitude | Known Ps value | Correct altitude on display |
| TOP-T-021 | Sea level Mach number | Known Qc, Ps | Mach 0 on display |
| TOP-T-022 | Known airspeed | Known Qc, Ps, TAT | Correct airspeed |
| TOP-T-023 | Wing sweep schedule | Known Mach/altitude | Correct wing position |

#### 7.3 Self-Test Verification

| Test ID | Description | Criteria |
|---------|-------------|----------|
| TOP-T-030 | BIT passes with healthy system | `bit_status` = pass |
| TOP-T-031 | BIT detects injected fault | `bit_status` = fail, `fail_detect` asserts |
| TOP-T-032 | Redundancy switchover | Active channel fails, backup takes over |

#### 7.4 Timing Verification

| Test ID | Description | Criteria |
|---------|-------------|----------|
| TOP-T-040 | Frame timing | Frame completes within spec (≤ 60 ms) |
| TOP-T-041 | Word timing | WA/WO alternate correctly |
| TOP-T-042 | Phase clock generation | Φ1, Φ2 non-overlapping at 375 kHz |
| TOP-T-043 | Bit time accuracy | 20 bit times per word |

### 8. FPGA Implementation Notes

#### 8.1 Target Devices
The design should be portable across major FPGA families:
- Xilinx (Artix-7, Kintex-7, or newer)
- Intel/Altera (Cyclone, Stratix)
- Lattice (ECP5, CrossLink-NX)

#### 8.2 Estimated Resources
| Resource | Estimated Usage |
|----------|----------------|
| LUTs | ~2,000–5,000 |
| Flip-Flops | ~500–1,500 |
| Block RAM | 2–4 (for ROM and RAS) |
| DSP blocks | 0–2 (optional for PMU/PDU) |
| Clock nets | 1–2 |

#### 8.3 Constraints
- All outputs shall be registered (no combinational paths to I/O pins)
- Clock domain crossing shall use proper synchronization if multiple clocks used
- Reset shall be synchronous to the system clock
- Pin assignments shall be documented per target board

#### 8.4 Simulation Environment
- VHDL-2008 compatible
- Testbenches use `assert` statements for automated verification
- Waveform output for visual inspection
- Coverage targets: >95% statement coverage, >90% branch coverage per module

---

## 9. Source References

All requirements and design details in this specification are traceable to the following source documents. OCR text extractions are in the `ocr_text/` folder.

### 9.1 Primary Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p1-4-to-p1-34-.pdf** | Report pp. 1-4 to 1-6 | `ocr_text/p1-4-to-p1-34-.txt` | System timing architecture — 5 MHz master, Φ1/Φ2 at 375 kHz, bit time, word time (T0–T19), WA/WO alternation, word mark (T18), OP time, frame mark, 512 OPs/frame |
| **p1-35-to-p2-28-.pdf** | Report pp. 1-40 to 1-42 | `ocr_text/p1-35-to-p2-28-.txt` | Module CW breakdown (5 bits→RAS, 15 bits→SL, SLF shares 4 RAS select bits), inter-module data flow walkthrough (frame mark → ROM reset → CW shift → SL routing → arithmetic → data transfer) |
| **p1-35-to-p2-28-.pdf** | Report pp. 2-9 to 2-22 | `ocr_text/p1-35-to-p2-28-.txt` | Executive control (20-bit exec word): D/A updates, digital outputs, BITE, sensor memory, ROM enables, frame mark; software/hardware relationship; propagation delay considerations |
| **ap1-26-97.pdf** | pp. 5–7, 15–17 | `ocr_text/ap1-26-97.txt` | Pipeline concurrency, module independence, expandability; system operation & instruction format; 28-circuit 3-module arrangement; data ROM/control ROM paths |
| **CADC_Module_Specification.pdf** | pp. 1–4 | *(text-layer PDF)* | All module interfaces integrated at top level |

### 9.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **Rays-…-Chapter-7-System-Info.pdf** | pp. 5–6 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Clock generator timing calculations, timing waveform details |
| **lsistate-97.pdf** | pp. 6–7 | *(text-layer PDF)* | Architecture decisions — parallel multi-processor approach, pipelining for throughput, CPU synchronization |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | pp. 1, 4 | *(text-layer PDF)* | System design block diagram (Steve Geller), software simulation approach |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Complete page index for all sections, figures, and appendices |
