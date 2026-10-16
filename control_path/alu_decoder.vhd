library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_ops_pkg.all;

entity alu_decoder is
   port ( 
      -- from data_path
      alu_2bit_op_i  : in std_logic_vector(1 downto 0);
      funct3_i       : in std_logic_vector (2 downto 0);
      funct7_i       : in std_logic_vector (6 downto 0);
      -- to data_path
      alu_op_o       : out std_logic_vector(4 downto 0));  
end entity;

architecture behavioral of alu_decoder is
begin 

   -- pronalazi odgovarajucu operaciju ALU jedinice u odnosu na:
   --    dvobitni signal alu_2bit_op koji dolazi iz control decodera
   --    funct3 i funct7 polja u instrukciji
   alu_dec:process(alu_2bit_op_i,funct3_i,funct7_i)is
   begin
      -- podrazumevane vrednosti
      alu_op_o <= "00000";
      case alu_2bit_op_i is
         when "00" =>  -- LOAD / STORE
            alu_op_o <= add_op;
         when "01" =>  -- B tip
            alu_op_o <= eq_op;
         when "10" => -- R tip
            case funct3_i is
               when "000" =>
                  alu_op_o <= add_op;
                  if(funct7_i(5)='1')then 
                     alu_op_o <= sub_op;
                  end if;
               when "110" =>
                  alu_op_o <= or_op;
               when "001" =>
                  alu_op_o <= sll_op;
               when "010" =>
                  alu_op_o <= lts_op;
               when "011" =>
                  alu_op_o <= ltu_op;
               when "100" =>
                  alu_op_o <= xor_op;
               when "101" =>
                  alu_op_o <= srl_op;
                  if (funct7_i(5)='1') then
                     alu_op_o <= sra_op;
                  end if;
               when others =>
                  alu_op_o <= and_op;
            end case;
        when "11" => -- I tip 
            case funct3_i is
                when "000" =>
                    alu_op_o <= add_op; 
                when "110" =>
                    alu_op_o <= or_op;
                when "001" =>
                    alu_op_o <= sll_op;
                when "010" => 
                    alu_op_o <= lts_op;
                when "011" =>
                    alu_op_o <= ltu_op;
                when "100" =>
                    alu_op_o <= xor_op;
                when "101" =>
                    alu_op_o <= srl_op;
                    if (funct7_i(5)='1') then
                        alu_op_o <= sra_op;
                    end if;   
                when others =>
                    alu_op_o <= and_op;
            end case;
        when others =>
            alu_op_o <= and_op;
     end case;
   end process;

end architecture;
