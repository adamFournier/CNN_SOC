library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- End-to-end VALID Conv3x3(4) + ReLU + MaxPool2x2 + Dense10.
-- 28x28x1 8-bit input -> 26x26x4 -> 13x13x4 -> 10 signed 32-bit scores.
-- Each stage is connected by ready/valid AXI4-Stream handshakes.
entity cnn_top is
  generic (
    WIDTH  : positive := 28;
    HEIGHT : positive := 28
  );
  port (
    axis_aclk    : in  std_logic;
    axis_aresetn : in  std_logic;
    s_axis_tdata  : in  std_logic_vector(7 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;
    m_axis_tdata  : out std_logic_vector(31 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );
end entity;

architecture rtl of cnn_top is
  signal conv_data, pool_data : std_logic_vector(31 downto 0);
  signal conv_valid, conv_ready, conv_last : std_logic;
  signal pool_valid, pool_ready, pool_last : std_logic;
begin
  assert WIDTH >= 4 and HEIGHT >= 4 and
         (WIDTH-2) mod 2 = 0 and (HEIGHT-2) mod 2 = 0
    report "CNN expects even dimensions >= 4 (VALID 3x3 conv, 2x2 pool)"
    severity failure;
  assert (WIDTH-2)/2 * ((HEIGHT-2)/2) * 4 <= 676
    report "Dense package capacity exceeded" severity failure;

  conv_i : entity work.cnn_conv
    generic map (WIDTH => WIDTH, HEIGHT => HEIGHT)
    port map (
      axis_aclk => axis_aclk, axis_aresetn => axis_aresetn,
      s_axis_tdata => s_axis_tdata, s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready, s_axis_tlast => s_axis_tlast,
      m_axis_tdata => conv_data, m_axis_tvalid => conv_valid,
      m_axis_tready => conv_ready, m_axis_tlast => conv_last
    );

  pool_i : entity work.maxpool2x2_axi
    generic map (INPUT_WIDTH => WIDTH-2, INPUT_HEIGHT => HEIGHT-2)
    port map (
      axis_aclk => axis_aclk, axis_aresetn => axis_aresetn,
      s_axis_tdata => conv_data, s_axis_tvalid => conv_valid,
      s_axis_tready => conv_ready, s_axis_tlast => conv_last,
      m_axis_tdata => pool_data, m_axis_tvalid => pool_valid,
      m_axis_tready => pool_ready, m_axis_tlast => pool_last
    );

  dense_i : entity work.dense_layer_axi
    generic map (FEATURE_WORDS => ((WIDTH-2)/2) * ((HEIGHT-2)/2))
    port map (
      axis_aclk => axis_aclk, axis_aresetn => axis_aresetn,
      s_axis_tdata => pool_data, s_axis_tvalid => pool_valid,
      s_axis_tready => pool_ready, s_axis_tlast => pool_last,
      m_axis_tdata => m_axis_tdata, m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready, m_axis_tlast => m_axis_tlast
    );
end architecture;
