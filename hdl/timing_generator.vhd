-------------------------------------------------------------------------------
-- Timing Generator
-- F-14A Central Air Data Computer - FPGA Implementation (Bit-Serial)
--
-- Generates the CADC timing hierarchy from the master clock:
--   1.5 MHz master -> 375 kHz phase clocks (phi1, phi2 non-overlapping)
--   4 master clocks per bit time (2.666 µs)
--   20 bit times per word, alternating WA/WO, 512 OPs per frame
--
-- Bit-serial timing:
--   WA (Word A): Control word shifts in, arithmetic computes
--   WO (Word O): Data shifts between modules
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timing_generator IS
  PORT (
    i_clk_master : IN  STD_LOGIC;
    i_rst        : IN  STD_LOGIC;
    -- Phase clocks (375 kHz, non-overlapping)
    o_phi1       : OUT STD_LOGIC;
    o_phi2       : OUT STD_LOGIC;
    -- Bit-serial timing
    o_bit_clk    : OUT STD_LOGIC;  -- Pulse at start of each bit time
    o_bit_count  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- T0-T19
    o_t0         : OUT STD_LOGIC;  -- First bit of word
    o_t18        : OUT STD_LOGIC;  -- Word mark bit time
    o_t19        : OUT STD_LOGIC;  -- Last bit of word
    -- Word timing
    o_word_type  : OUT STD_LOGIC;  -- '0'=WA, '1'=WO
    o_word_mark  : OUT STD_LOGIC;  -- Pulse at T18
    -- Operation and frame timing
    o_op_count   : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);  -- 0-511
    o_frame_mark : OUT STD_LOGIC   -- Pulse at end of frame
  );
END ENTITY timing_generator;

ARCHITECTURE rtl OF timing_generator IS

  -- Phase clock divider (4 master clocks per bit time for 1.5 MHz -> 375 kHz)
  SIGNAL s_phase_cnt : UNSIGNED(1 DOWNTO 0) := "00";
  
  -- Bit time counter (T0-T19)
  SIGNAL s_bit_cnt   : UNSIGNED(4 DOWNTO 0) := (OTHERS => '0');
  
  -- Word type (WA=0, WO=1)
  SIGNAL s_word_sel  : STD_LOGIC := '0';
  
  -- Operation counter (0-511)
  SIGNAL s_op_cnt    : UNSIGNED(9 DOWNTO 0) := (OTHERS => '0');
  
  -- Phase clock registers
  SIGNAL s_phi1_reg  : STD_LOGIC := '0';
  SIGNAL s_phi2_reg  : STD_LOGIC := '0';
  
  -- Bit clock (pulse at start of bit time)
  SIGNAL s_bit_clk   : STD_LOGIC := '0';
  
  -- Registered timing markers (stable when phi2='1')
  SIGNAL s_t0_reg    : STD_LOGIC := '1';  -- Registered T0
  SIGNAL s_t18_reg   : STD_LOGIC := '0';  -- Registered T18
  SIGNAL s_t19_reg   : STD_LOGIC := '0';  -- Registered T19
  SIGNAL s_word_type_reg : STD_LOGIC := '0';  -- Registered word type

BEGIN

  -----------------------------------------------------------------------------
  -- Main timing process
  -- Generates phi1/phi2 at 375 kHz from 1.5 MHz master
  -- Phase sequence per bit time: 00=setup, 01=phi1, 10=hold, 11=phi2
  -----------------------------------------------------------------------------
  timing_proc: PROCESS(i_clk_master)
  BEGIN
    IF RISING_EDGE(i_clk_master) THEN
      IF i_rst = '1' THEN
        s_phase_cnt <= "00";
        s_bit_cnt   <= (OTHERS => '0');
        s_word_sel  <= '0';
        s_op_cnt    <= (OTHERS => '0');
        s_phi1_reg  <= '0';
        s_phi2_reg  <= '0';
        s_bit_clk   <= '0';
        s_t0_reg    <= '1';  -- T0 after reset
        s_t18_reg   <= '0';
        s_t19_reg   <= '0';
        s_word_type_reg <= '0';
      ELSE
        -- Default bit_clk low
        s_bit_clk <= '0';
        
        -- Phase counter (4 phases per bit time)
        CASE s_phase_cnt IS
          WHEN "00" =>
            -- Setup phase - bit_clk pulse
            s_phi1_reg <= '0';
            s_phi2_reg <= '0';
            s_bit_clk  <= '1';
            s_phase_cnt <= "01";
            
          WHEN "01" =>
            -- Phi1 active
            s_phi1_reg <= '1';
            s_phi2_reg <= '0';
            s_phase_cnt <= "10";
            
          WHEN "10" =>
            -- Hold phase - register timing signals before phi2
            s_phi1_reg <= '0';
            s_phi2_reg <= '0';
            s_phase_cnt <= "11";
            -- Register timing markers so they're stable when phi2='1'
            s_t0_reg  <= '1' WHEN s_bit_cnt = 0 ELSE '0';
            s_t18_reg <= '1' WHEN s_bit_cnt = 18 ELSE '0';
            s_t19_reg <= '1' WHEN s_bit_cnt = 19 ELSE '0';
            s_word_type_reg <= s_word_sel;
            
          WHEN "11" =>
            -- Phi2 active - advance bit counter at end
            s_phi1_reg <= '0';
            s_phi2_reg <= '1';
            s_phase_cnt <= "00";
            
            -- Advance bit/word/op counters
            IF s_bit_cnt = 19 THEN
              s_bit_cnt <= (OTHERS => '0');
              IF s_word_sel = '1' THEN
                -- End of WO, advance operation
                s_word_sel <= '0';
                IF s_op_cnt = 511 THEN
                  s_op_cnt <= (OTHERS => '0');
                ELSE
                  s_op_cnt <= s_op_cnt + 1;
                END IF;
              ELSE
                -- End of WA, switch to WO
                s_word_sel <= '1';
              END IF;
            ELSE
              s_bit_cnt <= s_bit_cnt + 1;
            END IF;
            
          WHEN OTHERS =>
            s_phase_cnt <= "00";
        END CASE;
      END IF;
    END IF;
  END PROCESS timing_proc;

  -----------------------------------------------------------------------------
  -- Output assignments
  -- t0/t18/t19/word_type use registered versions for phi2 alignment
  -----------------------------------------------------------------------------
  o_phi1       <= s_phi1_reg;
  o_phi2       <= s_phi2_reg;
  o_bit_clk    <= s_bit_clk;
  o_bit_count  <= STD_LOGIC_VECTOR(s_bit_cnt);
  o_t0         <= s_t0_reg;   -- Registered for phi2 alignment
  o_t18        <= s_t18_reg;  -- Registered for phi2 alignment
  o_t19        <= s_t19_reg;  -- Registered for phi2 alignment
  o_word_type  <= s_word_type_reg;  -- Registered for phi2 alignment
  o_word_mark  <= '1' WHEN (s_bit_cnt = 18 AND s_phase_cnt = "00") ELSE '0';
  o_op_count   <= STD_LOGIC_VECTOR(s_op_cnt);
  o_frame_mark <= '1' WHEN (s_bit_cnt = 19 AND s_word_sel = '1' AND 
                            s_op_cnt = 511 AND s_phase_cnt = "11") ELSE '0';

END ARCHITECTURE rtl;
