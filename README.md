# F-14A Central Air Data Computer (CADC) — FPGA Reconstruction

A modern FPGA implementation of the F-14A Tomcat's Central Air Data Computer, originally designed by Ray Holt at Garrett AiResearch in 1968-1970. This was arguably **the world's first microprocessor**, predating the Intel 4004 by two years but remaining classified until 1998.

## Overview

The CADC computes real-time air data parameters for the F-14A fighter aircraft:
- **Inputs:** Static pressure (Ps), impact pressure (Qc), total air temperature (TAT), angle of attack
- **Outputs:** Mach number, altitude, airspeed, vertical speed, wing sweep commands, flap/glove vane positions

### Original System Specifications

| Parameter | Value |
|-----------|-------|
| Word Width | 20 bits (1 sign + 19 magnitude) |
| Number Format | Sign-and-magnitude, fractional fixed-point |
| Master Clock | 1.5 MHz |
| Frame Time | ~54.6 ms (18.3 Hz update rate) |
| Operations/Frame | 512 (multiplies, divides, adds, sqrt, I/O) |
| Total Transistors | 74,442 (62,092 in ROM) |
| Unique Chip Types | 6 |
| Power | ≤10 watts |
| PCB Size | 4" × 10" |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CADC TOP LEVEL                             │
│                                                                 │
│   ┌──────────────┐    ┌─────────────┐    ┌─────────────┐       │
│   │   Timing     │    │  Control    │    │    I/O      │       │
│   │  Generator   │───►│    ROM +    │◄──►│   Bridge    │◄─► Sensors
│   │              │    │  Sequencer  │    │             │◄─► Displays
│   └──────────────┘    └──────┬──────┘    └─────────────┘       │
│                              │                                  │
│         ┌────────────────────┼────────────────────┐            │
│         ▼                    ▼                    ▼            │
│   ┌───────────┐       ┌───────────┐        ┌───────────┐       │
│   │    PMU    │       │    SL     │        │    SLF    │       │
│   │ (Multiply)│◄─────►│ (Steering │◄──────►│   (ALU)   │       │
│   │  944111   │       │   Logic)  │        │  944113   │       │
│   └───────────┘       │  944118   │        └─────┬─────┘       │
│                       │           │              │             │
│   ┌───────────┐       │           │        ┌─────┴─────┐       │
│   │    PDU    │◄─────►│           │◄──────►│    RAS    │       │
│   │  (Divide) │       │           │        │ (Register │       │
│   │  944112   │       └───────────┘        │   File)   │       │
│   └───────────┘                            │  944114   │       │
│                                            └───────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
f14-CADC/
├── hdl/                    # Synthesizable VHDL modules
│   ├── cadc_top.vhd       # Top-level integration
│   ├── timing_generator.vhd
│   ├── pmu.vhd            # Parallel Multiplier Unit
│   ├── pdu.vhd            # Parallel Divider Unit  
│   ├── slf.vhd            # Special Logic Function (ALU)
│   ├── ras.vhd            # Random Access Storage (16×20 registers)
│   ├── sl.vhd             # Steering Logic (data routing)
│   ├── control_rom_sequencer.vhd
│   └── io_bridge.vhd
├── tb/                     # VHDL testbenches
│   └── *_tb.vhd           # One testbench per module
├── sim/                    # Simulation batch files
│   └── run_*.bat          # Questa GUI simulation launchers
├── specs/                  # Design specifications
│   ├── CADC_System_Requirements.md
│   ├── CADC_Top_Level_Spec.md
│   └── *_Module_Spec.md   # Per-module specifications
├── ocr_text/              # OCR'd text from original documents
└── *.pdf                  # Original Ray Holt design notebooks
```

## Modules

| Module | Part # | Function | Devices |
|--------|--------|----------|---------|
| **PMU** | 944111 | 20×20 parallel multiply, Q1.19 result | 1,063 |
| **PDU** | 944112 | 20÷20 non-restoring division | 1,241 |
| **SLF** | 944113 | ALU (add/sub/and/or/xor/shift), flags (Z/N/C/V) | 743 |
| **RAS** | 944114 | 16×20-bit dual-port register file | 2,330 |
| **SL** | 944118 | 3-channel data multiplexer/router | 771 |
| **ROM** | 944125 | 128×20-bit microcode storage | 1,269–3,268 |

## Simulation

### Prerequisites
- **Questa** (or ModelSim) 2025.3 or later
- VHDL-2008 support

### Running Simulations

Each module has a dedicated batch file in `sim/`:

```batch
# Run individual module testbench with GUI and waveforms
sim\run_pmu.bat
sim\run_pdu.bat
sim\run_slf.bat
sim\run_ras.bat
sim\run_sl.bat
sim\run_timing_generator.bat
sim\run_control_rom_sequencer.bat
sim\run_io_bridge.bat
sim\run_cadc_top.bat
```

The batch files:
1. Compile the HDL and testbench
2. Generate a `.do` script with relevant signals
3. Launch Questa GUI with waveform viewer

### Test Results

| Module | Tests | Pass | Status |
|--------|-------|------|--------|
| timing_generator | 7 | 7 | ✅ |
| pmu | 20 | 18 | ⚠️ (2 edge-case overflow) |
| pdu | 8 | 8 | ✅ |
| slf | 53 | 53 | ✅ |
| ras | 18 | 18 | ✅ |
| sl | 14 | 14 | ✅ |
| control_rom_sequencer | 11 | 11 | ✅ |
| io_bridge | 12 | 12 | ✅ |
| cadc_top | 8 | 8 | ✅ |
| **Total** | **151** | **149** | **98.7%** |

## Coding Standards

All VHDL follows project coding standards:
- **Ports:** `i_` (input), `o_` (output), `io_` (bidirectional)
- **Generics:** `g_` prefix
- **Signals:** `s_` prefix
- **Constants:** `c_` prefix
- **Variables:** `v_` prefix
- **Types:** `t_` prefix
- **Keywords:** UPPERCASE
- **Identifiers:** lowercase with underscores

## Historical Significance

The CADC represents a pivotal moment in computing history:

- **1968:** Garrett AiResearch wins contract for F-14A air data computer
- **1970:** Ray Holt completes the 6-chip MOS-LSI design
- **1971:** CADC enters production — two years before Intel 4004 ships
- **1998:** Design declassified after 28 years of military secrecy
- **2026:** This FPGA reconstruction project

The CADC was a complete microprogrammed computer on six chips, computing complex aerodynamic equations in real-time. It pioneered concepts like:
- Microprogrammed control
- Pipelined parallel processing
- Serial/parallel hybrid arithmetic
- Purpose-built DSP architecture

## References

- Ray Holt's Design Notebooks (Chapters 1–7)
- AiResearch Report 71-7266
- "The Untold Story of the Invention of the Microprocessor" — Ray Holt, 1998

## License

This is an educational reconstruction for historical preservation. Original design by Ray Holt, Garrett AiResearch Division.

## Author

FPGA reconstruction by Adam Taylor, Adiuvo Engineering & Training Ltd.
