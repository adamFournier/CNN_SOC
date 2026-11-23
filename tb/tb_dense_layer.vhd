library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_dense_layer is end entity;
architecture test of tb_dense_layer is
  signal clk : std_logic := '0';
  signal rstn : std_logic := '0';
  signal s_data : std_logic_vector(31 downto 0) := (others => '0');
  signal s_valid, s_last : std_logic := '0';
  signal s_ready : std_logic;
  signal m_data : std_logic_vector(31 downto 0);
  signal m_valid, m_last : std_logic;
  signal m_ready : std_logic := '0';
  type int10_t is array (0 to 9) of integer;
  constant frame0 : int10_t := (1, 2, 3, 4, 10, -10, 5, 6, 7, 8);
  constant frame1 : int10_t := (9, 8, 7, 6, 30, -30, 5, 4, 3, 2);
  function pack_four(a,b,c,d : natural) return std_logic_vector is
    variable w : std_logic_vector(31 downto 0);
  begin
    w(7 downto 0) := std_logic_vector(to_unsigned(a,8));
    w(15 downto 8) := std_logic_vector(to_unsigned(b,8));
    w(23 downto 16) := std_logic_vector(to_unsigned(c,8));
    w(31 downto 24) := std_logic_vector(to_unsigned(d,8));
    return w;
  end function;
begin
  clk <= not clk after 5 ns;
  dut : entity work.dense_layer_axi
    generic map (FEATURE_WORDS => 2)
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
      for sample in 0 to 1 loop
        wait until falling_edge(clk);
        if frame = 0 then
          if sample = 0 then
            s_data <= pack_four(1,2,3,4);
          else
            s_data <= pack_four(5,6,7,8);
          end if;
        else
          if sample = 0 then
            s_data <= pack_four(9,8,7,6);
          else
            s_data <= pack_four(5,4,3,2);
          end if;
        end if;
        s_last <= '1' when sample = 1 else '0';
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
    while beats < 20 loop
      wait until rising_edge(clk);
      if m_valid = '1' and m_ready = '1' then
        if beats < 10 then
          expected := frame0(beats);
        else
          expected := frame1(beats-10);
        end if;
        assert to_integer(signed(m_data)) = expected
          report "Dense MAC mismatch at score " & integer'image(beats)
          severity failure;
        assert (m_last = '1') = (beats mod 10 = 9)
          report "Dense TLAST mismatch" severity failure;
        beats := beats + 1;
      end if;
      tick := tick + 1;
      if tick mod 4 = 0 then m_ready <= '0';
      else m_ready <= '1'; end if;
    end loop;
    report "PASS: Dense - 2 frames, signed MACs, class scores, backpressure";
    finish;
  end process;
  watchdog : process
  begin
    wait for 40 us;
    assert false report "TIMEOUT: Dense test" severity failure;
  end process;
end architecture;
