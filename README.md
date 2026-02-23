# F-14A Central Air Data Computer (CADC) — FPGA Reconstruction

A modern FPGA implementation of the F-14A Tomcat's Central Air Data Computer, originally designed by Ray Holt at Garrett AiResearch in 1968-1970. This was arguably **the world's first microprocessor**, predating the Intel 4004 by two years but remaining classified until 1998.

## Overview

The CADC computes real-time air data parameters for the F-14A fighter aircraft:
- **Inputs:** Static pressure (Ps), impact pressure (Qc), total air temperature (TAT), angle of attack
- **Outputs:** Mach number, altitude, airspeed, vertical speed, wing sweep commands, flap/glove vane positions

### Original System Specifications

| Parameter | Value |
|-----------|-------|
| Word Width | 20 bits (1 sign + 19 fractional) |
| Number Format | 2's complement, fractional fixed-point |
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

---

## Timing Architecture

### Master Clock Hierarchy

```
Master Clock: 1.5 MHz (667 ns period)
    │
    ├── Phase Counter (4 states per bit time = 2.666 µs)
    │       Phase 0: Setup / bit_clk pulse
    │       Phase 1: PHI1 active
    │       Phase 2: Hold (register timing signals)
    │       Phase 3: PHI2 active (data shifts/latches)
    │
    ├── Bit Counter: T0-T19 (20 bits per word = 53.33 µs)
    │
    ├── Word Type: WA/WO alternating (2 words per operation = 106.67 µs)
    │
    └── Operation Counter: 0-511 (512 ops per frame = 54.6 ms)
```

### Phase Clock Generation

```
           Phase 0    Phase 1    Phase 2    Phase 3    Phase 0
              │          │          │          │          │
    clk ──────┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌──
              └──┘   └──┘   └──┘   └──┘   └──┘   └──┘   └──┘

    phi1 ─────────────┐                       ┌─────────────────
                      └───────────────────────┘

    phi2 ─────────────────────────┐                       ┌─────
                                  └───────────────────────┘

    bit_clk ──┐                                        ┌────────
              └────────────────────────────────────────┘

              ◄───────── One Bit Time (2.666 µs) ─────────►
```

### Word Timing (WA/WO)

Each operation consists of two 20-bit words:
- **WA (Word A)**: Control phase - microcode decoded, ALU computes
- **WO (Word O)**: Data phase - serial data flows between modules

```
                        One Operation (106.67 µs)
    ├─────────────────── WA ──────────────────┼─────────────────── WO ──────────────────┤
    
    T0  T1  T2  T3  T4  T5  T6  T7  T8 ... T18 T19 │ T0  T1  T2  T3 ... T18 T19
    ───┬───┬───┬───┬───┬───┬───┬───┬───────┬───┬───┼───┬───┬───┬───────┬───┬───
       │   │   │   │   │   │   │   │       │   │   │   │   │   │       │   │
       │   │   │   │   │   │   │   │       │   │   │   │   │   │       │   └── Last bit
       └───┴───┴───┴───┴───┴───┴───┘       │   │   │   │   │   │       │
       ◄── SLF receives CW bits 0-6 ──►    │   │   └───┴───┴───┴───────┴── Data shifts
                                           │   │
                      ALU compute at T8 ───┘   │
                                               │
                      Update regs at T18 ──────┘
```

---

## Inter-Module Timing

### Serial Data Output Compensation

All modules use timing compensation for serial outputs:

```
    Output Pattern: sr(0) WHEN t0='1' ELSE sr(1)
    
    ┌─────────────────────────────────────────────────────────────────────┐
    │ T0:  Output sr(0) directly (just loaded, shift hasn't happened)    │
    │ T1+: Output sr(1) (shift register already advanced by one)         │
    └─────────────────────────────────────────────────────────────────────┘
    
    This ensures the consuming module samples correct data after its PHI2 edge.
```

### PMU (Multiplier) Pipeline

```
    ┌───────────────────── WO_N ─────────────────────┐┌───────── WA_N+1 ─────────┐
    │                                                ││                          │
    │ T0 ────────────────────────────────────── T19  ││ T0 ─────────────── T19   │
    │  │                                         │   ││  │                       │
    │  │ ◄─── Shift in mcand (from ACC) ──────► │   ││  │                       │
    │  │ ◄─── Shift in mplier (from TMP) ─────► │   ││  │                       │
    │  │                                         │   ││  │                       │
    │  │                    Latch at T19 ────────┘   ││  │ Parallel multiply     │
    │  │                                             ││  │ Load product → sr     │
    └──┼─────────────────────────────────────────────┘└──┼───────────────────────┘
       │                                                 │
       │◄────── Operands shifting in ──────────────────►│
       │                                                 │◄─── Product ready ───►
       
    Product available during WO_N+1 (1 operation latency)
```

### PDU (Divider) Pipeline

```
    ┌───────────────────── WO_N ─────────────────────┐┌───────── WA_N+1 ─────────┐
    │                                                ││                          │
    │  ◄─── Shift in dividend (from ACC) ─────────► ││                          │
    │  ◄─── Shift in divisor (from TMP) ──────────► ││  Parallel divide at T0   │
    │                                                ││  (dividend << 20) / div  │
    │                    Latch operands at T19 ──────││  Load quotient → sr      │
    └────────────────────────────────────────────────┘└──────────────────────────┘

    Q1.19 fractional: dividend scaled by 2^20 before division
    Quotient available during WO_N+1
```

### SLF (ALU) Pipeline

```
    ┌──────────────────────────── WA ─────────────────────────────┐
    │                                                             │
    │  T0  T1  T2  T3  T4  T5  T6  T7   T8 .............. T18 T19 │
    │   │   │   │   │   │   │   │   │    │                 │   │  │
    │   │   │   │   │   │   │   │   │    │                 │   │  │
    │   └───┴───┴───┴───┴───┴───┴───┘    │                 │   │  │
    │   ◄── Receive CW bits 0-6 ────►    │                 │   │  │
    │              (serial)              │                 │   │  │
    │                                    │                 │   │  │
    │              Latch CW at T7 ───────┘                 │   │  │
    │                                                      │   │  │
    │              ALU compute at T8 ──────────────────────┘   │  │
    │                                                          │  │
    │              Update ACC/TMP at T18 ──────────────────────┘  │
    │              compute_done pulse ────────────────────────────┘
    └─────────────────────────────────────────────────────────────┘
    
    ┌──────────────────────────── WO ─────────────────────────────┐
    │                                                             │
    │  T0   T1 ......................................... T19      │
    │   │    │                                           │        │
    │   │    │ ◄─── Shift in data_bit to input_sr ────► │        │
    │   │    │ ◄─── Shift out acc_bit, tmp_bit ───────► │        │
    │   │    │                                           │        │
    │   │    │                   Latch input_lat at T19 ─┘        │
    │   │    │                                                    │
    │   │ Load acc_out_sr, tmp_out_sr from regs (compute_done)    │
    └───┼─────────────────────────────────────────────────────────┘
        │
        └── Used by PMU/PDU as operand sources during this WO
```

### RAS (RAM) Timing

```
    ┌─────────────────── WA ───────────────────┐┌─────────────────── WO ───────────────────┐
    │                                          ││                                          │
    │  T0                                      ││  T0 ─────────────────────────────── T19  │
    │   │                                      ││   │                                  │   │
    │   │ Latch rd_addr, wr_addr               ││   │ READ:  rd_data shifts out        │   │
    │   │ (from parallel microword)            ││   │        (from parallel latch)     │   │
    │   │                                      ││   │                                  │   │
    │   │ Load rd_data to shift register       ││   │ WRITE: wr_data shifts in         │   │
    │   │                                      ││   │        Set wr_pending at T19 ────┘   │
    └───┼──────────────────────────────────────┘└───┼──────────────────────────────────────┘
        │                                           │
        │                                           ▼
    ┌───┴───────────────── Next WA ────────────────────────────────┐
    │                                                              │
    │  PHI2 edge: If wr_pending, complete write to RAM             │
    │             Clear wr_pending                                 │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘
    
    Write completes ONE PHI2 cycle AFTER T19 (ensures all 20 bits shifted in)
```

### SL (Steering Logic) Timing

```
    ┌─────────────────── WA ───────────────────┐┌─────────────────── WO ───────────────────┐
    │                                          ││                                          │
    │  T0                                      ││                                          │
    │   │                                      ││   COMBINATIONAL MUX:                     │
    │   │ Latch sel_acc, sel_ras, sel_io       ││                                          │
    │   │ from parallel microword              ││   acc_in_bit  ← selected source          │
    │   │                                      ││   ras_wr_bit  ← selected source          │
    │   │                                      ││   io_out_bit  ← selected source          │
    │   │                                      ││                                          │
    └───┴──────────────────────────────────────┘└──────────────────────────────────────────┘
```

**SL IO Output Mux Encoding:**

| sel_io | Source |
|--------|--------|
| 00 | ACC |
| 01 | RAS |
| 10 | PMU |
| 11 | PDU_Q |

### I/O Bridge Timing

```
    ┌─────────────────── WA ───────────────────┐┌─────────────────── WO ───────────────────┐
    │                                          ││                                          │
    │  io_ctrl ACTIVE (gated by word_type=0)   ││  io_ctrl = NOP (gated off)               │
    │                                          ││                                          │
    │  READ:  Latch sensor → io_data_out_par   ││  Serialize: io_in_sr loads at T0         │
    │                                          ││             shifts out T1-T19            │
    │  WRITE: Capture io_out_sr → output reg   ││                                          │
    │                                          ││  Collect:   io_out_sr shifts in T0-T19   │
    │                                          ││                                          │
    └──────────────────────────────────────────┘└──────────────────────────────────────────┘
    
    ┌─────────────────────────────────────────────────────────────────────────────────────┐
    │ CRITICAL: io_ctrl is gated with word_type='0' (WA only)                             │
    │           Prevents write command from re-triggering during WO when io_out_sr is     │
    │           still shifting and contains partially-assembled data.                     │
    └─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Pipeline

### Instruction N vs N+1 Pipeline

The CADC uses a **pipelined architecture** where routing and computation are offset by one operation:

```
    ┌──────────────────────────────────────────────────────────────────────────────────┐
    │                          PIPELINE RULE                                           │
    │                                                                                  │
    │  To LOAD data from source X to ACC:                                              │
    │    Instruction N:   Set ACC_SRC = X in microword (routes during WO_N)           │
    │    Instruction N+1: Set ALU_OP = LOAD, acc_we = 1 (uses data latched at WO_N)   │
    └──────────────────────────────────────────────────────────────────────────────────┘
```

```
    Instruction N:    ┌─────── WA_N ────────┐┌─────── WO_N ────────┐
                      │  SL latches sel_acc │  Data routes via SL  │
                      │  from microword     │  to SLF input        │
                      └────────────────────┘└──────────┬───────────┘
                                                       │
                                                       ▼ Data latched in SLF input_lat
    Instruction N+1:  ┌─────── WA_N+1 ──────┐┌─────── WO_N+1 ───────┐
                      │  ALU computes using │  New data routing     │
                      │  latched input_lat  │                       │
                      └────────────────────┘└───────────────────────┘
```

---

## Polynomial Computation Example

Computing `E = ((a3*X + a2)*X + a1)*X + a0` via Horner's method:

```
┌──────┬────────────────────────────────────┬──────────────────────────────┬───────────┐
│ Inst │ WA Action                          │ WO Action                    │ ACC After │
├──────┼────────────────────────────────────┼──────────────────────────────┼───────────┤
│  0   │ sel_acc=IO, io_ctrl=read_ps        │ X routes to SLF              │    -      │
│  1   │ LOAD, acc_we=1                     │ (X arrives from WO0)         │    X      │
│  2   │ tmp_we=1                           │ -                            │ X, TMP=X  │
│  3   │ sel_acc=CONST[0]                   │ a3 routes to SLF             │    X      │
│  4   │ LOAD, acc_we=1                     │ (a3 arrives), PMU←(ACC,TMP)  │   a3      │
│  5   │ sel_acc=PMU, WAIT_PMU              │ a3*X computes, routes        │   a3      │
│  6   │ LOAD, sel_acc=CONST[1]             │ a3*X to ACC, a2 routes       │  a3*X     │
│  7   │ ADD, acc_we=1                      │ (a2 arrives), PMU←(v,X)      │ a3*X+a2   │
│  8   │ sel_acc=PMU, WAIT_PMU              │ (a3*X+a2)*X computes         │ a3*X+a2   │
│  9   │ LOAD, sel_acc=CONST[2]             │ result to ACC, a1 routes     │(a3X+a2)*X │
│ 10   │ ADD, acc_we=1                      │ (a1 arrives), PMU←(v,X)      │  ...+a1   │
│ 11   │ sel_acc=PMU, WAIT_PMU              │ final mult computes          │  ...+a1   │
│ 12   │ LOAD, sel_acc=CONST[3]             │ result to ACC, a0 routes     │((...)*X)  │
│ 13   │ ADD, acc_we=1                      │ (a0 arrives)                 │    E      │
│ 14   │ sel_io=ACC (NOP)                   │ E routes to io_out_sr        │    E      │
│ 15   │ sel_io=ACC (NOP)                   │ E fully collected            │    E      │
│ 16   │ sel_io=ACC, io_ctrl=write_mach     │ Capture E to output reg      │    E      │
│ 17   │ JUMP 17 (halt)                     │ -                            │    E      │
└──────┴────────────────────────────────────┴──────────────────────────────┴───────────┘
```

---

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

### Command Line Simulation

```powershell
# Compile all HDL and testbenches
vlib work
vcom -2008 hdl/timing_generator.vhd hdl/pmu.vhd hdl/pdu.vhd hdl/ras.vhd `
           hdl/sl.vhd hdl/slf.vhd hdl/io_bridge.vhd `
           hdl/control_rom_sequencer.vhd hdl/cadc_top.vhd
vcom -2008 tb/*.vhd

# Run top-level polynomial test
vsim -c work.cadc_top_tb -do "run -all; quit -f"

# Run individual module tests
vsim -c work.pmu_tb -do "run -all; quit -f"
vsim -c work.pdu_tb -do "run -all; quit -f"
vsim -c work.slf_tb -do "run -all; quit -f"
```

### Test Results

| Module | Tests | Pass | Status |
|--------|-------|------|--------|
| timing_generator | 9 | 9 | ✅ |
| pmu | 7 | 7 | ✅ |
| pdu | 4 | 4 | ✅ |
| slf | 9 | 9 | ✅ |
| ras | 8 | 8 | ✅ |
| sl | 4 | 4 | ✅ |
| io_bridge | 20 | 20 | ✅ |
| cadc_top | 7 | 7 | ✅ |
| **Total** | **68** | **68** | **100%** |

### Polynomial Verification (E = a3·X³ + a2·X² + a1·X + a0)

Coefficients: a3=0.125, a2=0.25, a1=0.375, a0=0.0625

| Input X | Hex | Result E | Hex | Decimal |
|---------|-----|----------|-----|---------|
| 0.5 | 0x40000 | 0.328125 | 0x2A000 | ✅ |
| 0.25 | 0x20000 | 0.173828 | 0x16400 | ✅ |
| 0.75 | 0x60000 | 0.537109 | 0x44C00 | ✅ |

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
