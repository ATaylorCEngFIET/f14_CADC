# PDU — Parallel Divider Unit (PN 944112)

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Part Number | 944112 |
| Device Count | 1,241 transistors |
| Function | 20-bit signed fractional division |
| Algorithm | Non-restoring division |
| I/O Style | Serial input, parallel internal, serial output (original); Parallel for FPGA |

### 2. Functional Description

The PDU performs **20-bit signed fractional division** using a non-restoring division algorithm. It produces both a 20-bit quotient and a 20-bit remainder.

#### 2.1 Algorithm — Non-Restoring Division

Non-restoring division avoids the "restore" step of restoring division by allowing the partial remainder to go negative. At each step:

1. If partial remainder is **positive**: shift left and **subtract** divisor
2. If partial remainder is **negative**: shift left and **add** divisor
3. Record quotient bit: 1 if partial remainder ≥ 0, 0 if negative

After all 20 iterations:
- If final remainder is negative, add divisor to correct (restore once at end)
- Quotient bits are in {0, 1} but need correction: convert from {-1, +1} encoding to standard binary

#### 2.2 Fractional Division
- Dividend (A) and Divisor (B) are 20-bit signed fractional numbers
- Quotient Q = A / B (20-bit signed fractional)
- **Pre-condition:** |Dividend| < |Divisor| to avoid overflow (result > 1.0)
- If |A| ≥ |B|, the result overflows and behavior is undefined (software must ensure valid inputs)

#### 2.3 Timing
- Division executes during the WA word time (20 bit times) in the original design
- For FPGA: multi-cycle operation (up to 20+ cycles), signaled by `busy`/`done`

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst` | Input | 1 | Synchronous reset (active high) |
| `start` | Input | 1 | Start division pulse |
| `dividend` | Input | 20 | Dividend (20-bit signed fractional) |
| `divisor` | Input | 20 | Divisor (20-bit signed fractional) |
| `quotient` | Output | 20 | Quotient (20-bit signed fractional) |
| `remainder` | Output | 20 | Remainder (20-bit signed fractional) |
| `busy` | Output | 1 | High while division in progress |
| `done` | Output | 1 | Pulses high for one cycle when result valid |
| `div_by_zero` | Output | 1 | Asserted if divisor is zero |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pdu is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        dividend    : in  std_logic_vector(19 downto 0);
        divisor     : in  std_logic_vector(19 downto 0);
        quotient    : out std_logic_vector(19 downto 0);
        remainder   : out std_logic_vector(19 downto 0);
        busy        : out std_logic;
        done        : out std_logic;
        div_by_zero : out std_logic
    );
end entity pdu;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| PDU-F-001 | Shall perform 20-bit signed fractional division | Must |
| PDU-F-002 | Shall use non-restoring division algorithm | Must |
| PDU-F-003 | Shall produce both quotient and remainder | Must |
| PDU-F-004 | Shall handle division of zero dividend correctly (result = 0) | Must |
| PDU-F-005 | Shall detect and flag divide-by-zero | Must |
| PDU-F-006 | Shall correctly handle negative dividend and positive divisor | Must |
| PDU-F-007 | Shall correctly handle positive dividend and negative divisor | Must |
| PDU-F-008 | Shall correctly handle negative dividend and negative divisor | Must |
| PDU-F-009 | Shall assert `busy` during computation | Must |
| PDU-F-010 | Shall pulse `done` for exactly one clock cycle when result valid | Must |
| PDU-F-011 | Shall complete division within 22 clock cycles | Should |
| PDU-F-012 | Quotient shall satisfy: dividend = quotient × divisor + remainder | Must |
| PDU-F-013 | |Remainder| < |Divisor| | Must |

### 5. Verification Tests

#### 5.1 Basic Functionality Tests

| Test ID | Description | Dividend | Divisor | Expected Quotient |
|---------|-------------|----------|---------|-------------------|
| PDU-T-001 | Zero / positive | 0x00000 | 0x40000 (+0.5) | 0x00000 |
| PDU-T-002 | 0.25 / 0.5 | 0x20000 | 0x40000 | 0x40000 (+0.5) |
| PDU-T-003 | 0.5 / (-0.5) | 0x40000 (note: invalid - |A|=|B|) | -- | overflow |
| PDU-T-004 | 0.25 / (-0.5) | 0x20000 | 0xC0000 | 0xC0000 (-0.5) |
| PDU-T-005 | (-0.25) / (-0.5) | 0xE0000 | 0xC0000 | 0x40000 (+0.5) |
| PDU-T-006 | (-0.25) / 0.5 | 0xE0000 | 0x40000 | 0xC0000 (-0.5) |
| PDU-T-007 | Small / Large | 0x00001 | 0x7FFFF | ~0x00001 |

#### 5.2 Division by Zero

| Test ID | Description | Criteria |
|---------|-------------|----------|
| PDU-T-010 | Divide by zero | `div_by_zero` asserted, `done` asserted, quotient undefined |

#### 5.3 Remainder Verification

| Test ID | Description | Criteria |
|---------|-------------|----------|
| PDU-T-020 | Verify remainder for all basic tests | dividend = quotient × divisor + remainder |
| PDU-T-021 | Remainder magnitude | |remainder| < |divisor| for all valid inputs |

#### 5.4 Non-Restoring Algorithm Specific Tests

| Test ID | Description | Notes |
|---------|-------------|-------|
| PDU-T-030 | Alternating partial remainder signs | Exercise both add and subtract paths |
| PDU-T-031 | All positive shifts | Dividend much smaller than divisor |
| PDU-T-032 | Maximum iterations | Worst-case timing verification |

#### 5.5 Timing Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| PDU-T-040 | Busy signal assertion | `busy` goes high on `start`, low when `done` |
| PDU-T-041 | Done pulse width | `done` high for exactly 1 clock |
| PDU-T-042 | Start during busy | Ignored or restart |
| PDU-T-043 | Back-to-back operations | Start new divide immediately after `done` |
| PDU-T-044 | Reset during operation | Clears state, deasserts `busy` |

#### 5.6 Testbench Structure

```vhdl
entity pdu_tb is
end entity pdu_tb;

architecture sim of pdu_tb is
    signal clk, rst, start, busy, done, div_by_zero : std_logic := '0';
    signal dividend, divisor, quotient, remainder : std_logic_vector(19 downto 0);
    
    constant CLK_PERIOD : time := 20 ns;
begin
    clk <= not clk after CLK_PERIOD / 2;
    
    uut: entity work.pdu
        port map (clk, rst, start, dividend, divisor, quotient, remainder,
                  busy, done, div_by_zero);
    
    stim: process
        procedure do_divide(a, b : std_logic_vector(19 downto 0);
                            exp_q : std_logic_vector(19 downto 0)) is
        begin
            dividend <= a;
            divisor <= b;
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1' and rising_edge(clk);
            assert quotient = exp_q
                report "Division failed" severity error;
            -- Verify remainder relationship
            -- dividend = quotient * divisor + remainder (in fractional)
        end procedure;
    begin
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        
        do_divide(x"00000", x"40000", x"00000");  -- PDU-T-001
        do_divide(x"20000", x"40000", x"40000");  -- PDU-T-002
        
        report "PDU tests complete" severity note;
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
| **p1-4-to-p1-34-.pdf** | Report pp. 1-10 to 1-14 | `ocr_text/p1-4-to-p1-34-.txt` | PDU circuit function — non-restoring division, serial D/Z inputs (WO), parallel quotient (WA), truncated shift-out; pin assignments (Fig 1-6); 24-pin DIP (Fig 1-7); 1241 devices; 141×157 mils; PN 944112 |
| **Rays-…-Chapter-2-944112-PDU.pdf** | Pages 2–4 | `ocr_text/Rays-F14A-CADC-…-Chapter-2-944112-PDU.txt` | Logical spec: non-restoring division, I/O pins, electrical chars (VDD=−14V), power dissipation (−55°C to +125°C), clock characteristics, logic levels, drive capability (75kΩ ∥ 40pF), input loading |
| **p3-1-to-B1-.pdf** | Appendix B | `ocr_text/p3-1-to-B1-.txt` | Non-restoring Division Algorithm — positive/negative partial remainder steps, quotient bit determination, final correction |
| **CADC_Module_Specification.pdf** | Section 2 | *(text-layer PDF)* | Reconstructed FPGA interface: clk, rst, start, busy, done, dividend, divisor, quotient, remainder |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **ap1-26-97.pdf** | pp. 7–9 | `ocr_text/ap1-26-97.txt` | PDU functional overview — serial I/O, continuous pipelined operation, chip photograph reference |
| **p2-29-to-p2-46-.pdf** | Report p. 2-46 | `ocr_text/p2-29-to-p2-46-.txt` | Inflight diagnostic test operands — 5 (D,Z) sets detecting >98% single failures |
| **p3-1-to-B1-.pdf** | Report pp. 3-1 to 3-2 | `ocr_text/p3-1-to-B1-.txt` | Single failure analysis program — test word determination |
| **Rays-…-Chapter-7-System-Info.pdf** | p. 3 | `ocr_text/Rays-…-Chapter-7-System-Info.txt` | Pin assignments (944112, 24-pin) |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for PDU in Report 71-7266 |
