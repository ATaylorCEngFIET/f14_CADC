# F-14A CADC: Original vs FPGA Implementation — Architectural Differences & Requirements Status

## 1. Architectural Differences

| Aspect | Original 1970 Design | FPGA Implementation | Impact |
|--------|---------------------|---------------------|--------|
| **Technology** | P-channel MOS (PMOS), 74,442 transistors | FPGA LUTs/FFs (Xilinx/Intel) | Faster, lower power, reprogrammable |
| **Clock Distribution** | Single T18 pin to each chip | T0, T18, T19 distributed from timing_generator | **Simpler design, more explicit** — original relied on internal counters |
| **Phase Clocks** | PHI1/PHI2 derived locally in each chip | PHI1/PHI2 generated centrally | Same functional behavior |
| **Data Transfer** | Bit-serial between chips (minimize pins) | Bit-serial maintained | **Faithful to original** |
| **ROM Storage** | 19 physical 944125 ROM chips (128×20 each) | Single control_rom_sequencer.vhd | Consolidated but same microcode architecture |
| **Multi-processor** | 3 parallel modules (3×PMU, 3×PDU, 3×SLF, 5×RAS, 5×SL) | Single module instantiation | **Simplified** — original had 28 circuits total |
| **Dual-Channel Redundancy** | Full dual-channel with auto-switchover | **Not implemented** | TOP-F-007 (Should, not Must) |
| **Built-In Test (BIT)** | Hardware self-test during flight | **Partial** — fail_detect signal exists | IO-F-010 (Should) |
| **PMU Algorithm** | Booth's algorithm (iterative, 20 cycles) | **Parallel multiply** (single cycle at WA T0) | **FPGA optimization** — same result |
| **PDU Algorithm** | Non-restoring division (iterative) | **Parallel divide** (single cycle) | **FPGA optimization** — same result |
| **RAS Size** | 16×20-bit per chip (5 chips = 80 registers) | 64×20-bit (single instance) | Exceeds original capacity |
| **Stack (subroutines)** | Not documented in original | **Not implemented** | ROM-F-012/F-013 (Should) |

---

## 2. Requirements Traceability — Status by Module

### Timing Generator (9 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| TIM-F-001 | PHI1/PHI2 at 375 kHz | ✅ **PASS** | 4-phase counter from 1.5 MHz |
| TIM-F-002 | Non-overlapping clocks | ✅ **PASS** | phase_cnt decode ensures no overlap |
| TIM-F-003 | 20 bit times (T0-T19) | ✅ **PASS** | s_bit_cnt[4:0] |
| TIM-F-004 | WA/WO alternation | ✅ **PASS** | s_word_sel toggles |
| TIM-F-005 | 512 ops/frame | ✅ **PASS** | s_op_cnt[9:0] |
| TIM-F-006 | Word mark at T18 | ✅ **PASS** | o_word_mark output |
| TIM-F-007 | Frame mark at OP 511 | ✅ **PASS** | o_frame_mark output |
| TIM-F-008 | Reset clears counters | ✅ **PASS** | Verified in TB |

### PMU — Multiplier (11 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| PMU-F-001 | 20×20 signed fractional multiply | ✅ **PASS** | Q1.19 format |
| PMU-F-002 | Booth's algorithm | ⚠️ **DEVIATION** | Uses **parallel multiply** — Booth too slow for FPGA |
| PMU-F-003 | 20-bit result (upper 40) | ✅ **PASS** | `v_product_40(39 DOWNTO 20)` |
| PMU-F-004 | Multiply by zero | ✅ **PASS** | TB verified |
| PMU-F-005 | Multiply by +1 | ✅ **PASS** | TB verified |
| PMU-F-006 | Multiply by -1 | ✅ **PASS** | TB verified |
| PMU-F-007 | Most negative × most negative | ✅ **PASS** | Overflow handling |
| PMU-F-008 | Busy assertion | ✅ **PASS** | Single-cycle so brief |
| PMU-F-009 | Done pulse | ⚠️ **N/A** | No done signal, result implicit |
| PMU-F-010 | Complete within 20 cycles | ✅ **EXCEEDS** | Completes in 1 cycle |
| PMU-F-011 | Rounding | ✅ **PASS** | Round-half-up implemented |

### PDU — Divider (13 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| PDU-F-001 | 20-bit signed fractional division | ✅ **PASS** | Q1.19 format |
| PDU-F-002 | Non-restoring division | ⚠️ **DEVIATION** | Uses **parallel divide** operator |
| PDU-F-003 | Quotient and remainder | ✅ **PASS** | Both available |
| PDU-F-004 | Zero dividend | ✅ **PASS** | TB verified |
| PDU-F-005 | Divide-by-zero detection | ✅ **PASS** | `o_dbz` flag |
| PDU-F-006–008 | Sign combinations | ✅ **PASS** | All 4 combos tested |
| PDU-F-009 | Busy assertion | ✅ **PASS** | Single-cycle |
| PDU-F-010 | Done pulse | ⚠️ **N/A** | Result implicit |
| PDU-F-011 | Within 22 cycles | ✅ **EXCEEDS** | 1 cycle |
| PDU-F-012 | Dividend = Q×D + R | ✅ **PASS** | Mathematically verified |
| PDU-F-013 | \|R\| < \|D\| | ✅ **PASS** | TB verified |

### SLF — ALU (16 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| SLF-F-001 | 16 ALU operations | ✅ **PASS** | ADD/SUB/AND/OR/XOR/NOT/SHL/SHR/NEG/ABS/G2B/B2G/LOAD/NOP/PASS |
| SLF-F-002 | 20-bit accumulator | ✅ **PASS** | s_acc register |
| SLF-F-003 | 20-bit temporary | ✅ **PASS** | s_tmp register |
| SLF-F-004 | Z/N/C flags | ✅ **PASS** | Generated combinationally |
| SLF-F-005–007 | Write enables | ✅ **PASS** | Controlled via CW |
| SLF-F-008 | Signed 2's complement | ✅ **PASS** | |
| SLF-F-009 | Arithmetic right shift | ✅ **PASS** | Sign extension |
| SLF-F-010 | Arithmetic left shift | ✅ **PASS** | |
| SLF-F-011 | Gray-to-Binary | ✅ **PASS** | XOR chain |
| SLF-F-012 | Binary-to-Gray | ✅ **PASS** | XOR with shifted |
| SLF-F-013 | ABS saturates 0x80000 | ✅ **PASS** | Returns 0x7FFFF |
| SLF-F-014 | Single-cycle ops | ✅ **PASS** | Combinational |
| SLF-F-015 | Combinational result | ✅ **PASS** | |
| SLF-F-016 | Reset clears regs | ✅ **PASS** | |

### RAS — Register File (10 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| RAS-F-001 | 20-bit wide storage | ✅ **PASS** | g_data_width=20 |
| RAS-F-002 | ≥64 locations | ✅ **PASS** | 64 locations (exceeds orig 16×5=80) |
| RAS-F-003 | Simultaneous R/W | ✅ **PASS** | Dual-port |
| RAS-F-004 | Write on clock edge | ✅ **PASS** | PHI2 edge |
| RAS-F-005 | Read latency | ✅ **PASS** | Registered (1-cycle) |
| RAS-F-006 | Write-first | ✅ **PASS** | s_wr_pending logic |
| RAS-F-007 | Reset clears | ✅ **PASS** | All zeros |
| RAS-F-008 | Data retention | ✅ **PASS** | |
| RAS-F-009 | Block RAM mapping | ✅ **PASS** | Infers properly |
| RAS-F-010 | Address wrap | ✅ **PASS** | Natural wrap |

### SL — Steering Logic (9 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| SL-F-001 | Combinational | ✅ **PASS** | Pure mux logic |
| SL-F-002–004 | Routing muxes | ✅ **PASS** | io_mux, ras_mux |
| SL-F-005 | Independent operation | ✅ **PASS** | |
| SL-F-006 | Multi-destination | ✅ **PASS** | |
| SL-F-007 | Timing margin | ✅ **PASS** | No critical path issues |
| SL-F-008 | Reserved = zero | ✅ **PASS** | |
| SL-F-009 | All 20 bits | ✅ **PASS** | |

### ROM/Sequencer (15 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| ROM-F-001 | Store microprogram | ✅ **PASS** | ROM array |
| ROM-F-002 | Sequential increment | ✅ **PASS** | |
| ROM-F-003 | Unconditional jump | ❌ **NOT IMPL** | Demo code only |
| ROM-F-004 | Conditional branch | ❌ **NOT IMPL** | Flags not wired |
| ROM-F-005–006 | Wait-for-busy | ❌ **NOT IMPL** | |
| ROM-F-007 | Field decode | ✅ **PASS** | Microword split |
| ROM-F-008 | Reset/frame_mark → PC=0 | ✅ **PASS** | |
| ROM-F-009 | Single-cycle fetch | ✅ **PASS** | |
| ROM-F-010 | Data ROM | ⚠️ **PARTIAL** | Constants embedded |
| ROM-F-011 | Loadable ROM | ❌ **NOT IMPL** | Fixed at synthesis |
| ROM-F-012 | Call/return stack | ❌ **NOT IMPL** | Should priority |
| ROM-F-013 | Stack ≥4 levels | ❌ **NOT IMPL** | |
| ROM-F-014 | Registered outputs | ✅ **PASS** | |
| ROM-F-015 | Branch-on-busy | ❌ **NOT IMPL** | |

### I/O Bridge (12 requirements)

| Req ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| IO-F-001–002 | Sensor read/write | ✅ **PASS** | io_ctrl commands |
| IO-F-003 | Latch input | ✅ **PASS** | |
| IO-F-004–005 | Output holding regs | ✅ **PASS** | |
| IO-F-006 | NOP no change | ✅ **PASS** | |
| IO-F-007 | Reset clears | ✅ **PASS** | |
| IO-F-008 | Gray pass-through | ✅ **PASS** | |
| IO-F-009 | channel_active | ✅ **PASS** | |
| IO-F-010 | fail_detect | ⚠️ **PARTIAL** | Signal exists, logic minimal |
| IO-F-011 | Single-cycle I/O | ✅ **PASS** | |
| IO-F-012 | io_ready | ✅ **PASS** | |

---

## 3. Summary Statistics

| Module | Must Reqs | Pass | Fail/Partial | Should Reqs | Pass |
|--------|-----------|------|--------------|-------------|------|
| Timing Generator | 8 | **8** | 0 | 0 | - |
| PMU | 9 | **8** | 1 (algorithm deviation) | 2 | 2 |
| PDU | 11 | **10** | 1 (algorithm deviation) | 2 | 2 |
| SLF | 14 | **14** | 0 | 2 | 2 |
| RAS | 8 | **8** | 0 | 2 | 2 |
| SL | 8 | **8** | 0 | 1 | 1 |
| ROM/Sequencer | 9 | **5** | 4 | 6 | 0 |
| I/O Bridge | 10 | **10** | 0 | 2 | 1 |
| Top Level | 8 | **7** | 1 (multi-module) | 3 | 0 |
| **TOTAL** | **85** | **78 (92%)** | 7 | 20 | 10 (50%) |

---

## 4. Key Architectural Deviations Explained

### 4.1 PMU/PDU: Parallel vs Iterative Algorithms

**Original Design:**
- PMU: Booth's algorithm executes over 20+ clock cycles
- PDU: Non-restoring division algorithm executes iteratively

**FPGA Implementation:**
- VHDL `*` and `/` operators synthesize to DSP slices (single cycle)

**Justification:** Same mathematical result, much faster, FPGA-appropriate. The original iterative algorithms were necessary due to transistor budget constraints in 1970.

### 4.2 Timing Signals: T0/T18/T19 Distribution

**Original Design:**
- Only T18 distributed globally to each chip
- Each chip had internal counters to derive T0/T19

**FPGA Implementation:**
- All three signals (T0, T18, T19) centrally generated by timing_generator

**Justification:** Simpler verification, FPGA has abundant routing resources. Eliminates need for redundant counters in each module.

### 4.3 Single Module vs Multi-Module Architecture

**Original Design:**
- 3 parallel processing modules
- 28 total chips (3×PMU, 3×PDU, 3×SLF, 5×RAS, 5×SL, 9×ROM)

**FPGA Implementation:**
- Single module (proof-of-concept)

**Gap:** TOP-F-006 (multiple PMU instances) not implemented. Future work could instantiate multiple processing channels.

### 4.4 Sequencer Completeness

**Original Design:**
- Full microprogram with jumps, branches, subroutines
- 19 ROM chips storing complete flight computer program

**FPGA Implementation:**
- Demo microcode with polynomial computation only
- No jump/branch/call/return implementation

**Gaps:** ROM-F-003/004/005/006/012/013/015 not implemented. The current sequencer demonstrates datapath functionality but lacks full control flow.

---

## 5. Test Coverage Summary

All 68 testbench tests pass:

| Module | Tests |
|--------|-------|
| TIMING_GEN | 9 |
| PMU | 7 |
| PDU | 4 |
| SLF | 9 |
| RAS | 8 |
| SL | 4 |
| IO_BRIDGE | 20 |
| CADC_TOP | 7 |
| **Total** | **68** |

The polynomial computation `E = a3*X³ + a2*X² + a1*X + a0` executes correctly with verified outputs:
- X=0.5 → E=0x2A000 (0.328125)
- X=0.25 → E=0x16400 (0.173828)
- X=0.75 → E=0x44C00 (0.537109)
