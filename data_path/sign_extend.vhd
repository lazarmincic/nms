-- prosirivanje znaka unutar wb faze za lb, lh, lbu i bhu instrukcije

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_extend is
   port (
       input_i : in std_logic_vector (31 downto 0);
       sext_op_i : in std_logic_vector (1 downto 0); -- byte enable
       output_o : out std_logic_vector (31 downto 0)
   );
end entity;

architecture Behavioral of sign_extend is
begin

    process (input_i, sext_op_i) is
    begin
        case (sext_op_i) is
            when "00" => -- byte
                output_o <=  ( 31 downto 8 => input_i(7)) & input_i(7 downto 0);
            when "01" => -- half
                output_o <= (31 downto 16 => input_i(15)) & input_i(15 downto 0);
            when others => -- word
                output_o <= input_i;
        end case;
    end process;

end architecture;