# F-14A CADC System-Level Requirements Specification

## Document Information
- **Project:** F-14A Central Air Data Computer — FPGA Reconstruction
- **Reference Documents:** AiResearch 71-7266, Ray Holt Design Notebook Chapters 1–7, CADC Module Specification, LSI State-of-the-Art Paper (1998)
- **Original Part Numbers:** PMU (944111), PDU (944112), SLF (944113), RAS (944114), SL (944118), ROM (944125)

---

## 1. System Overview

### 1.1 Purpose
The CADC performs real-time computation of air data parameters for the F-14A Tomcat fighter aircraft. It receives inputs from pressure sensors, temperature sensors, and pilot controls, and produces outputs to cockpit displays (Mach, altitude, airspeed, vertical speed) and flight control surfaces (wing sweep, maneuver flaps, glove vane).

### 1.2 Architecture Summary
The CADC is a **20-bit, fractional fixed-point, microprogrammed, pipelined, multi-processor** system. It comprises six unique MOS-LSI chip types totaling 74,442 devices (transistors), of which 62,092 are stored program instructions in ROM.

### 1.3 Key Design Parameters

| Parameter | Value |
|-----------|-------|
| Word width | 20 bits (1 sign + 19 data) |
| Number representation | 2's complement, fractional fixed-point |
| Master clock | 5 MHz |
| Phase clocks (Φ1, Φ2) | 375 kHz |
| Bit time | 2.666 μsec (one Φ2-to-Φ2 period) |
| Word time | 20 bit times = 53.33 μsec |
| Operation (OP) time | 2 words (WA + WO) = 106.66 μsec |
| Total operations per frame | 512 |
| Frame time | ~54.6 msec (≈ 1/18.3 sec) |
| Throughput per second | 5,490 multiplies, 1,922 divides, 293 add/sub, 73 sqrt, 842 I/O |
| PC board size | 4" × 10" (40 sq in) |
| Power budget | ≤ 10 watts at 25°C ambient |
| Unique chip types | 6 |

### 1.4 Data Format

```
Bit:  S  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19
      ↑    ↑                                                                                              ↑
    Sign  MSB=0.5                                                                                      LSB≈0.000002
```

- **Sign bit (S):** 0 = positive, 1 = negative
- **Data bits (1–19):** Fractional values from 2⁻¹ (0.5) to 2⁻¹⁹ (≈0.0000019)
- **Negative numbers:** 2's complement notation

### 1.5 System Timing

The 5 MHz master oscillator is divided to produce two non-overlapping phase clocks:
- **Φ1** and **Φ2** at 375 kHz
- One **bit time** = Φ2 rising edge to next Φ2 rising edge = 2.666 μsec
- **20 consecutive bit times** = one **word** (T0 through T19)
- **Word types:**
  - **WA (Word A):** Parallel arithmetic algorithms operate; control (instruction) words shift serially into units
  - **WO (Word O):** Computational inputs and outputs shift serially among units
- **Word mark:** Signal coincident with T18 of every word time
- **Operation (OP):** Two consecutive words WA + WO
- **Frame mark:** Signal coincident with T18 of the final word time of the final OP
- **Frame:** One complete computational cycle (512 OPs)

### 1.6 Module Configuration

The CADC uses a multi-processor arrangement with three computing modules operating in parallel. The system uses a **total of 28 circuits**:

| Chip Type | Quantity | Allocation |
|-----------|----------|------------|
| PMU | 3 | 1 per module |
| PDU | 3 | 1 per module |
| SLF | 3 | 1 per module |
| RAS | 5 | Distributed across modules |
| SL | 5 | Distributed across modules |
| ROM | 19 | 9 program control + 6 fixed data + 4 executive control |
| **Total** | **28** | |

Each module is identified by its arithmetic unit. The system is divided into three modules with interconnected data and control word paths between circuits.

**ROM Allocation:**
- **9 Program Control ROMs:** Store the microprogram instructions
- **6 Fixed Data Storage ROMs:** Store mathematical constants, polynomial coefficients, lookup tables
- **4 Executive Control ROMs:** Store the executive scheduler that coordinates the 512 operations per frame

### 1.7 Chip Summary

| Chip | Part Number | Devices/Chip | Chip Size (mils) | Package | Function |
|------|-------------|-------------|-----------------|---------|----------|
| PMU | 944111 | 1,063 | — | 24-pin DIP | Parallel Multiplier Unit |
| PDU | 944112 | 1,241 | — | 24-pin DIP | Parallel Divider Unit |
| SLF | 944113 | 743 | 120 × 130 | 24-pin DIP | Special Logic Function (ALU core) |
| RAS | 944114 | 2,330 | 115 × 130 | 14-pin DIP | Random Access Storage (16×20-bit scratchpad) |
| SL  | 944118 | 771 | 128 × 133 | 24-pin DIP | Steering Logic (3-channel data mux) |
| ROM | 944125 | 1,269–3,268 | 143 × 150 | 14-pin DIP | Read-Only Memory (128×20-bit, 2560 bits/chip) |

**Total system devices:** 74,442 transistors (of which 62,092 in ROM program storage)

### 1.8 Redundancy and Self-Test
- The CADC is a fully redundant dual-channel system
- Real-time built-in self-test continuously runs diagnostic patterns
- Any single failure triggers automatic switchover to the redundant channel
- Inflight diagnostics are incorporated into the program ROM

---

## 2. FPGA Implementation Considerations

### 2.1 Clock Domain
For FPGA implementation, the original 5 MHz master clock and derived 375 kHz phase clocks should be reconstructed. The FPGA clock can run at a higher frequency with clock enables generating the original timing.

### 2.2 Data Path Width
All internal data paths are 20 bits wide. The FPGA implementation should use 20-bit signals throughout.

### 2.3 Serial vs Parallel
The original design used serial data transfer between chips to minimize pin count. For FPGA implementation, parallel 20-bit buses may be used internally with serial interfaces provided for external I/O compatibility.

### 2.4 Module Instantiation
The multi-processor arrangement should be preserved in the FPGA, with multiple instances of PMU, RAS, SLF, and ROM as per the original module configuration.

### 2.5 MOS-to-FPGA Mapping
- Original P-channel MOS logic → FPGA LUTs/FFs
- Original ROM chips → FPGA Block RAM or distributed ROM
- Original RAS → FPGA Block RAM or distributed RAM
- Original serial shift registers → Can be implemented as parallel registers with serial I/O wrappers

---

## 3. External Interfaces

### 3.1 Sensor Inputs
| Input | Type | Description |
|-------|------|-------------|
| Static Pressure (Ps) | Quartz sensor + 20-bit ADC | Altitude measurement |
| Dynamic Pressure (Qc) | Quartz sensor + 20-bit ADC | Airspeed/Mach measurement |
| Temperature (TAT) | Temperature sensor + ADC | Total air temperature |
| Analog Pilot Inputs | Analog signals | Pilot control settings |
| Digital Switch Inputs | Discrete digital | Pilot switch positions |

### 3.2 Control Outputs
| Output | Type | Description |
|--------|------|-------------|
| Wing Sweep | Servo control | Wing sweep position command |
| Maneuver Flaps | Servo control | Maneuver flap position command |
| Glove Vane | Servo control | Glove vane position command |
| Mach Number Display | 20-bit DAC | Cockpit Mach indicator |
| Altitude Display | 20-bit DAC | Cockpit altimeter |
| Airspeed Display | 20-bit DAC | Cockpit airspeed indicator |
| Vertical Speed Display | 20-bit DAC | Cockpit vertical speed indicator |

### 3.3 System Signals
| Signal | Description |
|--------|-------------|
| Master Clock (5 MHz) | System master oscillator input |
| Φ1, Φ2 (375 kHz) | Derived two-phase non-overlapping clocks |
| Word Mark | T18 of every word time |
| Frame Mark | T18 of final OP in frame |
| Redundancy Switch | Fail-over control between dual channels |
| BIT Status | Built-in test pass/fail indication |

---

## 4. Mathematical Functions

The CADC implements the following classes of computations:

1. **Polynomial evaluations** — For pressure/temperature conversions
2. **Trigonometric approximations** — Via polynomial series
3. **Division and multiplication** — Core arithmetic for all functions
4. **Square root** — Via iterative algorithms
5. **Gray-to-Binary / Binary-to-Gray conversion** — For sensor interface
6. **Rate limiting** — For wing sweep rate limiting
7. **Deadband functions** — For maneuver flap deadband
8. **Threshold functions** — For switch threshold detection
9. **Angle-of-attack correction** — Mechanization of AoA corrections
10. **Engine pressure ratio (EPR)** — Function computation

### 4.1 Scaling
All values are scaled to the fractional fixed-point range [-1.0, +1.0). Physical quantities are mapped to this range using known scale factors documented in the mechanization drawings.

---

## 5. Verification Strategy

### 5.1 Module-Level Testing
Each module (PMU, PDU, SLF, RAS, SL, ROM, I/O Bridge) shall have its own testbench with:
- Functional verification of all operations
- Boundary condition testing (max/min values, overflow, underflow)
- Timing verification against original specifications

### 5.2 System-Level Testing
- Full-frame simulation running all 512 operations
- Comparison against known-good results from original software simulation
- Sensor-to-display end-to-end verification
- Self-test diagnostic pattern verification

### 5.3 Test Vectors
Where possible, test vectors shall be derived from:
- Original AiResearch software simulation results
- Mathematical function tables from mechanization drawings
- Known input/output relationships for standard atmosphere conditions

---

## 6. Source References

All requirements in this specification are traceable to the following source documents. OCR text extractions are in the `ocr_text/` folder.

### 6.1 Primary Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p1-4-to-p1-34-.pdf** | Report pp. 1-4 to 1-7 | `ocr_text/p1-4-to-p1-34-.txt` | Supply voltage, system timing (5 MHz → 375 kHz Φ1/Φ2, 2.666μs bit time, 20 bits/word, WA/WO, word mark T18, 512 OPs/frame), data format (20-bit fractional fixed-point, sign + 19 data, 2's complement, bit weights) |
| **p1-4-to-p1-34-.pdf** | Report pp. 1-7 to 1-34 | `ocr_text/p1-4-to-p1-34-.txt` | All 6 chip device counts & sizes: PMU=1063, PDU=1241 (141×157 mils), SLF=743 (120×130), RAS=2330 (115×130), SL=771 (128×133), ROM=1269–3268 (143×150); package types (24-pin DIP, 14-pin DIP) |
| **p1-35-to-p2-28-.pdf** | Report pp. 1-35 to 1-42 | `ocr_text/p1-35-to-p2-28-.txt` | Module configuration (3 modules), ROM allocation, control word path, 20-bit CW breakdown, 512-OP frame cycle walkthrough |
| **p1-35-to-p2-28-.pdf** | Report pp. 2-21 to 2-22 | `ocr_text/p1-35-to-p2-28-.txt` | Throughput statistics — 300 multiplies, 105 divides, 225 adds/subs, 75 limits, 4 square roots, 20 AND/OR, 55 IF transfers per frame (~50% capacity) |
| **ap1-26-97.pdf** | pp. 1–2, 4–5, 7, 15 | `ocr_text/ap1-26-97.txt` | Design constraints (40 sq in, ≤10W), computational requirements, fixed-point fractional 20-bit rationale, word length, serial transfer decision, pipelining architecture, timing, 28-circuit breakdown |
| **Rays-…-Chapter-1-944111-PMU.pdf** | p. 2 | `ocr_text/Rays-…-Chapter-1-944111-PMU.txt` | System device count totals: 74,442 active MOS devices; 62,092 in ROM storage; per-chip breakdown |

### 6.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p2-29-to-p2-46-.pdf** | Report p. 2-46 | `ocr_text/p2-29-to-p2-46-.txt` | Inflight diagnostics — single-failure detection, dual-channel redundancy, BIT circuitry |
| **lsistate-97.pdf** | pp. 1–2, 6–8 | *(text-layer PDF)* | Design history & constraints, architecture decisions (parallel multi-processor, pipelining, serial transfer), F-14A delivery timeline, Moore's Law comparison |
| **CADC_Module_Specification.pdf** | pp. 1–4 | *(text-layer PDF)* | All module interface summaries for FPGA reconstruction |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | pp. 1–9 | *(text-layer PDF)* | Design sequence narrative — system design, logic design, chip manufacturing, first flight Dec 1970 |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Complete table of contents and figure list for Report 71-7266 |
