library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 2x2 max pooling, stride 2, for four packed 8-bit feature channels.
-- Each accepted AXI beat contains one spatial location: [ch3|ch2|ch1|ch0].
-- Input dimensions must be positive and even. No padding is applied.
entity maxpool2x2_axi is
  generic (
    INPUT_WIDTH  : positive := 26;
    INPUT_HEIGHT : positive := 26
  );
  port (
    axis_aclk    : in  std_logic;
    axis_aresetn : in  std_logic;
    s_axis_tdata  : in  std_logic_vector(31 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;
    m_axis_tdata  : out std_logic_vector(31 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );
end entity;

architecture rtl of maxpool2x2_axi is
  constant OUTPUT_WIDTH : positive := INPUT_WIDTH / 2;
  type line_t is array (0 to OUTPUT_WIDTH-1) of std_logic_vector(31 downto 0);
  signal top_row_max : line_t; -- Updated on even-numbered rows; no reset required.
  signal horizontal_left : std_logic_vector(31 downto 0) := (others => '0');
  signal col_index : natural range 0 to INPUT_WIDTH-1 := 0;
  signal row_index : natural range 0 to INPUT_HEIGHT-1 := 0;
  signal out_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal out_valid : std_logic := '0';
  signal out_last  : std_logic := '0';
  signal can_accept : std_logic;

  function lane_max(a, b : std_logic_vector(31 downto 0))
    return std_logic_vector is
    variable result_word : std_logic_vector(31 downto 0);
  begin
    for lane in 0 to 3 loop
      if unsigned(a(lane*8+7 downto lane*8)) >=
         unsigned(b(lane*8+7 downto lane*8)) then
        result_word(lane*8+7 downto lane*8) :=
          a(lane*8+7 downto lane*8);
      else
        result_word(lane*8+7 downto lane*8) :=
          b(lane*8+7 downto lane*8);
      end if;
    end loop;
    return result_word;
  end function;
begin
  assert INPUT_WIDTH mod 2 = 0 and INPUT_HEIGHT mod 2 = 0
    report "MaxPool expects even input dimensions" severity failure;

  can_accept <= '1' when axis_aresetn = '1' and
      (out_valid = '0' or m_axis_tready = '1') else '0';
  s_axis_tready <= can_accept;
  m_axis_tdata  <= out_data;
  m_axis_tvalid <= out_valid;
  m_axis_tlast  <= out_last;

  process(axis_aclk)
    variable horizontal_max : std_logic_vector(31 downto 0);
  begin
    if rising_edge(axis_aclk) then
      if axis_aresetn = '0' then
        col_index <= 0;
        row_index <= 0;
        horizontal_left <= (others => '0');
        out_data <= (others => '0');
        out_valid <= '0';
        out_last <= '0';
      else
        if out_valid = '1' and m_axis_tready = '1' then
          out_valid <= '0';
          out_last <= '0';
        end if;

        if s_axis_tvalid = '1' and can_accept = '1' then
          if col_index mod 2 = 0 then
            horizontal_left <= s_axis_tdata;
          else
            horizontal_max := lane_max(horizontal_left, s_axis_tdata);
            if row_index mod 2 = 0 then
              top_row_max(col_index / 2) <= horizontal_max;
            else
              out_data <= lane_max(top_row_max(col_index / 2), horizontal_max);
              out_valid <= '1';
              if row_index = INPUT_HEIGHT-1 and col_index = INPUT_WIDTH-1 then
                out_last <= '1';
              else
                out_last <= '0';
              end if;
            end if;
          end if;

          -- The frame size, not TLAST, determines the output coordinates.
          -- The input TLAST is checked by the testbench.
          if col_index = INPUT_WIDTH-1 then
            col_index <= 0;
            if row_index = INPUT_HEIGHT-1 then
              row_index <= 0;
            else
              row_index <= row_index + 1;
            end if;
          else
            col_index <= col_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
