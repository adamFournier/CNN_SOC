library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Demonstration-only signed INT8 weights for validating the RTL MAC.
-- They are NOT trained CNN classifier parameters.
-- Feature order: pixel-major, channels 0,1,2,3 at each 13x13 location.
package dense_weights_pkg is
  constant NUM_CLASSES : positive := 10;
  constant MAX_INPUT_FEATURES : positive := 13 * 13 * 4;
  type dense_row_t is array (0 to MAX_INPUT_FEATURES-1) of signed(7 downto 0);
  type dense_matrix_t is array (0 to NUM_CLASSES-1) of dense_row_t;
  type dense_bias_t is array (0 to NUM_CLASSES-1) of signed(31 downto 0);
  constant DENSE_WEIGHTS : dense_matrix_t := (
    0 => (0 => to_signed( 1, 8), others => to_signed(0, 8)),
    1 => (1 => to_signed( 1, 8), others => to_signed(0, 8)),
    2 => (2 => to_signed( 1, 8), others => to_signed(0, 8)),
    3 => (3 => to_signed( 1, 8), others => to_signed(0, 8)),
    4 => (0 | 1 | 2 | 3 => to_signed( 1, 8), others => to_signed(0, 8)),
    5 => (0 | 1 | 2 | 3 => to_signed(-1, 8), others => to_signed(0, 8)),
    6 => (4 => to_signed( 1, 8), others => to_signed(0, 8)),
    7 => (5 => to_signed( 1, 8), others => to_signed(0, 8)),
    8 => (6 => to_signed( 1, 8), others => to_signed(0, 8)),
    9 => (7 => to_signed( 1, 8), others => to_signed(0, 8))
  );
  constant DENSE_BIASES : dense_bias_t := (others => to_signed(0, 32));
end package;
