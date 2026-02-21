# SL — Steering Logic (PN 944118)

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Part Number | 944118 |
| Device Count | 771 transistors |
| Function | Combinational data routing fabric (multiplexer network) |
| Type | Purely combinational (no registers) |

### 2. Functional Description

The Steering Logic (SL) is a **three-channel serial digital data multiplexer**. Information is shifted serially through the device during WO. A 15-bit control word is accepted during WA that specifies which input or input combination is steered to each of three data outputs.

#### 2.1 Original Chip Details
- **Part Number:** 944118
- **Active MOS Devices:** 771
- **Chip Size:** 128 × 133 mils
- **Package:** 24-pin dual in-line
- **Inputs:** EXT1 through EXT13 (13 data inputs), T18, WO, CW (control word), Φ1, Φ2, VDD, Ground
- **Outputs:** Output 1 (M/D), Output 2 (D/Z), Output 3 (STOR), CW Out (delayed by 15 bits)

#### 2.2 Control Word Format
The 15-bit control word occupies the last 15 bits of the 20-bit CW. From LSB:
- **Bits [3:0]:** Selection for Output 1 (4 bits → 16 codes)
- **Bits [7:4]:** Selection for Output 2 (4 bits → 16 codes)
- **Bits [14:8]:** Selection for Output 3 (7 bits → 128 codes)

#### 2.3 Output 1 Selection Codes

| Code | Selected to Output 1 |
|------|---------------------|
| 0000 | EXT1 |
| 0001 | EXT2 |
| 0010 | EXT3 |
| 0011 | EXT4 |
| 0100 | EXT5 |
| 0101 | EXT6 |
| 0110 | EXT7 |
| 0111 | EXT8 |
| 1000 | EXT9 |
| 1001 | EXT10 |
| 1010 | EXT13 |
| 1011 | EXT1 |
| 1100 | EXT9 + EXT4 |
| 1101 | EXT10 + EXT4 |
| 1110 | EXT4 + EXT8 |
| 1111 | EXT2 (or EXT8) |

#### 2.4 Output 2 Selection Codes

| Code | Selected to Output 2 |
|------|---------------------|
| 0000 | EXT1 |
| 0001 | EXT2 |
| 0010 | EXT3 |
| 0011 | EXT4 |
| 0100 | EXT5 |
| 0101 | EXT6 |
| 0110 | EXT7 |
| 0111 | EXT8 |
| 1000 | EXT9 |
| 1001 | EXT10 |
| 1010 | T19 |
| 1011 | EXT1 |
| 1100 | EXT9 + EXT4 |
| 1101 | EXT10 + EXT4 |
| 1110 | EXT4 + EXT8 |
| 1111 | EXT2 (or EXT8) |

#### 2.5 Output 3 Selection Codes (7-bit, expanded)

| Code (7-bit) | Selected to Output 3 |
|-------------|---------------------|
| 0000000 | EXT1 |
| 0000001 | EXT2 |
| 0000010 | EXT3 |
| 0000011 | EXT4 |
| 0000100 | EXT5 |
| 0000101 | EXT6 |
| 0000110 | EXT7 |
| 0000111 | EXT9 |
| ... | Extended combinations with EXT additions (Z1, Z2 intermediate values) |

The Z-intermediate values allow compound routing:
- Z1 = EXT12 + EXT8
- Z2 = Z1 + EXT2, or Z1 - EXT2, Z1 + EXT4, Z1 - EXT4

#### 2.6 FPGA Implementation
For FPGA, the 13 external inputs (EXT1–EXT13) map to the data sources from other modules:

| Source | Width | Description |
|--------|-------|-------------|
| `src_ras` | 20 | Data read from RAS (scratchpad) |
| `src_acc` | 20 | Current ACC value from SLF |
| `src_tmp` | 20 | Current TMP register value from SLF |
| `src_pmu` | 20 | Result from PMU (multiplier) |
| `src_pdu_q` | 20 | Quotient from PDU (divider) |
| `src_pdu_r` | 20 | Remainder from PDU (divider) |
| `src_io_in` | 20 | Data from I/O Bridge (sensor input) |
| `src_const` | 20 | Constant from ROM data word |

#### 2.2 Destination Multiplexers

**ACC Source Select (`sel_acc_src`):**
Selects which source feeds the ALU/ACC input. This is a critical path as it determines what data the ALU operates on.

| sel_acc_src | Source |
|-------------|--------|
| 000 | src_ras |
| 001 | src_pmu |
| 010 | src_pdu_q |
| 011 | src_pdu_r |
| 100 | src_io_in |
| 101 | src_const |
| 110 | src_tmp |
| 111 | (reserved / zero) |

**RAS Write Source Select (`sel_ras_src`):**
Selects which source feeds the RAS write data port.

| sel_ras_src | Source |
|-------------|--------|
| 00 | src_acc |
| 01 | src_pmu |
| 10 | src_pdu_q |
| 11 | src_io_in |

**I/O Output Source Select (`sel_io_src`):**
Selects which source feeds the I/O Bridge output.

| sel_io_src | Source |
|------------|--------|
| 00 | src_acc |
| 01 | src_ras |
| 10 | src_pmu |
| 11 | src_pdu_q |

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| **Data Sources** | | | |
| `src_ras` | Input | 20 | RAS read data |
| `src_acc` | Input | 20 | ACC register value |
| `src_tmp` | Input | 20 | TMP register value |
| `src_pmu` | Input | 20 | PMU result |
| `src_pdu_q` | Input | 20 | PDU quotient |
| `src_pdu_r` | Input | 20 | PDU remainder |
| `src_io_in` | Input | 20 | I/O input data |
| `src_const` | Input | 20 | Constant from ROM |
| **Select Controls** | | | |
| `sel_acc_src` | Input | 3 | ACC input source select |
| `sel_ras_src` | Input | 2 | RAS write data source select |
| `sel_io_src` | Input | 2 | I/O output source select |
| **Routed Outputs** | | | |
| `acc_in` | Output | 20 | Selected data for ACC/ALU input |
| `ras_wr_data` | Output | 20 | Selected data for RAS write |
| `io_out` | Output | 20 | Selected data for I/O output |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sl is
    port (
        -- Data sources
        src_ras     : in  std_logic_vector(19 downto 0);
        src_acc     : in  std_logic_vector(19 downto 0);
        src_tmp     : in  std_logic_vector(19 downto 0);
        src_pmu     : in  std_logic_vector(19 downto 0);
        src_pdu_q   : in  std_logic_vector(19 downto 0);
        src_pdu_r   : in  std_logic_vector(19 downto 0);
        src_io_in   : in  std_logic_vector(19 downto 0);
        src_const   : in  std_logic_vector(19 downto 0);
        -- Select controls
        sel_acc_src : in  std_logic_vector(2 downto 0);
        sel_ras_src : in  std_logic_vector(1 downto 0);
        sel_io_src  : in  std_logic_vector(1 downto 0);
        -- Routed outputs
        acc_in      : out std_logic_vector(19 downto 0);
        ras_wr_data : out std_logic_vector(19 downto 0);
        io_out      : out std_logic_vector(19 downto 0)
    );
end entity sl;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| SL-F-001 | Shall be purely combinational (no clock, no registers) | Must |
| SL-F-002 | Shall route one of 8 sources to ACC input per `sel_acc_src` | Must |
| SL-F-003 | Shall route one of 4 sources to RAS write data per `sel_ras_src` | Must |
| SL-F-004 | Shall route one of 4 sources to I/O output per `sel_io_src` | Must |
| SL-F-005 | All three output muxes shall operate independently | Must |
| SL-F-006 | Same source may be routed to multiple destinations simultaneously | Must |
| SL-F-007 | Maximum propagation delay shall not exceed critical path budget | Should |
| SL-F-008 | Reserved select values shall output zero | Should |
| SL-F-009 | All 20 bits shall be routed (no bit swapping or modification) | Must |

### 5. Verification Tests

#### 5.1 ACC Source Selection Tests

| Test ID | Description | sel_acc_src | Expected Output |
|---------|-------------|-------------|-----------------|
| SL-T-001 | Route RAS to ACC | 000 | src_ras value |
| SL-T-002 | Route PMU to ACC | 001 | src_pmu value |
| SL-T-003 | Route PDU quotient to ACC | 010 | src_pdu_q value |
| SL-T-004 | Route PDU remainder to ACC | 011 | src_pdu_r value |
| SL-T-005 | Route I/O input to ACC | 100 | src_io_in value |
| SL-T-006 | Route constant to ACC | 101 | src_const value |
| SL-T-007 | Route TMP to ACC | 110 | src_tmp value |
| SL-T-008 | Reserved code 111 | 111 | 0x00000 |

#### 5.2 RAS Source Selection Tests

| Test ID | Description | sel_ras_src | Expected Output |
|---------|-------------|-------------|-----------------|
| SL-T-010 | Route ACC to RAS | 00 | src_acc value |
| SL-T-011 | Route PMU to RAS | 01 | src_pmu value |
| SL-T-012 | Route PDU quotient to RAS | 10 | src_pdu_q value |
| SL-T-013 | Route I/O input to RAS | 11 | src_io_in value |

#### 5.3 I/O Source Selection Tests

| Test ID | Description | sel_io_src | Expected Output |
|---------|-------------|------------|-----------------|
| SL-T-020 | Route ACC to I/O | 00 | src_acc value |
| SL-T-021 | Route RAS to I/O | 01 | src_ras value |
| SL-T-022 | Route PMU to I/O | 10 | src_pmu value |
| SL-T-023 | Route PDU quotient to I/O | 11 | src_pdu_q value |

#### 5.4 Independence Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| SL-T-030 | All three muxes select different sources | Each output reflects its selected source |
| SL-T-031 | All three muxes select same source | All outputs identical |
| SL-T-032 | Change one select, others stable | Only changed output updates |

#### 5.5 Data Integrity Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| SL-T-040 | All zeros through each path | Output = 0x00000 |
| SL-T-041 | All ones through each path | Output = 0xFFFFF |
| SL-T-042 | Unique pattern through each path | All 20 bits correctly routed |
| SL-T-043 | Walking ones through each source | Bit-level routing verification |

#### 5.6 Testbench Structure

```vhdl
entity sl_tb is
end entity sl_tb;

architecture sim of sl_tb is
    signal src_ras, src_acc, src_tmp, src_pmu : std_logic_vector(19 downto 0);
    signal src_pdu_q, src_pdu_r, src_io_in, src_const : std_logic_vector(19 downto 0);
    signal sel_acc_src : std_logic_vector(2 downto 0);
    signal sel_ras_src, sel_io_src : std_logic_vector(1 downto 0);
    signal acc_in, ras_wr_data, io_out : std_logic_vector(19 downto 0);
begin
    uut: entity work.sl
        port map (
            src_ras, src_acc, src_tmp, src_pmu,
            src_pdu_q, src_pdu_r, src_io_in, src_const,
            sel_acc_src, sel_ras_src, sel_io_src,
            acc_in, ras_wr_data, io_out
        );
    
    stim: process
    begin
        -- Set unique values on each source
        src_ras   <= x"11111";
        src_acc   <= x"22222";
        src_tmp   <= x"33333";
        src_pmu   <= x"44444";
        src_pdu_q <= x"55555";
        src_pdu_r <= x"66666";
        src_io_in <= x"77777";
        src_const <= x"88888";
        
        -- Test ACC source selection
        for i in 0 to 7 loop
            sel_acc_src <= std_logic_vector(to_unsigned(i, 3));
            sel_ras_src <= "00";
            sel_io_src <= "00";
            wait for 10 ns;
            -- Verify acc_in matches expected source
        end loop;
        
        -- Test RAS source selection
        sel_acc_src <= "000";
        for i in 0 to 3 loop
            sel_ras_src <= std_logic_vector(to_unsigned(i, 2));
            wait for 10 ns;
            -- Verify ras_wr_data matches expected source
        end loop;
        
        -- Test I/O source selection
        for i in 0 to 3 loop
            sel_io_src <= std_logic_vector(to_unsigned(i, 2));
            wait for 10 ns;
            -- Verify io_out matches expected source
        end loop;
        
        report "SL tests complete" severity note;
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
| **p1-4-to-p1-34-.pdf** | Report pp. 1-26 to 1-31 | `ocr_text/p1-4-to-p1-34-.txt` | SL circuit function — 3-channel serial digital data multiplexer; 15-bit CW; Output 1 selection codes (4 bits, 16 codes: EXT1–EXT10, EXT13, sums); Output 2 codes (4 bits, incl. T19); Output 3 codes (7 bits, extended with Z1/Z2 intermediates, A+B+C); addition/subtraction during transfer; 771 devices; 128×133 mils; 24-pin DIP; PN 944118 |
| **Rays-…-Chapter-5-944118-Steering.pdf** | Pages 2–4+ | `ocr_text/Rays-F14A-CADC-…-Chapter-5-944118-Steering.txt` | Detailed logical spec: 15-bit CW during WA (first 5 bits pass-through to CW OUT), 13 data inputs (EXT1–EXT13), 4 outputs (Output 1/2/3, CW Out), complete selection code tables, T18 signal, addition/subtraction capability |
| **ap1-26-97.pdf** | pp. 9–12 | `ocr_text/ap1-26-97.txt` | **Detailed** SL functional description — 3-channel multiplexer, 15-bit instruction word (4+4+7 bits), complete Output 1/2/3 code tables with all EXT mappings, Output 3 A+B+C addition, CW pass-through, zero-time add/subtract |
| **CADC_Module_Specification.pdf** | Section 5 | *(text-layer PDF)* | Reconstructed FPGA interface: src_ras, src_acc, src_tmp, src_pmu, src_pdu_q, src_pdu_r, src_io_in, src_const, sel controls, routed outputs |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p1-35-to-p2-28-.pdf** | Report pp. 1-40 to 1-41 | `ocr_text/p1-35-to-p2-28-.txt` | Module CW breakdown — how 20-bit CW splits: first 5 bits → RAS/SLF, last 15 bits → SL; module-specific bit assignments |
| **Rays-…-Chapter-7-System-Info.pdf** | p. 3 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Pin assignments (944118, 24-pin): pin 1=EXT12, 2=EXT2, 3=EXT4, 6=CW OUT, 7=OUT 2, 8=OUT 3, 14=EXT10, 18=EXT1, 20=EXT13 |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for SL in Report 71-7266 |
