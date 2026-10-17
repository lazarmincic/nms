library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TOP_RISCV is
   port(
      -- Globalna sinhronizacija
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- Interfejs ka memoriji za podatke
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      -- Interfejs ka memoriji za instrukcije
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_we_o       : out std_logic_vector(3 downto 0));  
end entity;

architecture structural of TOP_RISCV is

   signal instruction_s      : std_logic_vector(31 downto 0);

   signal mem_to_reg_s       : std_logic;
   signal alu_op_s           : std_logic_vector(4 downto 0);
   signal alu_src_b_s        : std_logic;
   signal rd_we_s            : std_logic;
   signal pc_next_sel_s      : std_logic_vector (1 downto 0);

   signal if_id_flush_s      : std_logic;

   signal alu_forward_a_s    : std_logic_vector(1 downto 0);
   signal alu_forward_b_s    : std_logic_vector(1 downto 0);
   signal branch_forward_a_s : std_logic;
   signal branch_forward_b_s : std_logic;
   signal branch_condition_s : std_logic;

   signal pc_en_s            : std_logic;
   signal if_id_en_s         : std_logic;
   
   signal instr_mem_address_s : std_logic_vector (31 downto 0);
         
   -- za branch predictor
   signal branch_adder_id_s : std_logic_vector (31 downto 0);
   signal pred_address_s : std_logic_vector (31 downto 0);
   signal pred_taken_s : std_logic;
   
   signal pred_taken_id_s : std_logic;
   signal pred_target_id_s : std_logic_vector (31 downto 0);
   
   signal pc_id_s : std_logic_vector (31 downto 0);
   
   signal id_ex_flush_s : std_logic;
   
   --prosirenje do 32I
   signal rd_be_s: std_logic_vector (1 downto 0);
   signal sext_op_s: std_logic_vector (1 downto 0);
   
   signal mem_unsigned_s: std_logic;
   
   -- za LUI
   signal set_a_to_0_s: std_logic;
   -- za AUIPC
   signal a_is_pc_s: std_logic;
   -- za branch instr.
   signal branch_op_s: std_logic_vector (2 downto 0);
   
begin
   -- Instanca datapath-a
   data_path_1: entity work.data_path
      port map (
         -- sinhronizacija
         clk                 => clk,
         reset               => reset,
         -- interfejs ka memoriji za instrukcije
         instr_mem_address_o => instr_mem_address_s,
         instr_mem_read_i    => instr_mem_read_i,
         instruction_o       => instruction_s,
         -- interfejs ka memoriji za podatke
         data_mem_address_o  => data_mem_address_o,
         data_mem_write_o    => data_mem_write_o,
         data_mem_read_i     => data_mem_read_i,
         -- kontrolni signali koji dolaze iz controlpath-a
         mem_to_reg_i        => mem_to_reg_s,
         alu_op_i            => alu_op_s,
         alu_src_b_i         => alu_src_b_s,
         rd_we_i             => rd_we_s,
         pc_next_sel_i       => pc_next_sel_s,
         branch_condition_o  => branch_condition_s,
         -- kontrolni signali za prosledjivanje operanada u ranije faze protocne obrade
         alu_forward_a_i     => alu_forward_a_s,
         alu_forward_b_i     => alu_forward_b_s,
         branch_forward_a_i  => branch_forward_a_s,
         branch_forward_b_i  => branch_forward_b_s,
         -- kontrolni signal za resetovanje if/id registra
         if_id_flush_i       => if_id_flush_s,
         -- kontrolni signali za zaustavljanje protocne obrade
         pc_en_i             => pc_en_s,
         if_id_en_i          => if_id_en_s,
         -- dodatni portovi za branch predict logiku
         branch_adder_id_o => branch_adder_id_s,
         pred_address_i => pred_address_s, 
         pred_taken_i => pred_taken_s,
         pred_taken_id_o => pred_taken_id_s,
         pred_target_id_o => pred_target_id_s,
         pc_id_o => pc_id_s,
         
         id_ex_flush_i => id_ex_flush_s,
         
         -- prosirenje do 32I
         rd_be_i => rd_be_s,
         sext_op_i => sext_op_s,
         mem_unsigned_i => mem_unsigned_s,
         -- LUI
         set_a_to_0_i => set_a_to_0_s,
         -- AUIPC
         a_is_pc_i => a_is_pc_s,
         -- za branch instr.
         branch_op_i => branch_op_s
         ); 

    instr_mem_address_o <= instr_mem_address_s;

   -- Instanca controlpath-a
   control_path_1: entity work.control_path
      port map (
         -- sinhronizacija
         clk                 => clk,
         reset               => reset,
         -- instrukcija dolazi iz datapah-a
         instruction_i       => instruction_s,
         -- kontrolni signali koji se prosledjiuju u datapath
         mem_to_reg_o        => mem_to_reg_s,
         alu_op_o            => alu_op_s,
         alu_src_b_o         => alu_src_b_s,
         rd_we_o             => rd_we_s,
         pc_next_sel_o       => pc_next_sel_s,
         branch_condition_i  => branch_condition_s,
         -- kontrolni signali za prosledjivanje operanada u ranije faze protocne obrade
         alu_forward_a_o     => alu_forward_a_s,
         alu_forward_b_o     => alu_forward_b_s,
         branch_forward_a_o  => branch_forward_a_s,
         branch_forward_b_o  => branch_forward_b_s,
         -- kontrolni signal za resetovanje if/id registra
         data_mem_we_o       => data_mem_we_o,
         if_id_flush_o       => if_id_flush_s,
         -- kontrolni signali za zaustavljanje protocne obrade
         pc_en_o             => pc_en_s,
         if_id_en_o          => if_id_en_s,
         
         pc_if_i => instr_mem_address_s,
         pred_address_o => pred_address_s, 
         branch_adder_id_i => branch_adder_id_s,
         pred_taken_o => pred_taken_s,
         
         pred_taken_id_i => pred_taken_id_s,
         pred_target_id_i => pred_target_id_s,
         
         pc_id_i => pc_id_s,
         
         id_ex_flush_o => id_ex_flush_s,
         
         -- prosirenje do 32I
         rd_be_o => rd_be_s,
         sext_op_o => sext_op_s,
         
         mem_unsigned_o => mem_unsigned_s,
         
         -- LUI
         set_a_to_0_o => set_a_to_0_s,
         -- AUIPC
         a_is_pc_o => a_is_pc_s,
         -- za branch instr.
         branch_op_o => branch_op_s
         );
   
end architecture;
