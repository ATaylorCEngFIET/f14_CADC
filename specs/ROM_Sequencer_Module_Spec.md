# ROM — Read-Only Memory + Sequencer (PN 944125)

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Part Number | 944125 |
| Device Count | 1,269 transistors (per ROM chip; multiple chips used) |
| Function | Program storage (microinstructions) + Data constants + Sequencer |
| Total Program Bits | ~62,092 devices dedicated to program storage |
| Microinstruction Width | 48 bits (reconstructed) |

### 2. Functional Description

The ROM subsystem serves three purposes:
1. **Control ROM:** Stores the microprogram (microinstructions) that control all chip operations
2. **Data ROM:** Stores constants and lookup tables used by the mathematical computations
3. **Sequencer:** Manages the micro-PC (program counter), instruction fetch, decode, and branching

#### 2.1 Microinstruction Format

The reconstructed 48-bit microinstruction word is organized as follows:

```
Bit:  47  40 | 39  32 | 31  28 | 27  24 | 23  20 | 19  16 | 15  12 | 11   8 |  7   4 |  3   0
      NEXTCTL | NEXTADR | ALU_OP | ACCCTL | RASCTL | SL_ACC | SL_RAS | PMUCTL | PDUCTL | IOCTL
```

| Field | Bits | Width | Description |
|-------|------|-------|-------------|
| NEXTCTL | 47–40 | 8 | Next address control (branch type) |
| NEXTADR | 39–32 | 8 | Next address / branch target |
| ALU_OP | 31–28 | 4 | SLF ALU operation code |
| ACCCTL | 27–24 | 4 | Accumulator control (write enables, source) |
| RASCTL | 23–20 | 4 | RAS control (read/write addr, write enable) |
| SL_ACC | 19–16 | 4 | Steering Logic ACC source select + enables |
| SL_RAS | 15–12 | 4 | Steering Logic RAS source select + enables |
| PMUCTL | 11–8 | 4 | PMU control (start, operand select) |
| PDUCTL | 7–4 | 4 | PDU control (start, operand select) |
| IOCTL | 3–0 | 4 | I/O Bridge control (direction, channel) |

#### 2.2 Sequencer Operations

The sequencer supports the following next-address control modes:

| NEXTCTL Code | Mode | Description |
|-------------|------|-------------|
| 00 | Sequential | micro_PC = micro_PC + 1 |
| 01 | Jump | micro_PC = NEXTADR |
| 02 | Branch on Zero | micro_PC = NEXTADR if Z=1, else PC+1 |
| 03 | Branch on Negative | micro_PC = NEXTADR if N=1, else PC+1 |
| 04 | Branch on Carry | micro_PC = NEXTADR if C=1, else PC+1 |
| 05 | Branch on PMU Busy | micro_PC = NEXTADR if PMU busy, else PC+1 |
| 06 | Branch on PDU Busy | micro_PC = NEXTADR if PDU busy, else PC+1 |
| 07 | Wait PMU | Hold PC until PMU done |
| 08 | Wait PDU | Hold PC until PDU done |
| 09 | Subroutine Call | Push PC+1, jump to NEXTADR |
| 0A | Return | Pop PC from stack |
| 0B-FF | Reserved | |

#### 2.3 ROM Chip Details (Original Design)
- **Part Number:** 944125
- **Active MOS Devices:** 3,268 per chip (largest chip in the system)
- **Chip Size:** 143 × 150 mils
- **Storage:** 2,560 bits per chip (128 words × 20 bits)
- **Access:** Random access and sequential access
- **Address Register:** Internal 7-bit register/counter for word selection
- **Chip Select:** 3-bit field (bits [9:7] of address) selects one of up to 8 ROMs in a group (current hardware limit: 4 per group due to output buffer drive capability)
- **Total program:** ~62,092 devices dedicated to stored program across multiple ROM chips

#### 2.4 ROM Address Management
The ROM contains an internal address register/counter with the following capabilities:
1. **Resettable (R):** Negative transition resets address to all zeros. Coincident with T8. Overrides all other inputs.
2. **Steppable (Increment):** Sequences through 128-word field
3. **Retain:** Holds present address (logical '1' during count interval)
4. **Load:** Accepts numerical input for independent address loading
5. **Add/Subtract:** Address modification by adding/subtracting

**Address Field Format:**
| Bits | Width | Function |
|------|-------|----------|
| [6:0] | 7 | Word select (one of 128 words) |
| [9:7] | 3 | ROM chip select (mask-decoded, one of 8) |
| [19:10] | 10 | Zero (unused) |

**Logic Input Priority:** Reset, Increment, Load, and Retain inputs are mutually exclusive, with Reset having highest priority. Add and Subtract inputs are mutually exclusive with each other. Load, Reset, Increment, or Retain override Add and Subtract inputs.

**Access Period (WAcc):** Defined as the period during which none of the following is at logical '1': retain, increment, load, add, subtract.

**Original I/O Pins:**
- **Inputs:** Add, Sub, Load, Retain, Reset, Increment, Φ1, Φ2, T18, Data In, VDD, Ground
- **Outputs:** Data Out (20-bit serial, wire-OR compatible), Parity Error

**Parity Error Detection:**
The ROM includes a built-in parity error output:
- A parity device changes state for every state change in the enabled data output
- During every 20-bit output period, the parity device will be '1' if there is an odd number of state changes on the data line
- The parity state at Φ1 negative transition of T19 should go to '0' and last until Φ1 of T0
- Parity devices in an associated group of ROMs are wire-OR'd together
- Parity error output is reset to '0' during WACC at Φ1 of T0

**F-14A CADC ROM Usage:**
The F-14A CADC uses only the **increment** address capability of the ROM. All data and address inputs except increment are grounded. Increment is connected to the appropriate signal for sequential addressing, controlled by the Executive Control software.

#### 2.5 Control ROM Size
- **512 operations** per frame × microinstructions per operation
- Program completely repeats every frame (~54.6 ms)
- Total ROM size determined by program requirements

#### 2.4 Data ROM
- Stores mathematical constants, polynomial coefficients, scale factors
- Addressed separately from control ROM
- Constants loaded into the data path via the SL `src_const` input

#### 2.5 Executive Control
- The sequencer implements executive control that schedules all 512 operations within a frame
- Operations are interleaved across multiple processor modules for parallel execution
- The frame mark resets the sequencer to the beginning of the program

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| **Clock & Reset** | | | |
| `clk` | Input | 1 | System clock |
| `rst` | Input | 1 | Synchronous reset — resets micro_PC to 0 |
| **Status Inputs** | | | |
| `flag_z` | Input | 1 | Zero flag from SLF |
| `flag_n` | Input | 1 | Negative flag from SLF |
| `flag_c` | Input | 1 | Carry flag from SLF |
| `pmu_busy` | Input | 1 | PMU busy status |
| `pdu_busy` | Input | 1 | PDU busy status |
| `frame_mark` | Input | 1 | Frame mark — resets to start of program |
| `word_mark` | Input | 1 | Word mark — T18 timing signal |
| **Control Outputs** | | | |
| `micro_addr` | Output | 10 | Current microinstruction address |
| `micro_word` | Output | 48 | Current microinstruction word |
| `alu_op` | Output | 4 | Decoded ALU operation for SLF |
| `acc_write_en` | Output | 1 | ACC write enable for SLF |
| `tmp_write_en` | Output | 1 | TMP write enable for SLF |
| `flags_write_en` | Output | 1 | Flags write enable for SLF |
| `ras_write_en` | Output | 1 | Write enable for RAS |
| `ras_read_addr` | Output | 6 | Read address for RAS |
| `ras_write_addr` | Output | 6 | Write address for RAS |
| `sel_acc_src` | Output | 3 | Steering Logic ACC source select |
| `sel_ras_src` | Output | 2 | Steering Logic RAS source select |
| `sel_io_src` | Output | 2 | Steering Logic I/O source select |
| `pmu_start` | Output | 1 | Start signal for PMU |
| `pdu_start` | Output | 1 | Start signal for PDU |
| `io_ctrl` | Output | 4 | I/O Bridge control signals |
| **Data ROM** | | | |
| `data_rom_addr` | Output | 10 | Data ROM read address |
| `data_rom_data` | Input | 20 | Data ROM read data (constant) |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_rom_sequencer is
    generic (
        CTRL_ROM_DEPTH : natural := 1024;  -- Microinstruction count
        DATA_ROM_DEPTH : natural := 512;   -- Data constant count
        UWORD_WIDTH    : natural := 48     -- Microinstruction width
    );
    port (
        -- Clock and Reset
        clk            : in  std_logic;
        rst            : in  std_logic;
        -- Status inputs
        flag_z         : in  std_logic;
        flag_n         : in  std_logic;
        flag_c         : in  std_logic;
        pmu_busy       : in  std_logic;
        pdu_busy       : in  std_logic;
        frame_mark     : in  std_logic;
        word_mark      : in  std_logic;
        -- Microinstruction output
        micro_addr     : out std_logic_vector(9 downto 0);
        micro_word     : out std_logic_vector(UWORD_WIDTH-1 downto 0);
        -- Decoded control signals
        alu_op         : out std_logic_vector(3 downto 0);
        acc_write_en   : out std_logic;
        tmp_write_en   : out std_logic;
        flags_write_en : out std_logic;
        ras_write_en   : out std_logic;
        ras_read_addr  : out std_logic_vector(5 downto 0);
        ras_write_addr : out std_logic_vector(5 downto 0);
        sel_acc_src    : out std_logic_vector(2 downto 0);
        sel_ras_src    : out std_logic_vector(1 downto 0);
        sel_io_src     : out std_logic_vector(1 downto 0);
        pmu_start      : out std_logic;
        pdu_start      : out std_logic;
        io_ctrl        : out std_logic_vector(3 downto 0);
        -- Data ROM interface
        data_rom_addr  : out std_logic_vector(9 downto 0);
        data_rom_data  : in  std_logic_vector(19 downto 0)
    );
end entity control_rom_sequencer;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| ROM-F-001 | Shall store the complete CADC microprogram | Must |
| ROM-F-002 | Shall implement a micro-PC with sequential increment | Must |
| ROM-F-003 | Shall implement unconditional jump (micro_PC = target) | Must |
| ROM-F-004 | Shall implement conditional branch on Z, N, C flags | Must |
| ROM-F-005 | Shall implement wait-for-PMU-done hold | Must |
| ROM-F-006 | Shall implement wait-for-PDU-done hold | Must |
| ROM-F-007 | Shall decode microinstruction fields to individual control signals | Must |
| ROM-F-008 | Micro-PC shall reset to 0 on `rst` or `frame_mark` | Must |
| ROM-F-009 | Microinstruction fetch shall be single-cycle | Must |
| ROM-F-010 | Data ROM shall provide constants to data path via SL | Must |
| ROM-F-011 | Control ROM should be loadable (Block RAM) for program updates | Should |
| ROM-F-012 | Shall support subroutine call/return with stack | Should |
| ROM-F-013 | Stack depth shall be at least 4 levels | Should |
| ROM-F-014 | All control outputs shall be registered (synchronous) | Must |
| ROM-F-015 | Branch-on-busy shall allow PMU/PDU to complete before proceeding | Must |

### 5. Verification Tests

#### 5.1 Sequential Execution Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-001 | Power-on reset | micro_PC = 0, first instruction fetched |
| ROM-T-002 | Sequential advance | micro_PC increments each cycle |
| ROM-T-003 | Multiple sequential instructions | Correct instructions fetched in order |

#### 5.2 Branch Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-010 | Unconditional jump | micro_PC = NEXTADR |
| ROM-T-011 | Branch on Z taken | Z=1, micro_PC = NEXTADR |
| ROM-T-012 | Branch on Z not taken | Z=0, micro_PC = PC+1 |
| ROM-T-013 | Branch on N taken | N=1, micro_PC = NEXTADR |
| ROM-T-014 | Branch on N not taken | N=0, micro_PC = PC+1 |
| ROM-T-015 | Branch on C taken | C=1, micro_PC = NEXTADR |
| ROM-T-016 | Branch on C not taken | C=0, micro_PC = PC+1 |

#### 5.3 Wait/Busy Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-020 | Wait PMU while busy | micro_PC held, same instruction |
| ROM-T-021 | Wait PMU when done | micro_PC advances |
| ROM-T-022 | Wait PDU while busy | micro_PC held |
| ROM-T-023 | Wait PDU when done | micro_PC advances |
| ROM-T-024 | Branch on PMU busy taken | PMU busy, branch taken |
| ROM-T-025 | Branch on PMU busy not taken | PMU not busy, fall through |

#### 5.4 Decode Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-030 | ALU_OP decode | `alu_op` matches bits [31:28] of microword |
| ROM-T-031 | ACC control decode | Write enables match ACCCTL field |
| ROM-T-032 | RAS control decode | Address and enables match RASCTL field |
| ROM-T-033 | Steering decode | SL select signals match SL_ACC and SL_RAS fields |
| ROM-T-034 | PMU control decode | `pmu_start` matches PMUCTL field |
| ROM-T-035 | PDU control decode | `pdu_start` matches PDUCTL field |
| ROM-T-036 | I/O control decode | `io_ctrl` matches IOCTL field |

#### 5.5 Frame Synchronization Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-040 | Frame mark resets PC | micro_PC = 0 after frame_mark |
| ROM-T-041 | Full frame execution | 512 operations complete, then frame_mark |
| ROM-T-042 | Word mark timing | Instructions execute on correct word boundaries |

#### 5.6 Subroutine Tests (if implemented)

| Test ID | Description | Criteria |
|---------|-------------|----------|
| ROM-T-050 | Call and return | Correct return address restored |
| ROM-T-051 | Nested calls (2 deep) | Both return addresses correct |
| ROM-T-052 | Stack overflow | Defined behavior on overflow |

#### 5.7 Testbench Structure

```vhdl
entity control_rom_sequencer_tb is
end entity control_rom_sequencer_tb;

architecture sim of control_rom_sequencer_tb is
    signal clk, rst : std_logic := '0';
    signal flag_z, flag_n, flag_c : std_logic := '0';
    signal pmu_busy, pdu_busy : std_logic := '0';
    signal frame_mark, word_mark : std_logic := '0';
    signal micro_addr : std_logic_vector(9 downto 0);
    signal micro_word : std_logic_vector(47 downto 0);
    signal alu_op : std_logic_vector(3 downto 0);
    -- ... other decoded signals ...
    
    constant CLK_PERIOD : time := 20 ns;
begin
    clk <= not clk after CLK_PERIOD / 2;
    
    -- DUT instantiation with test ROM content
    uut: entity work.control_rom_sequencer
        port map (...);
    
    stim: process
    begin
        -- Reset
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        
        -- Verify sequential execution from address 0
        for i in 0 to 9 loop
            wait until rising_edge(clk);
            assert micro_addr = std_logic_vector(to_unsigned(i, 10))
                report "Sequential execution failed at step " & integer'image(i)
                severity error;
        end loop;
        
        -- Test conditional branch: set Z flag, expect branch
        flag_z <= '1';
        -- Load a branch-on-Z instruction...
        wait until rising_edge(clk);
        -- Verify micro_PC jumped to target
        
        -- Test wait for PMU
        pmu_busy <= '1';
        -- Execute wait-PMU instruction
        -- Verify PC holds
        wait for 5 * CLK_PERIOD;
        pmu_busy <= '0';
        wait until rising_edge(clk);
        -- Verify PC advances
        
        report "Control ROM/Sequencer tests complete" severity note;
        wait;
    end process;
end architecture sim;
```

---

## 8. Source References

All requirements and design details in this specification are traceable to the following source documents. OCR text extractions are in the `ocr_text/` folder.

### 8.1 Primary Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p1-4-to-p1-34-.pdf** | Report pp. 1-31 to 1-34 | `ocr_text/p1-4-to-p1-34-.txt` | ROM circuit function — 2560-bit storage (128×20); 20-bit serial address (7-bit word + 3-bit chip select + 10 zeros); address register/counter (reset/step/increment/retain/load/add/sub); input priority (R > incr/load/retain > add/sub); access period (WAcc); wire-OR output; parity error; 1269–3268 devices; 143×150 mils; 14-pin DIP; PN 944125 |
| **Rays-…-Chapter-6-944125-ROM.pdf** | Pages 2–4+ | `ocr_text/Rays-F14A-CADC-…-Chapter-6-944125-ROM.txt` | Detailed logical spec: address management (reset/step/retain/load/add/sub), chip select (3-bit mask decode, up to 8 ROMs/group), parity error output (state change per data output, checked at Φ1 of T19→T0), wire-OR compatibility, timing |
| **p1-35-to-p2-28-.pdf** | Report pp. 1-35 to 1-42 | `ocr_text/p1-35-to-p2-28-.txt` | ROM allocation (Module 1: PMU+3 data+3 control; Module 2: PDU+1 data+3 control; Module 3: SLF+2 data+3 control), operating modes (data ROMs incr on WA, control ROMs incr on WO), ROM photo (3268 devices) |
| **p1-35-to-p2-28-.pdf** | Report pp. 2-9 to 2-21 | `ocr_text/p1-35-to-p2-28-.txt` | **Executive control** — 20-bit executive word bit assignments: D/A updates, digital outputs, BITE, sensor memory, ROM enables (bits 13–19), frame mark, discrete register step |
| **CADC_Module_Specification.pdf** | Section 6 | *(text-layer PDF)* | Reconstructed 48-bit microinstruction format: NEXTCTL(47–40), NEXTADR(39–32), ALU_OP(31–28), ACCCTL(27–24), RASCTL(23–20), SL_ACC(19–16), SL_RAS(15–12), PMUCTL(11–8), PDUCTL(7–4), IOCTL(3–0) |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p1-35-to-p2-28-.pdf** | Report pp. 2-20 to 2-21 | `ocr_text/p1-35-to-p2-28-.txt` | ROM enable strategy — exec bits 13–19 enable/disable ROM groups (14 ROMs saved at cost of 4 exec ROMs = net 10 saved) |
| **ap1-26-97.pdf** | pp. 12–13 | `ocr_text/ap1-26-97.txt` | ROM functional overview — sequential access in F-14A, wire-OR outputs, chip photograph |
| **Rays-…-Chapter-7-System-Info.pdf** | p. 3 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Pin assignments (944125, 14-pin): pin 1=RETAIN, 3=PARITY, 5=INCREMENT, 6=ADD, 7=SUB, 8=GRD, 9=RESET(FM), 10=LOAD, 11=T18, 12=Φ2, 13=Φ1, 14=VDD |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | pp. 5–7 | *(text-layer PDF)* | ROM programming process — math equations → sequence → binary (70,000 total bits), AMI format, paper tape |
| **p3-1-to-B1-.pdf** | Report pp. 3-1 to 3-2 | `ocr_text/p3-1-to-B1-.txt` | ROM data format, simulation program descriptions |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for ROM in Report 71-7266 |
