
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package cnn_weights_pkg is

    -- Un filtre 3x3 = 9 poids signes sur 8 bits
    type kernel_t is array (0 to 8) of signed(7 downto 0);

    -- 4 filtres de convolution
    type filters_t is array (0 to 3) of kernel_t;

    constant CONV_WEIGHTS : filters_t := (

        -- FILTRE 0
        0 => (
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8)
        ),

        -- FILTRE 1
        1 => (
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8)
        ),

        -- FILTRE 2
        2 => (
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8)
        ),

        -- FILTRE 3
        3 => (
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8),
            to_signed(0, 8), to_signed(0, 8), to_signed(0, 8)
        )
    );

    -- Un biais signe sur 32 bits par filtre
    type biases_t is array (0 to 3) of signed(31 downto 0);

    constant CONV_BIASES : biases_t := (
        0 => to_signed(0, 32),
        1 => to_signed(0, 32),
        2 => to_signed(0, 32),
        3 => to_signed(0, 32)
    );

end package cnn_weights_pkg;
