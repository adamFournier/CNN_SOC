library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_cnn_top is end entity;
architecture test of tb_cnn_top is
  signal clk : std_logic := '0';
  signal rstn : std_logic := '0';
  signal s_data : std_logic_vector(7 downto 0) := (others => '0');
  signal s_valid, s_last : std_logic := '0';
  signal s_ready : std_logic;
  signal m_data : std_logic_vector(31 downto 0);
  signal m_valid, m_last : std_logic;
  signal m_ready : std_logic := '0';
begin
  clk <= not clk after 5 ns;
  dut : entity work.cnn_top
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
      for pixel in 0 to 783 loop
        wait until falling_edge(clk);
        s_data <= std_logic_vector(to_unsigned((pixel + frame*13) mod 256, 8));
        s_last <= '1' when pixel = 783 else '0';
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
  begin
    wait until rstn = '1';
    while beats < 20 loop
      wait until rising_edge(clk);
      if m_valid = '1' and m_ready = '1' then
        assert not is_x(m_data)
          report "CNN output contains undefined bits" severity failure;
        assert (m_last = '1') = (beats mod 10 = 9)
          report "CNN output TLAST mismatch" severity failure;
        beats := beats + 1;
      end if;
      tick := tick + 1;
      if tick mod 7 = 0 then m_ready <= '0';
      else m_ready <= '1'; end if;
    end loop;
    report "PASS: CNN top - two 28x28 frames, 10 scores each, backpressure";
    finish;
  end process;
  watchdog : process
  begin
    wait for 100 us;
    assert false report "TIMEOUT: CNN top integration test" severity failure;
  end process;
end architecture;
