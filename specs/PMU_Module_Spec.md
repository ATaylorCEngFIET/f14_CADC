# PMU — Parallel Multiplier Unit (PN 944111)

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Part Number | 944111 |
| Device Count | 1,063 transistors |
| Function | 20×20-bit signed fractional multiplication |
| Algorithm | Booth's algorithm (modified) |
| I/O Style | Serial input, parallel internal, serial output (original); Parallel for FPGA |

### 2. Functional Description

The PMU performs **20-bit by 20-bit signed fractional multiplication** using a Booth-style algorithm. The result is a 20-bit signed fractional product (upper 20 bits of the 40-bit raw product, with appropriate rounding).

#### 2.1 Algorithm — Booth's Multiplication
Booth's algorithm reduces the number of partial products by encoding runs of 1's in the multiplier. For each pair of adjacent multiplier bits:

| B(i) | B(i-1) | Action |
|------|--------|--------|
| 0 | 0 | No operation (shift only) |
| 0 | 1 | Add multiplicand |
| 1 | 0 | Subtract multiplicand |
| 1 | 1 | No operation (shift only) |

This is performed iteratively over the 20 bits of the multiplier, producing a 40-bit raw result. The upper 20 bits (with sign extension and rounding) form the final result.

#### 2.2 Fractional Multiplication
Since both operands are fractional fixed-point numbers in [-1.0, +1.0):
- The product of two 20-bit fractional numbers produces a 40-bit result
- The PMU returns the upper 20 bits (bits [39:20] of the 40-bit result)
- This effectively performs: `result = (A × B) >> 20` with rounding

#### 2.3 Timing
- In the original design, multiplication executes during the WA word time (20 bit times)
- Operands are loaded serially during the previous WO word time
- For FPGA: multi-cycle operation, signaled by `busy`/`done`

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst` | Input | 1 | Synchronous reset (active high) |
| `start` | Input | 1 | Start multiplication pulse |
| `operand_a` | Input | 20 | Multiplicand (20-bit signed fractional) |
| `operand_b` | Input | 20 | Multiplier (20-bit signed fractional) |
| `result` | Output | 20 | Product (20-bit signed fractional) |
| `busy` | Output | 1 | High while multiplication in progress |
| `done` | Output | 1 | Pulses high for one cycle when result is valid |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pmu is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start     : in  std_logic;
        operand_a : in  std_logic_vector(19 downto 0);  -- Multiplicand
        operand_b : in  std_logic_vector(19 downto 0);  -- Multiplier
        result    : out std_logic_vector(19 downto 0);   -- Product
        busy      : out std_logic;
        done      : out std_logic
    );
end entity pmu;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| PMU-F-001 | Shall perform 20×20-bit signed fractional multiplication | Must |
| PMU-F-002 | Shall use Booth's algorithm for partial product generation | Must |
| PMU-F-003 | Shall produce a 20-bit result from upper bits of 40-bit product | Must |
| PMU-F-004 | Shall correctly handle multiplication by zero | Must |
| PMU-F-005 | Shall correctly handle multiplication by +1 (0x3FFFF in fractional) | Must |
| PMU-F-006 | Shall correctly handle multiplication by -1 (0x80000) | Must |
| PMU-F-007 | Shall correctly handle the most negative × most negative case | Must |
| PMU-F-008 | Shall assert `busy` during computation | Must |
| PMU-F-009 | Shall pulse `done` for exactly one clock cycle when result is valid | Must |
| PMU-F-010 | Shall complete multiplication within 20 clock cycles (one word time) | Should |
| PMU-F-011 | Result shall be rounded to nearest (round half up) | Should |

### 5. Verification Tests

#### 5.1 Basic Functionality Tests

| Test ID | Description | Input A | Input B | Expected Result |
|---------|-------------|---------|---------|-----------------|
| PMU-T-001 | Zero × Zero | 0x00000 | 0x00000 | 0x00000 |
| PMU-T-002 | Positive × Zero | 0x40000 (+0.5) | 0x00000 | 0x00000 |
| PMU-T-003 | 0.5 × 0.5 | 0x40000 | 0x40000 | 0x10000 (0.25) |
| PMU-T-004 | 0.5 × -0.5 | 0x40000 | 0xC0000 | 0xF0000 (-0.25) |
| PMU-T-005 | -0.5 × -0.5 | 0xC0000 | 0xC0000 | 0x10000 (+0.25) |
| PMU-T-006 | Max positive × Max positive | 0x7FFFF | 0x7FFFF | ~0x3FFFF |
| PMU-T-007 | Max negative × Max positive | 0x80000 | 0x7FFFF | ~0x80001 |
| PMU-T-008 | Max negative × Max negative | 0x80000 | 0x80000 | 0x7FFFF (saturate/overflow case) |
| PMU-T-009 | Unity approximation × value | 0x7FFFF | 0x40000 | ~0x40000 |

#### 5.2 Booth's Algorithm Edge Cases

| Test ID | Description | Notes |
|---------|-------------|-------|
| PMU-T-010 | Alternating bit pattern 0xAAAAA × 0x55555 | Tests all Booth transitions |
| PMU-T-011 | All ones pattern 0xFFFFF × 0xFFFFF | -1/524288 × -1/524288 |
| PMU-T-012 | Single bit set in each position | Verify each bit position contributes correctly |

#### 5.3 Timing Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| PMU-T-020 | Busy signal assertion | `busy` goes high on `start`, goes low when `done` |
| PMU-T-021 | Done pulse width | `done` is high for exactly 1 clock cycle |
| PMU-T-022 | Start during busy | New `start` during `busy` shall be ignored or restart |
| PMU-T-023 | Back-to-back operations | Can start new multiply immediately after `done` |
| PMU-T-024 | Reset during operation | `rst` during multiplication clears state, deasserts `busy` |

#### 5.4 Testbench Structure

```vhdl
-- PMU Testbench outline
entity pmu_tb is
end entity pmu_tb;

architecture sim of pmu_tb is
    signal clk, rst, start, busy, done : std_logic := '0';
    signal operand_a, operand_b, result : std_logic_vector(19 downto 0);
    
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz FPGA clock
begin
    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;
    
    -- DUT instantiation
    uut: entity work.pmu
        port map (clk, rst, start, operand_a, operand_b, result, busy, done);
    
    -- Stimulus process
    stim: process
        procedure do_multiply(a, b : std_logic_vector(19 downto 0);
                              expected : std_logic_vector(19 downto 0)) is
        begin
            operand_a <= a;
            operand_b <= b;
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1' and rising_edge(clk);
            assert result = expected
                report "Multiply failed" severity error;
        end procedure;
    begin
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        
        -- Run test vectors
        do_multiply(x"00000", x"00000", x"00000");  -- PMU-T-001
        do_multiply(x"40000", x"40000", x"10000");  -- PMU-T-003
        -- ... additional tests ...
        
        report "PMU tests complete" severity note;
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
| **p1-4-to-p1-34-.pdf** | Report pp. 1-7 to 1-9 | `ocr_text/p1-4-to-p1-34-.txt` | PMU circuit function — Booth's algorithm, serial M/R inputs (WO), parallel product (WA), rounded shift-out; pin assignments (Fig 1-3); 24-pin DIP (Fig 1-4); 1063 devices; 150×53 mils |
| **Rays-…-Chapter-1-944111-PMU.pdf** | Pages 2–4 | `ocr_text/Rays-F14A-CADC-…-Chapter-1-944111-PMU.txt` | Logical spec: Booth's algorithm, I/O pins, propagation delays (M→reg 125ns, reg→out 250ns), electrical chars (VDD=−14V), drive capability (75kΩ ∥ 40pF), input loading; 74,442 total system devices |
| **p3-1-to-B1-.pdf** | Appendix A | `ocr_text/p3-1-to-B1-.txt` | Booth's Algorithm — signed 2's complement multiplication, bit-pair encoding, shift with sign extension, worked examples |
| **CADC_Module_Specification.pdf** | Section 1 | *(text-layer PDF)* | Reconstructed FPGA interface: clk, rst, start, busy, done, operand_a, operand_b, result |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **ap1-26-97.pdf** | pp. 7, 12 | `ocr_text/ap1-26-97.txt` | PMU functional overview — serial I/O, continuous pipelined operation, no instruction word needed |
| **p2-29-to-p2-46-.pdf** | Report p. 2-46 | `ocr_text/p2-29-to-p2-46-.txt` | Inflight diagnostic test operands — 5 (M,R) sets detecting >98% single failures |
| **p3-1-to-B1-.pdf** | Report pp. 3-1 to 3-2 | `ocr_text/p3-1-to-B1-.txt` | Single failure analysis program — test word set determination |
| **Rays-…-Chapter-7-System-Info.pdf** | p. 3 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Pin assignments (944111, 24-pin): pin 1=GRD, 5=M IN, 8=P OUT, 9=M OUT, 10=Φ1, 18=R IN, 20=VDD |
| **lsistate-97.pdf** | p. 2 | *(text-layer PDF)* | Design constraints → Booth's algorithm selection rationale |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for PMU in Report 71-7266 |
