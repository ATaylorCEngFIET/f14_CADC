# I/O Bridge Module

## Module Requirement Specification

### 1. Overview

| Attribute | Value |
|-----------|-------|
| Function | Adapt CADC core digital signals to/from external analog/digital interfaces |
| Type | Mixed: registered control + combinational data path |
| External Interfaces | ADC/DAC, sensor channels, display outputs, servo outputs |

### 2. Functional Description

The I/O Bridge adapts the CADC processor core's 20-bit digital data path to and from the external world of analog sensors, digital switches, cockpit displays, and flight control servos.

#### 2.1 Input Channels

| Channel | Source | Type | Description |
|---------|--------|------|-------------|
| CH_PS | Static pressure sensor | 20-bit ADC (Gray-coded) | Altitude computation |
| CH_QC | Dynamic pressure sensor | 20-bit ADC (Gray-coded) | Airspeed/Mach computation |
| CH_TAT | Temperature sensor | ADC | Total air temperature |
| CH_ANALOG | Pilot analog inputs | ADC | Various pilot controls |
| CH_DIGITAL | Pilot switches | Discrete | Switch position states |

#### 2.2 Output Channels

| Channel | Destination | Type | Description |
|---------|-------------|------|-------------|
| CH_MACH | Mach number display | 20-bit DAC | Cockpit Mach indicator |
| CH_ALT | Altitude display | 20-bit DAC | Cockpit altimeter |
| CH_AIRSPD | Airspeed display | 20-bit DAC | Cockpit airspeed indicator |
| CH_VSPD | Vertical speed display | 20-bit DAC | Cockpit vertical speed |
| CH_WING | Wing sweep | Servo DAC | Wing sweep position command |
| CH_FLAP | Maneuver flaps | Servo DAC | Flap position command |
| CH_GLOVE | Glove vane | Servo DAC | Glove vane position command |
| CH_BIT | BIT status | Discrete | Built-in test pass/fail |

#### 2.3 I/O Control (IOCTL) Field Encoding

The 4-bit IOCTL field from the microinstruction controls I/O operations:

| IOCTL | Operation | Description |
|-------|-----------|-------------|
| 0000 | NOP | No I/O operation |
| 0001 | READ_PS | Read static pressure sensor |
| 0010 | READ_QC | Read dynamic pressure sensor |
| 0011 | READ_TAT | Read temperature sensor |
| 0100 | READ_ANALOG | Read analog pilot input |
| 0101 | READ_DIGITAL | Read digital switch inputs |
| 0110 | WRITE_MACH | Write to Mach display |
| 0111 | WRITE_ALT | Write to altitude display |
| 1000 | WRITE_AIRSPD | Write to airspeed display |
| 1001 | WRITE_VSPD | Write to vertical speed display |
| 1010 | WRITE_WING | Write wing sweep command |
| 1011 | WRITE_FLAP | Write maneuver flap command |
| 1100 | WRITE_GLOVE | Write glove vane command |
| 1101 | WRITE_BIT | Write BIT status |
| 1110 | Reserved | |
| 1111 | Reserved | |

#### 2.4 Input Latching
- Sensor inputs are sampled and latched when the corresponding READ command is executed
- The latched 20-bit value appears on `io_data_out` for the SL to route to ACC/RAS
- Gray-coded sensor inputs are passed through as-is; the SLF performs Gray-to-Binary conversion

#### 2.5 Output Holding
- Output values are latched into holding registers when the corresponding WRITE command is executed
- Holding registers maintain the output until the next WRITE to the same channel
- DAC outputs are continuously driven from the holding registers

#### 2.6 Redundancy Interface
- The I/O Bridge includes redundancy switching logic
- A failure detection signal can trigger switchover to the backup channel
- Both channels receive identical microprogram commands but only one drives outputs

### 3. Interface Specification

#### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| **Core Interface** | | | |
| `clk` | Input | 1 | System clock |
| `rst` | Input | 1 | Synchronous reset |
| `io_ctrl` | Input | 4 | I/O control from microinstruction |
| `io_data_in` | Input | 20 | Data to write to output channel |
| `io_data_out` | Output | 20 | Data read from input channel |
| `io_ready` | Output | 1 | I/O operation complete |
| **Sensor Inputs** | | | |
| `sensor_ps` | Input | 20 | Static pressure (Gray-coded) |
| `sensor_qc` | Input | 20 | Dynamic pressure (Gray-coded) |
| `sensor_tat` | Input | 20 | Total air temperature |
| `sensor_analog` | Input | 20 | Analog pilot input |
| `sensor_digital` | Input | 20 | Digital switch inputs |
| **Display/Actuator Outputs** | | | |
| `out_mach` | Output | 20 | Mach number display |
| `out_alt` | Output | 20 | Altitude display |
| `out_airspd` | Output | 20 | Airspeed display |
| `out_vspd` | Output | 20 | Vertical speed display |
| `out_wing` | Output | 20 | Wing sweep command |
| `out_flap` | Output | 20 | Maneuver flap command |
| `out_glove` | Output | 20 | Glove vane command |
| `out_bit_status` | Output | 1 | BIT pass/fail |
| **Redundancy** | | | |
| `channel_active` | Input | 1 | This channel is active (drives outputs) |
| `fail_detect` | Output | 1 | Failure detected in this channel |

#### 3.2 VHDL Entity Declaration

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity io_bridge is
    port (
        -- Core interface
        clk            : in  std_logic;
        rst            : in  std_logic;
        io_ctrl        : in  std_logic_vector(3 downto 0);
        io_data_in     : in  std_logic_vector(19 downto 0);
        io_data_out    : out std_logic_vector(19 downto 0);
        io_ready       : out std_logic;
        -- Sensor inputs
        sensor_ps      : in  std_logic_vector(19 downto 0);
        sensor_qc      : in  std_logic_vector(19 downto 0);
        sensor_tat     : in  std_logic_vector(19 downto 0);
        sensor_analog  : in  std_logic_vector(19 downto 0);
        sensor_digital : in  std_logic_vector(19 downto 0);
        -- Display/actuator outputs
        out_mach       : out std_logic_vector(19 downto 0);
        out_alt        : out std_logic_vector(19 downto 0);
        out_airspd     : out std_logic_vector(19 downto 0);
        out_vspd       : out std_logic_vector(19 downto 0);
        out_wing       : out std_logic_vector(19 downto 0);
        out_flap       : out std_logic_vector(19 downto 0);
        out_glove      : out std_logic_vector(19 downto 0);
        out_bit_status : out std_logic;
        -- Redundancy
        channel_active : in  std_logic;
        fail_detect    : out std_logic
    );
end entity io_bridge;
```

### 4. Functional Requirements

| Req ID | Requirement | Priority |
|--------|-------------|----------|
| IO-F-001 | Shall read sensor data when commanded by IOCTL | Must |
| IO-F-002 | Shall write to display/actuator outputs when commanded by IOCTL | Must |
| IO-F-003 | Sensor read shall latch input data and present on `io_data_out` | Must |
| IO-F-004 | Output writes shall latch data into holding registers | Must |
| IO-F-005 | Output holding registers shall drive external signals continuously | Must |
| IO-F-006 | NOP IOCTL shall not change any I/O state | Must |
| IO-F-007 | Reset shall clear all output holding registers to zero | Must |
| IO-F-008 | Gray-coded sensor inputs shall be passed as-is (conversion in SLF) | Must |
| IO-F-009 | Output shall only drive when `channel_active` = 1 | Must |
| IO-F-010 | `fail_detect` shall assert on detected self-test failure | Should |
| IO-F-011 | I/O operation shall complete in a single clock cycle | Should |
| IO-F-012 | `io_ready` shall assert when read data is valid or write is latched | Must |

### 5. Verification Tests

#### 5.1 Sensor Input Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-001 | Read static pressure | `io_data_out` = `sensor_ps` after READ_PS |
| IO-T-002 | Read dynamic pressure | `io_data_out` = `sensor_qc` after READ_QC |
| IO-T-003 | Read temperature | `io_data_out` = `sensor_tat` after READ_TAT |
| IO-T-004 | Read analog input | `io_data_out` = `sensor_analog` after READ_ANALOG |
| IO-T-005 | Read digital switches | `io_data_out` = `sensor_digital` after READ_DIGITAL |
| IO-T-006 | sensor changes between reads | Latched value reflects time of read |

#### 5.2 Display/Actuator Output Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-010 | Write Mach display | `out_mach` = written value, held until next write |
| IO-T-011 | Write altitude display | `out_alt` = written value |
| IO-T-012 | Write airspeed display | `out_airspd` = written value |
| IO-T-013 | Write vertical speed | `out_vspd` = written value |
| IO-T-014 | Write wing sweep | `out_wing` = written value |
| IO-T-015 | Write maneuver flaps | `out_flap` = written value |
| IO-T-016 | Write glove vane | `out_glove` = written value |
| IO-T-017 | Write BIT status | `out_bit_status` = driven value |

#### 5.3 Hold / NOP Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-020 | NOP doesn't change outputs | All outputs unchanged after NOP |
| IO-T-021 | Output holds after write | Value persists through multiple cycles |
| IO-T-022 | Output persists through reads | Writing to one channel doesn't affect others |

#### 5.4 Channel Independence Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-030 | Write to each output independently | Only targeted output changes |
| IO-T-031 | Read from each input independently | Only targeted input appears on `io_data_out` |

#### 5.5 Redundancy Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-040 | Active channel drives outputs | Outputs driven when `channel_active`=1 |
| IO-T-041 | Inactive channel tristates/zeroes outputs | Outputs not driven when `channel_active`=0 |
| IO-T-042 | Failure detection | `fail_detect` asserts on self-test mismatch |

#### 5.6 Reset Tests

| Test ID | Description | Criteria |
|---------|-------------|----------|
| IO-T-050 | Reset clears all outputs | All output registers = 0 after reset |
| IO-T-051 | Reset clears BIT status | `out_bit_status` = 0 after reset |

#### 5.7 Testbench Structure

```vhdl
entity io_bridge_tb is
end entity io_bridge_tb;

architecture sim of io_bridge_tb is
    signal clk, rst : std_logic := '0';
    signal io_ctrl : std_logic_vector(3 downto 0);
    signal io_data_in, io_data_out : std_logic_vector(19 downto 0);
    signal io_ready : std_logic;
    signal sensor_ps, sensor_qc, sensor_tat : std_logic_vector(19 downto 0);
    signal sensor_analog, sensor_digital : std_logic_vector(19 downto 0);
    signal out_mach, out_alt, out_airspd, out_vspd : std_logic_vector(19 downto 0);
    signal out_wing, out_flap, out_glove : std_logic_vector(19 downto 0);
    signal out_bit_status, channel_active, fail_detect : std_logic;
    
    constant CLK_PERIOD : time := 20 ns;
begin
    clk <= not clk after CLK_PERIOD / 2;
    
    uut: entity work.io_bridge
        port map (
            clk, rst, io_ctrl, io_data_in, io_data_out, io_ready,
            sensor_ps, sensor_qc, sensor_tat, sensor_analog, sensor_digital,
            out_mach, out_alt, out_airspd, out_vspd,
            out_wing, out_flap, out_glove, out_bit_status,
            channel_active, fail_detect
        );
    
    stim: process
    begin
        rst <= '1';
        channel_active <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        
        -- Set up sensor values
        sensor_ps <= x"12345";
        sensor_qc <= x"67890";
        sensor_tat <= x"ABCDE";
        wait for CLK_PERIOD;
        
        -- Read static pressure
        io_ctrl <= "0001";  -- READ_PS
        wait until rising_edge(clk);
        io_ctrl <= "0000";  -- NOP
        wait for 1 ns;
        assert io_data_out = x"12345"
            report "READ_PS failed" severity error;
        
        -- Write to Mach display
        io_data_in <= x"54321";
        io_ctrl <= "0110";  -- WRITE_MACH
        wait until rising_edge(clk);
        io_ctrl <= "0000";
        wait for 1 ns;
        assert out_mach = x"54321"
            report "WRITE_MACH failed" severity error;
        
        -- Verify output holds
        wait for 10 * CLK_PERIOD;
        assert out_mach = x"54321"
            report "MACH output not held" severity error;
        
        report "I/O Bridge tests complete" severity note;
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
| **p1-35-to-p2-28-.pdf** | Report pp. 2-9 to 2-20 | `ocr_text/p1-35-to-p2-28-.txt` | Executive control I/O bits — D/A output updates (wing sweep, displays), A/D mux stepping, ADC data shift-out format (12-bit within 20-bit word), sensor memory control (Ps, Pt counters), digital outputs, IFF update, switch updates, BITE control |
| **p1-35-to-p2-28-.pdf** | Report pp. 2-23 to 2-28 | `ocr_text/p1-35-to-p2-28-.txt` | Programming examples showing I/O usage — AoA correction (Psi, Pti sensor inputs), EPR function (Pt2, ambient temp), I/O data paths through steering to arithmetic units |
| **p2-29-to-p2-46-.pdf** | Report pp. 2-29 to 2-43 | `ocr_text/p2-29-to-p2-46-.txt` | I/O programming examples — EPR zones, glove vane schedule f1(M), glove vane limit LIM(Δ), wing sweep rate limit, maneuver flap deadband/rate limit, switch thresholds (Mach switches S1–S5) |
| **CADC_Module_Specification.pdf** | Section 7 | *(text-layer PDF)* | Reconstructed FPGA interface: clk, rst, io_in, io_out, io_ctrl, sensor lines, actuator outputs |

### 8.2 Supporting Sources

| Source Document | Pages / Sections | OCR Text File | Information Extracted |
|----------------|-----------------|---------------|----------------------|
| **p2-29-to-p2-46-.pdf** | Report p. 2-46 | `ocr_text/p2-29-to-p2-46-.txt` | Inflight diagnostics / BITE — diagnostic results feeding BITE circuitry, comparator verification |
| **ap1-26-97.pdf** | pp. 1–2 | `ocr_text/ap1-26-97.txt` | System I/O overview — pressure/temperature sensors, pilot displays (altimeter, Mach, temp), aircraft control systems, digital/analog signal forms |
| **lsistate-97.pdf** | pp. 1–2, 6 | *(text-layer PDF)* | Design constraints affecting I/O — size (40 sq in), 10W power, real-time computing, sensor/actuator requirements |
| **F-14-CADC-Design-Sequence-v1.00.pdf** | p. 1 | *(text-layer PDF)* | System block diagram — digital inputs (A/D), module I/O paths, output control paths |
| **toc-illustrations.pdf** | pp. 1–4 | *(text-layer PDF)* | Figure/page cross-references for I/O sections in Report 71-7266 |
