
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.cnn_weights_pkg.all;

entity cnn_conv is
  generic (
    WIDTH  : integer := 28;
    HEIGHT : integer := 28
  );
  port (
    axis_aclk    : in std_logic;
    axis_aresetn : in std_logic;

    s_axis_tdata  : in  std_logic_vector(7 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;

    m_axis_tdata  : out std_logic_vector(31 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );
end cnn_conv;

architecture Behavioral of cnn_conv is

constant k_merged_scale : integer :=8;

  -- Position du pixel qui est en train d'entrer
  signal col_cnt : integer range 0 to WIDTH-1  ;
  signal row_cnt : integer range 0 to HEIGHT-1 ;

  -- Line buffers (pas de reset : ça permet d'utiliser de la RAM)
  type line_buffer is array (0 to WIDTH-1) of std_logic_vector(7 downto 0);
  signal line_buffer_1 : line_buffer;   -- ligne n-2
  signal line_buffer_2 : line_buffer;   -- ligne n-1

  -- Fenêtre 3x3
  signal p00, p01, p02 : std_logic_vector(7 downto 0) ;
  signal p10, p11, p12 : std_logic_vector(7 downto 0) ;
  signal p20, p21, p22 : std_logic_vector(7 downto 0) ;

  -- Handshake
  signal s_axis_tready_reg : std_logic;
  signal m_axis_tvalid_reg : std_logic ;
  signal m_axis_tlast_reg  : std_logic ;
  signal in_handshake      : std_logic;   -- un pixel est accepté ce cycle

  -- Calcul de la convolution
  signal output_reg  : signed(20 downto 0);
  signal clip_output : std_logic_vector(7 downto 0);
  
  -- signaux combinatoire
  type conv_results_t is array (0 to 3) of signed(31 downto 0);
  signal conv_result : conv_results_t; -- resulta conv
  signal scaled_result : conv_results_t; -- *merged scale
  
  type activations_t is array (0 to 3) of signed(7 downto 0);
signal activation : activations_t; -- clipping + relu


 signal pixel_q : std_logic_vector(7 downto 0); -- pixels normalisé et quantifié 
 
 
begin


  ------------------------------------------------------------------------------
  -- Handshake AXI-Stream
  ------------------------------------------------------------------------------
  -- Prêt à recevoir si la sortie est vide, ou si elle est prise ce cycle
  s_axis_tready_reg <= '1'
    when (m_axis_tvalid_reg = '0' or m_axis_tready = '1')
    and axis_aresetn = '1'
    else '0';
  s_axis_tready     <= s_axis_tready_reg;

  in_handshake <= s_axis_tvalid and s_axis_tready_reg;

  m_axis_tvalid <= m_axis_tvalid_reg;
  m_axis_tlast  <= m_axis_tlast_reg;

  ------------------------------------------------------------------------------
  -- Convolution (combinatoire sur les 4 fenetres)
  ------------------------------------------------------------------------------
-- KERNEL 0
kernel_0 : entity work.conv_kernel
    port map (
        p00 => p00, p01 => p01, p02 => p02,
        p10 => p10, p11 => p11, p12 => p12,
        p20 => p20, p21 => p21, p22 => p22,

        w00 => CONV_WEIGHTS(0)(0),
        w01 => CONV_WEIGHTS(0)(1),
        w02 => CONV_WEIGHTS(0)(2),
        w10 => CONV_WEIGHTS(0)(3),
        w11 => CONV_WEIGHTS(0)(4),
        w12 => CONV_WEIGHTS(0)(5),
        w20 => CONV_WEIGHTS(0)(6),
        w21 => CONV_WEIGHTS(0)(7),
        w22 => CONV_WEIGHTS(0)(8),

        bias   => CONV_BIASES(0),
        result => conv_result(0)
    );


-- KERNEL 1
kernel_1 : entity work.conv_kernel
    port map (
        p00 => p00, p01 => p01, p02 => p02,
        p10 => p10, p11 => p11, p12 => p12,
        p20 => p20, p21 => p21, p22 => p22,

        w00 => CONV_WEIGHTS(1)(0),
        w01 => CONV_WEIGHTS(1)(1),
        w02 => CONV_WEIGHTS(1)(2),
        w10 => CONV_WEIGHTS(1)(3),
        w11 => CONV_WEIGHTS(1)(4),
        w12 => CONV_WEIGHTS(1)(5),
        w20 => CONV_WEIGHTS(1)(6),
        w21 => CONV_WEIGHTS(1)(7),
        w22 => CONV_WEIGHTS(1)(8),

        bias   => CONV_BIASES(1),
        result => conv_result(1)
    );


-- KERNEL 2
kernel_2 : entity work.conv_kernel
    port map (
        p00 => p00, p01 => p01, p02 => p02,
        p10 => p10, p11 => p11, p12 => p12,
        p20 => p20, p21 => p21, p22 => p22,

        w00 => CONV_WEIGHTS(2)(0),
        w01 => CONV_WEIGHTS(2)(1),
        w02 => CONV_WEIGHTS(2)(2),
        w10 => CONV_WEIGHTS(2)(3),
        w11 => CONV_WEIGHTS(2)(4),
        w12 => CONV_WEIGHTS(2)(5),
        w20 => CONV_WEIGHTS(2)(6),
        w21 => CONV_WEIGHTS(2)(7),
        w22 => CONV_WEIGHTS(2)(8),

        bias   => CONV_BIASES(2),
        result => conv_result(2)
    );


-- KERNEL 3
kernel_3 : entity work.conv_kernel
    port map (
        p00 => p00, p01 => p01, p02 => p02,
        p10 => p10, p11 => p11, p12 => p12,
        p20 => p20, p21 => p21, p22 => p22,

        w00 => CONV_WEIGHTS(3)(0),
        w01 => CONV_WEIGHTS(3)(1),
        w02 => CONV_WEIGHTS(3)(2),
        w10 => CONV_WEIGHTS(3)(3),
        w11 => CONV_WEIGHTS(3)(4),
        w12 => CONV_WEIGHTS(3)(5),
        w20 => CONV_WEIGHTS(3)(6),
        w21 => CONV_WEIGHTS(3)(7),
        w22 => CONV_WEIGHTS(3)(8),

        bias   => CONV_BIASES(3),
        result => conv_result(3)
    );
    
------------------------------------------------------------------------------
-- normalisation par 255 2**8 puis quantification avec scale0 = 2**-6 donc x/2**8/2**-6 = x/2**2
------------------------------------------------------------------------------
  
  pixel_q <= std_logic_vector(shift_right(unsigned(s_axis_tdata), 2));
    
------------------------------------------------------------------------------
-- merged scale
------------------------------------------------------------------------------
  
gen_shift : for i in 0 to 3 generate
begin
    scaled_result(i) <= shift_right(conv_result(i), k_merged_scale);
end generate;
------------------------------------------------------------------------------
-- clipping + relu
------------------------------------------------------------------------------
  

gen_activation : for i in 0 to 3 generate
begin

    activation(i) <=
        to_signed(0, 8) when scaled_result(i) < 0 else
        to_signed(127, 8) when scaled_result(i) > 127 else
        resize(scaled_result(i), 8);

end generate;

-- resultatas des 4 noyaux
m_axis_tdata <= std_logic_vector(activation(3)) &
                std_logic_vector(activation(2)) &
                std_logic_vector(activation(1)) &
                std_logic_vector(activation(0));
  ------------------------------------------------------------------------------
  -- Line buffers (sans reset)
  ------------------------------------------------------------------------------
  
  process (axis_aclk)
  begin
    if rising_edge(axis_aclk) then
      if in_handshake = '1' then
        line_buffer_1(col_cnt) <= line_buffer_2(col_cnt);
        line_buffer_2(col_cnt) <= pixel_q;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Compteurs, fenêtre, tvalid, tlast
  ------------------------------------------------------------------------------
  process (axis_aclk)
  begin
    if rising_edge(axis_aclk) then
      if axis_aresetn = '0' then
        row_cnt <= 0;
        col_cnt <= 0;
        p00 <= (others => '0');  p01 <= (others => '0');  p02 <= (others => '0');
        p10 <= (others => '0');  p11 <= (others => '0');  p12 <= (others => '0');
        p20 <= (others => '0');  p21 <= (others => '0');  p22 <= (others => '0');
        m_axis_tvalid_reg <= '0';
        m_axis_tlast_reg  <= '0';
      else

        -- Le DMA a pris la donnée : la sortie redevient vide
        if m_axis_tvalid_reg = '1' and m_axis_tready = '1' then
          m_axis_tvalid_reg <= '0';
          m_axis_tlast_reg  <= '0';
        end if;

        if in_handshake = '1' then

          -- Glissement de la fenêtre
          p00 <= p01;  p01 <= p02;  p02 <= line_buffer_1(col_cnt);
          p10 <= p11;  p11 <= p12;  p12 <= line_buffer_2(col_cnt);
          p20 <= p21;  p21 <= p22;  p22 <= pixel_q;

          -- La fenêtre est complète à partir de la ligne 2 / colonne 2
          if col_cnt >= 2 and row_cnt >= 2 then
            m_axis_tvalid_reg <= '1';
            -- Dernier pixel de l'image
            if col_cnt = WIDTH-1 and row_cnt = HEIGHT-1 then
              m_axis_tlast_reg <= '1';
            end if;
          end if;

          -- Compteurs
          if col_cnt = WIDTH-1 then
            col_cnt <= 0;
            if row_cnt = HEIGHT-1 then
              row_cnt <= 0;
            else
              row_cnt <= row_cnt + 1;
            end if;
          else
            col_cnt <= col_cnt + 1;
          end if;

        end if;
      end if;
    end if;
  end process;

end Behavioral;