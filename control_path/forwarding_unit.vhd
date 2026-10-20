library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity forwarding_unit is
   port (
      -- ulazi iz ID faze
      rs1_address_id_i   : in  std_logic_vector(4 downto 0);
      rs2_address_id_i   : in  std_logic_vector(4 downto 0);
      -- ulazi iz EX faze
      rs1_address_ex_i   : in  std_logic_vector(4 downto 0);
      rs2_address_ex_i   : in  std_logic_vector(4 downto 0);
      -- ulazi iz MEM faze
      rd_we_mem_i        : in  std_logic;
      rd_address_mem_i   : in  std_logic_vector(4 downto 0);
      -- ulazi iz WB faze
      rd_we_wb_i         : in  std_logic;
      rd_address_wb_i    : in  std_logic_vector(4 downto 0);
      -- izlazi za prosledjivanje operanada ALU jedinici
      alu_forward_a_o    : out std_logic_vector (1 downto 0);
      alu_forward_b_o    : out std_logic_vector(1 downto 0);
      -- izlazi za prosledjivanje operanada komparatoru za odredjivanje uslova skoka
      branch_forward_a_o : out std_logic_vector (1 downto 0);
      branch_forward_b_o : out std_logic_vector (1 downto 0);
      -- prosledjivanje iz ex u id fazu za komparator za uslovne skokove
      rd_we_ex_i: in std_logic;
      rd_address_ex_i: in std_logic_vector (4 downto 0);
      -- prosledjivanje iz mem u id ako je load bio u mem
      mem_to_reg_mem_i: in std_logic;
      -- in use signali
      rs1_in_use_id_i: in std_logic;
      rs2_in_use_id_i: in std_logic;
      rs1_in_use_ex_i: in std_logic;
      rs2_in_use_ex_i: in std_logic
      );
end entity;

architecture Behavioral of forwarding_unit is
   constant zero_c : std_logic_vector (4 downto 0) := std_logic_vector(to_unsigned(0, 5));
begin

   -- proces koji kontrolise da li je potrebno prosledjivanje operanada ALU jedinici
   -- prosledjivanje iz MEM faze ima veci prioritet od prosledjivanja iz WB faze,
   -- zato sto je vrednost novija ('svezija')
   forward_proc : process(rd_we_mem_i, rd_address_mem_i, rd_we_wb_i, rd_address_wb_i,
                          rs1_address_ex_i, rs2_address_ex_i, rs1_in_use_ex_i, rs2_in_use_ex_i, 
                          mem_to_reg_mem_i
                          ) is
   begin
      alu_forward_a_o <= "00";
      alu_forward_b_o <= "00";
      -- prosledjivanje signala iz WB faze
      if (rd_we_wb_i = '1' and rd_address_wb_i /= zero_c)then
         if (rd_address_wb_i = rs1_address_ex_i and rs1_in_use_ex_i = '1') then
            alu_forward_a_o <= "01";
         end if;
         if(rd_address_wb_i = rs2_address_ex_i and rs2_in_use_ex_i = '1')then
            alu_forward_b_o <= "01";
         end if;
      end if;
      -- prosledjivanje signala iz MEM faze (veci prioritet)
      if (rd_we_mem_i = '1' and rd_address_mem_i /= zero_c)then
         if (rd_address_mem_i = rs1_address_ex_i and rs1_in_use_ex_i = '1')then
            alu_forward_a_o <= "10";
            if (mem_to_reg_mem_i = '1') then
                alu_forward_a_o <= "11";
            end if;
         end if;
         if (rd_address_mem_i = rs2_address_ex_i and rs2_in_use_ex_i = '1')then
            alu_forward_b_o <= "10";
            if (mem_to_reg_mem_i = '1') then
                alu_forward_b_o <= "11";
            end if;
         end if;
      end if;
   end process;

   -- proces koji kontrolise da li je potrebno prosledjivanje operanada komparatoru za uslovne skokove
   -- prosledjivanje iz EX faze ima veci prioritet od prosledjivanja iz MEM faze,
   -- zato sto je vrednost novija ('svezija')
   
   -- podrska za branch predictor - moze da se desi situacija da je
   -- potrebno prosledjivanje komparatoru iz ex faze u id fazu
   
   forward_branch_proc : process(rd_we_mem_i, rd_address_mem_i, rd_we_ex_i, rd_address_ex_i,
                                 rs1_address_id_i, rs2_address_id_i, mem_to_reg_mem_i,
                                 rs1_in_use_id_i, rs2_in_use_id_i) is
   begin
      branch_forward_b_o <= "00";
      branch_forward_a_o <= "00";      
      
      -- prosledjivanje signala iz MEM faze
      if (rd_we_mem_i = '1' and rd_address_mem_i /= zero_c)then
         if (rd_address_mem_i = rs1_address_id_i and rs1_in_use_id_i = '1')then
            branch_forward_a_o <= "01"; 
            if (mem_to_reg_mem_i = '1') then    -- prosledjivanje iz MEM za load instr. u MEM
                branch_forward_a_o <= "11"; 
            end if;
         end if;
         if (rd_address_mem_i = rs2_address_id_i and rs2_in_use_id_i = '1')then
            branch_forward_b_o <= "01";
            if (mem_to_reg_mem_i = '1') then
                branch_forward_b_o <= "11"; 
            end if;
         end if;
      end if;
      
      -- prosleđivanje iz EX faze (veci prioritet)
      if (rd_we_ex_i = '1' and rd_address_ex_i /= zero_c) then
        if (rd_address_ex_i = rs1_address_id_i and rs1_in_use_id_i = '1') then
            branch_forward_a_o <= "10";
         end if;
         if (rd_address_ex_i = rs2_address_id_i and rs2_in_use_id_i = '1') then
            branch_forward_b_o <= "10";
         end if;
      end if;
   end process;
      
end architecture;
