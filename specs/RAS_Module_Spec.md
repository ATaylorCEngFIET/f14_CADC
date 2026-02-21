# RAS — Random Access Storage (PN 944114)

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Part Number | 944114 |
| Device Count | 2,330 transistors |
| Function | Local scratchpad RAM for intermediate computational values |
| Size | Estimated 64 × 20-bit words (based on device count) |
| Access | Single-port or dual-port (read + write per cycle) |

### 2. Functional Description

The RAS provides **local scratchpad memory** for storing intermediate computational values during the CADC's real-time processing cycle. Each computing module in the multi-processor configuration has its own RAS instance.

#### 2.1 Memory Organization (Original Design)
- **Word width:** 20 bits (matching the CADC data word size)
- **Depth:** 16 words (4-bit address from control word)
- **Total storage:** 16 × 20 = 320 bits
- **Device count:** 2,330 active MOS devices
- **Chip size:** 115 × 130 mils
- **Package:** 14-pin dual in-line

#### 2.2 Original Serial Access Protocol
The original RAS operates as a **16-word random access read-write storage device** with serial I/O:

- A **5-bit control word** is accepted during WA:
  - **Bits [3:0]:** Select one of 16 twenty-bit serial registers (address)
  - **Bit [4]:** Write enable — if '1', data input is written to selected register during next WO; if '0', register contents remain unaffected
- **Readout is non-destructive:** If a register is selected for read only, data is also rewritten into the selected register
- **Inhibit Write (IW):** External logic input that prevents writing when true. Should be true during WO and false during WA

**Timing:**
| Phase | Action |
|-------|--------|
| WA1 | Enter control word |
| WO1 | Contents of selected register shifted out serially; if write bit true, new data written in |
| WA2 | Contents of selected register from CW shifted out serially |
| WO2 | Enter new control word |

**Original I/O Pins:**
- **Inputs:** DI (data in), CW (control word), IW (inhibit write), T18, WO, Φ1, Φ2, VDD, Ground
- **Outputs:** DO (data out)

#### 2.3 FPGA Implementation (Parallel Access)
For FPGA implementation, the serial access is converted to parallel:
- Full 20-bit read/write per clock cycle
- Address width expanded to 6 bits (64 words) for additional storage if needed
- Write enable replaces the serial control word protocol
- Inhibit write can be implemented as an additional gate on write enable

#### 2.4 Data Retention
- RAS values are maintained throughout the computational frame
- Values carry over between frames (no automatic clearing)
- Only explicit writes modify stored values
- Reset clears all memory locations to zero

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst` | Input | 1 | Synchronous reset (active high) — clears all locations |
| `read_addr` | Input | 6 | Read address (0–63) |
| `read_data` | Output | 20 | Data read from addressed location |
| `write_addr` | Input | 6 | Write address (0–63) |
| `write_data` | Input | 20 | Data to write |
| `write_en` | Input | 1 | Write enable — data written on rising clock edge |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ras is
    generic (
        ADDR_WIDTH : natural := 6;    -- 64 words
        DATA_WIDTH : natural := 20    -- 20-bit words
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        read_addr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        read_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        write_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        write_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        write_en   : in  std_logic
    );
end entity ras;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| RAS-F-001 | Shall provide 20-bit wide random access storage | Must |
| RAS-F-002 | Shall support at least 64 addressable locations | Must |
| RAS-F-003 | Shall support simultaneous read and write to different addresses | Must |
| RAS-F-004 | Write shall occur on rising clock edge when `write_en` is asserted | Must |
| RAS-F-005 | Read shall be asynchronous (combinational) or synchronous with 1-cycle latency | Must |
| RAS-F-006 | Read-during-write to same address: new data forwarded (write-first) | Should |
| RAS-F-007 | Reset shall clear all locations to zero | Must |
| RAS-F-008 | Data shall be retained between clock cycles when not written | Must |
| RAS-F-009 | FPGA implementation should map to Block RAM or distributed RAM | Should |
| RAS-F-010 | Address out of range shall have defined behavior (wrap or read zero) | Should |

### 5. Verification Tests

#### 5.1 Basic Read/Write Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| RAS-T-001 | Write then read same address | Read back matches written data |
| RAS-T-002 | Write to address 0, read back | Correct data at address 0 |
| RAS-T-003 | Write to max address (63), read back | Correct data at address 63 |
| RAS-T-004 | Write all ones (0xFFFFF), read back | All ones returned |
| RAS-T-005 | Write alternating pattern, read back | Pattern preserved |

#### 5.2 Address Independence Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| RAS-T-010 | Write different data to adjacent addresses | Each address returns its own data |
| RAS-T-011 | Write to all 64 addresses sequentially | All values retained and independently readable |
| RAS-T-012 | Overwrite a location | New value replaces old value |
| RAS-T-013 | Non-written locations retain initial value | After reset, unwritten locations read 0 |

#### 5.3 Concurrent Access Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| RAS-T-020 | Simultaneous read/write different addresses | Both operations succeed independently |
| RAS-T-021 | Read-during-write same address | Defined behavior (write-first or read-old) |

#### 5.4 Reset Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| RAS-T-030 | Reset after writing data | All locations read back as 0 |
| RAS-T-031 | Reset clears all 64 locations | Verify every address reads 0 after reset |

#### 5.5 Write Enable Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| RAS-T-040 | Write disabled, data unchanged | Location retains previous value |
| RAS-T-041 | Write enabled for one cycle only | Only targeted location changes |

#### 5.6 Testbench Structure

```vhdl
entity ras_tb is
end entity ras_tb;

architecture sim of ras_tb is
    signal clk, rst, write_en : std_logic := '0';
    signal read_addr, write_addr : std_logic_vector(5 downto 0);
    signal read_data, write_data : std_logic_vector(19 downto 0);
    
    constant CLK_PERIOD : time := 20 ns;
begin
    clk <= not clk after CLK_PERIOD / 2;
    
    uut: entity work.ras
        port map (clk, rst, read_addr, read_data, write_addr, write_data, write_en);
    
    stim: process
    begin
        -- Reset
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        
        -- Write 0xABCDE to address 5
        write_addr <= "000101";
        write_data <= x"ABCDE";
        write_en <= '1';
        wait until rising_edge(clk);
        write_en <= '0';
        
        -- Read from address 5
        read_addr <= "000101";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert read_data = x"ABCDE"
            report "RAS read/write failed" severity error;
        
        -- Verify other address is still 0
        read_addr <= "000110";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert read_data = x"00000"
            report "RAS isolation failed" severity error;
        
        -- Write all 64 locations
        for i in 0 to 63 loop
            write_addr <= std_logic_vector(to_unsigned(i, 6));
            write_data <= std_logic_vector(to_unsigned(i * 1000, 20));
            write_en <= '1';
            wait until rising_edge(clk);
        end loop;
        write_en <= '0';
        
        -- Read all back
        for i in 0 to 63 loop
            read_addr <= std_logic_vector(to_unsigned(i, 6));
            wait until rising_edge(clk);
            wait for 1 ns;
            assert read_data = std_logic_vector(to_unsigned(i * 1000, 20))
                report "RAS data mismatch at address " & integer'image(i)
                severity error;
        end loop;
        
        report "RAS tests complete" severity note;
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
| **p1-4-to-p1-34-.pdf** | Report pp. 1-21 to 1-26 | `ocr_text/p1-4-to-p1-34-.txt` | RAS circuit function — 16-word random access R/W storage; serial I/O (WO); non-destructive readout; 5-bit CW during WA (4-bit address + 1-bit write enable); register select table (0000=Reg 1 … 1111=Reg 16); inhibit write input; timing (WAI→CW, WO1→data shift); 2330 devices; 115×130 mils; 14-pin DIP; PN 944114 |
| **Rays-…-Chapter-4-944114-RAS.pdf** | Pages 2–4+ | `ocr_text/Rays-F14A-CADC-…-Chapter-4-944114-RAS.txt` | Detailed logical spec: 5-bit CW (bits [3:0] register select, bit [4] write enable), non-destructive readout, inhibit write (active WO, false WA), register selection table, data I/O timing, electrical characteristics |
| **CADC_Module_Specification.pdf** | Section 4 | *(text-layer PDF)* | Reconstructed FPGA interface: clk, rst, read_addr, read_data, write_addr, write_data, write_en |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **ap1-26-97.pdf** | pp. 12–13 | `ocr_text/ap1-26-97.txt` | RAS functional overview — 16-word R/W, 5-bit instruction word, register select codes, inhibit write, chip photograph |
| **Rays-…-Chapter-7-System-Info.pdf** | p. 3 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Pin assignments (944114, 14-pin): pin 1=DATA IN, 3=DATA OUT, 4=WO, 8=GRD, 11=Φ1, 12=IW, 14=VDD |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for RAS in Report 71-7266 |
