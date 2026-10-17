library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity branch_eval is
    port (
        operand1_i: in std_logic_vector (31 downto 0);
        operand2_i: in std_logic_vector (31 downto 0);
        operation_i: in std_logic_vector (2 downto 0);
        branch_condition_o: out std_logic
    );
end entity;

architecture behavioral of branch_eval is
begin

    beu: process (operand1_i, operand2_i, operation_i) is
    begin
        branch_condition_o <= '0';
        case operation_i is
            when "000" =>
                if signed(operand1_i) = signed(operand2_i) then
                    branch_condition_o <= '1';
                end if;
            when "001" =>
                if signed(operand1_i) /= signed(operand2_i) then
                    branch_condition_o <= '1';
                end if; 
            when "100" =>  -- less
                if signed(operand1_i) < signed(operand2_i) then
                    branch_condition_o <= '1';
                end if;
            when "101" => --greather or equal
                if signed(operand1_i) >= signed(operand2_i) then
                    branch_condition_o <= '1';
                end if;
            when "110" => --less unsigned
                if unsigned(operand1_i) < unsigned(operand2_i) then
                    branch_condition_o <= '1';
                end if;
            when "111" => --greather or equal unsigned
                if unsigned(operand1_i) >= unsigned(operand2_i) then
                    branch_condition_o <= '1';
                end if;
            when others =>
        end case;
    end process;

end architecture;