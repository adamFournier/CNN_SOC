----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.10.2026 14:45:37
-- Design Name: 
-- Module Name: conv_kernel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity conv_kernel is
    port (
        -- Les 9 pixels de la fenêtre
        p00, p01, p02 : in std_logic_vector(7 downto 0);
        p10, p11, p12 : in std_logic_vector(7 downto 0);
        p20, p21, p22 : in std_logic_vector(7 downto 0);

        -- Les 9 poids du filtre
        w00, w01, w02 : in signed(7 downto 0);
        w10, w11, w12 : in signed(7 downto 0);
        w20, w21, w22 : in signed(7 downto 0);

        -- bias 
        bias : in signed(31 downto 0);


        result : out signed(31 downto 0)
    );
end conv_kernel;

architecture Behavioral of conv_kernel is

signal sum_products : signed(20 downto 0);

begin

sum_products <= resize(signed('0' & p00)*w00,21) + resize(signed('0' & p01)*w01,21) +  resize(signed('0' & p02)*w02,21) +
                resize(signed('0' & p10)*w10,21) + resize(signed('0' & p11)*w11,21) +  resize(signed('0' & p12)*w12,21) +
                resize(signed('0' & p20)*w20,21) + resize(signed('0' & p21)*w21,21) +  resize(signed('0' & p22)*w22,21)
                ;

 result <= resize(sum_products, 32) + bias;
    
end Behavioral;
