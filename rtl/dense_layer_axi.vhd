library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.dense_weights_pkg.all;

-- Fully-connected layer: 4 signed INT8 features per beat, 10 output scores.
-- Scores are signed INT32, delivered one per AXI4-Stream beat.
entity dense_layer_axi is
  generic (FEATURE_WORDS : positive := 13 * 13);
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

architecture rtl of dense_layer_axi is
  type state_t is (COLLECT, EMIT);
  type accum_t is array (0 to NUM_CLASSES-1) of signed(31 downto 0);
  signal state : state_t := COLLECT;
  signal input_index : natural range 0 to FEATURE_WORDS-1 := 0;
  signal output_index : natural range 0 to NUM_CLASSES-1 := 0;
  signal accumulators : accum_t := (others => (others => '0'));
begin
  assert FEATURE_WORDS * 4 <= MAX_INPUT_FEATURES
    report "Dense weight matrix too small for input features" severity failure;
  s_axis_tready <= '1' when state = COLLECT and axis_aresetn = '1' else '0';
  m_axis_tvalid <= '1' when state = EMIT and axis_aresetn = '1' else '0';
  m_axis_tdata <= std_logic_vector(accumulators(output_index))
                   when state = EMIT else (others => '0');
  m_axis_tlast <= '1' when state = EMIT and
                            output_index = NUM_CLASSES-1 else '0';

  process(axis_aclk)
    variable next_sum : signed(31 downto 0);
    variable activation : signed(7 downto 0);
  begin
    if rising_edge(axis_aclk) then
      if axis_aresetn = '0' then
        state <= COLLECT;
        input_index <= 0;
        output_index <= 0;
        for class_id in 0 to NUM_CLASSES-1 loop
          accumulators(class_id) <= DENSE_BIASES(class_id);
        end loop;
      elsif state = COLLECT then
        if s_axis_tvalid = '1' then
          for class_id in 0 to NUM_CLASSES-1 loop
            next_sum := accumulators(class_id);
            for channel in 0 to 3 loop
              activation := signed(s_axis_tdata(channel*8+7 downto channel*8));
              next_sum := next_sum + resize(
                activation * DENSE_WEIGHTS(class_id)(input_index*4+channel), 32);
            end loop;
            accumulators(class_id) <= next_sum;
          end loop;
          if input_index = FEATURE_WORDS-1 then
            assert s_axis_tlast = '1'
              report "Dense layer: missing TLAST on last input" severity warning;
            input_index <= 0;
            output_index <= 0;
            state <= EMIT;
          else
            assert s_axis_tlast = '0'
              report "Dense layer: early TLAST" severity warning;
            input_index <= input_index + 1;
          end if;
        end if;
      else
        if m_axis_tready = '1' then
          if output_index = NUM_CLASSES-1 then
            output_index <= 0;
            input_index <= 0;
            for class_id in 0 to NUM_CLASSES-1 loop
              accumulators(class_id) <= DENSE_BIASES(class_id);
            end loop;
            state <= COLLECT;
          else
            output_index <= output_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
