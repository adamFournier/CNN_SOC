library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_maxpool2x2 is end entity;
architecture test of tb_maxpool2x2 is
  signal clk : std_logic := '0';
  signal rstn : std_logic := '0';
  signal s_data : std_logic_vector(31 downto 0) := (others => '0');
  signal s_valid : std_logic := '0';
  signal s_ready, s_last : std_logic;
  signal m_data : std_logic_vector(31 downto 0);
  signal m_valid, m_ready : std_logic := '0';
  signal m_last : std_logic;
  type int4_t is array (0 to 3) of integer;
  constant peak : int4_t := (5, 7, 13, 15);

  function pack_word(base : natural) return std_logic_vector is
    variable w : std_logic_vector(31 downto 0);
  begin
    for c in 0 to 3 loop
      w(c*8+7 downto c*8) := std_logic_vector(to_unsigned(base + c*20, 8));
    end loop;
    return w;
  end function;
begin
  clk <= not clk after 5 ns;
  dut : entity work.maxpool2x2_axi
    generic map (INPUT_WIDTH => 4, INPUT_HEIGHT => 4)
    port map (
      axis_aclk => clk, axis_aresetn => rstn,
      s_axis_tdata => s_data, s_axis_tvalid => s_valid,
      s_axis_tready => s_ready, s_axis_tlast => s_last,
      m_axis_tdata => m_data, m_axis_tvalid => m_valid,
      m_axis_tready => m_ready, m_axis_tlast => m_last);

  producer : process
  begin
    wait for 25 ns;
    wait until falling_edge(clk);
    rstn <= '1';
    for frame in 0 to 1 loop
      for pixel in 0 to 15 loop
        wait until falling_edge(clk);
        s_data <= pack_word(pixel + frame*16);
        s_last <= '1' when pixel = 15 else '0';
        s_valid <= '1';
        loop
          wait until rising_edge(clk);
          exit when s_ready = '1';
        end loop;
      end loop;
    end loop;
    wait until falling_edge(clk);
    s_valid <= '0';
    s_last <= '0';
    wait;
  end process;

  consumer : process
    variable beats : natural := 0;
    variable tick : natural := 0;
    variable expected : integer;
  begin
    wait until rstn = '1';
    while beats < 8 loop
      wait until rising_edge(clk);
      if m_valid = '1' and m_ready = '1' then
        for c in 0 to 3 loop
          expected := peak(beats mod 4) + (beats / 4)*16 + c*20;
          assert to_integer(unsigned(m_data(c*8+7 downto c*8))) = expected
            report "MaxPool incorrect max value" severity failure;
        end loop;
        assert (m_last = '1') = (beats mod 4 = 3)
          report "MaxPool TLAST error" severity failure;
        beats := beats + 1;
      end if;
      tick := tick + 1;
      if tick mod 5 = 0 then
        m_ready <= '0';
      else
        m_ready <= '1';
      end if;
    end loop;
    report "PASS: maxpool2x2 - 2 frames, 4 channels, backpressure";
    finish;
  end process;
  watchdog : process
  begin
    wait for 30 us;
    assert false report "TIMEOUT: MaxPool test" severity failure;
  end process;
end architecture;
