library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.controlpath_signals_pkg.all;

entity control_path is
   port (
      -- sinhronizacija
      clk                : in  std_logic;
      reset              : in  std_logic;
      -- instrukcija dolazi iz datapah-a
      instruction_i      : in  std_logic_vector (31 downto 0);
      -- Statusni signaln iz datapath celine
      branch_condition_i : in  std_logic;
      -- kontrolni signali koji se prosledjiuju u datapath
      mem_to_reg_o       : out std_logic;
      alu_op_o           : out std_logic_vector(4 downto 0);
      alu_src_b_o        : out std_logic;
      rd_we_o            : out std_logic;
      pc_next_sel_o      : out std_logic_vector (1 downto 0);
      data_mem_we_o      : out std_logic_vector(3 downto 0);
      -- kontrolni signali za prosledjivanje operanada u ranije faze protocne obrade
      alu_forward_a_o    : out std_logic_vector (1 downto 0);
      alu_forward_b_o    : out std_logic_vector (1 downto 0);
      branch_forward_a_o : out std_logic;  -- mux a 
      branch_forward_b_o : out std_logic;   -- mux b
      -- kontrolni signal za resetovanje if/id registra
      if_id_flush_o      : out std_logic;
      -- kontrolni signali za zaustavljanje protocne obrade
      pc_en_o            : out std_logic;
      if_id_en_o         : out std_logic;
      -- vrednost pc registra u if fazi
      pc_if_i : in std_logic_vector (31 downto 0);
      -- predvidjena vrednost adrese skoka za data path (if)
      pred_address_o : out std_logic_vector (31 downto 0);
      -- izracunata adresa skoka u id fazi
      branch_adder_id_i : in std_logic_vector (31 downto 0);
      -- predviđen rezultat skoka (if)
      pred_taken_o : out std_logic;
      -- iz datapath-a - predviđena adresa i rezultat u id fazi (registrovan)
      pred_taken_id_i : in std_logic;
      pred_target_id_i : in std_logic_vector (31 downto 0);
      -- vrednost pc registra u id fazi (za upis u btb i bht)
      pc_id_i : in std_logic_vector (31 downto 0);
      -- flush za id ex registar unutar data path a
      id_ex_flush_o: out std_logic;
      
      -- proširenje do 32I
      rd_be_o: out std_logic_vector (1 downto 0); -- byte enable
      sext_op_o: out std_logic_vector (1 downto 0); -- sign extend operand
      mem_unsigned_o: out std_logic -- bira izmedju lb i lbu (lh i lhu) u wb fazi
      );
end entity;


architecture behavioral of control_path is
begin


   --*********** Kombinaciona logika ******************

   -- izdvoji adrese operanada iz instrukcije
   rs1_address_id_s <= instruction_i(19 downto 15);
   rs2_address_id_s <= instruction_i(24 downto 20);
   rd_address_id_s  <= instruction_i(11 downto 7);

   funct7_id_s <= instruction_i(31 downto 25);
   funct3_id_s <= instruction_i(14 downto 12);

   -- signal upisa 32-bitnog podatka u memoriju se prosiruje na cetiri 
   -- memorija je bajt-adresibilna pa postoji we signal za svaki bajt na lokaciji sirine 32 bita  
   data_mem_write_enable :
      data_mem_we_o <= "1111" when data_mem_we_mem_s = '1' else
                       "0000";

   -- ovaj proces nadzire instrukcije skokova
   -- za uslovni skok
   --    kontrolise multiplekser za sledecu adresu PC-a
   --    resetuje if/id registar ukoliko je branch predict jedinica pogresila
   --    azurira btb i bht
   
   -- branch_condition_i je ulaz iz komparatora, treba uzeti u obzir tip instrukcije - da li dolazi do grananja pri
   --   jednakosti ili pri nejednakosti
   branch_taken_s <= branch_condition_i when funct3_id_s(0)='0' else
                     not branch_condition_i when funct3_id_s(0)='1';
                     
   pc_next_if_s : process(branch_id_s, branch_taken_s, bcc_id_s, pred_taken_s, pred_taken_id_i,
        branch_adder_id_i, pred_target_id_i)
   begin
      if_id_flush_s <= '0';
      pc_next_sel_o <= "00"; -- nema skoka
      
      btb_bht_we_s <= "00";
      id_ex_flush_s <= '0';
      -- if faza
      if (pred_taken_s = '1') then
         pc_next_sel_o <= "01"; 
      end if;
      -- id faza
      if (branch_id_s = '1') then -- instrukcija skoka
         if (branch_taken_s = pred_taken_id_i and branch_adder_id_i = pred_target_id_i) then
            -- skok je tačno predviđen - adresa i ishod grane su tacno predvidjeni
            -- azuriraj bht unutar bpu, btb se ne azurira
            btb_bht_we_s(0) <= '1';
         else
            -- skok netačno predviđen - flush
            -- prosledi izracunatu adresu ako se skok desio
            -- prediktor je vec prosledio pogresnu instrukciju u id, pa immediate vrednost 
            -- izracunata nije ta na koju treba da se skoci.
            if (branch_taken_s = '1') then
                -- prevideo da ne skace a skocio
                pc_next_sel_o <= "10";
                if_id_flush_s <= '1';
            else
                -- predvideo da skace a ne skace
                if_id_flush_s <= '1';
                id_ex_flush_s <= '1';
                pc_next_sel_o <= "11";
            end if;
            -- azuriraj btb ukoliko se adrese ne poklapaju
            if (branch_adder_id_i /= pred_target_id_i) then
                btb_bht_we_s(1) <= '1';
            end if;
            -- azuriraj bht ukoliko se ishodi skoka ne poklapaju
            if (branch_taken_s /= pred_taken_id_i) then
                btb_bht_we_s(0) <= '1';
            end if;
         end if;
      end if;
   end process;

   bpu_en_s <= if_id_en_s;

   --*********** Sekvencijalna logika ******************
   --ID/EX registar
   id_ex : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0' or control_pass_s = '0' or id_ex_flush_s = '1')then
            branch_ex_s      <= '0';
            funct3_ex_s      <= (others => '0');
            funct7_ex_s      <= (others => '0');
            alu_src_b_ex_s   <= '0';
            mem_to_reg_ex_s  <= '0';
            alu_2bit_op_ex_s <= (others => '0');
            rs1_address_ex_s <= (others => '0');
            rs2_address_ex_s <= (others => '0');
            rd_address_ex_s  <= (others => '0');
            rd_we_ex_s       <= '0';
            data_mem_we_ex_s <= '0';
         else
            branch_ex_s      <= branch_id_s;
            funct7_ex_s      <= funct7_id_s;
            funct3_ex_s      <= funct3_id_s;
            alu_src_b_ex_s   <= alu_src_b_id_s;
            mem_to_reg_ex_s  <= mem_to_reg_id_s;
            alu_2bit_op_ex_s <= alu_2bit_op_id_s;
            rs1_address_ex_s <= rs1_address_id_s; rs2_address_ex_s <= rs2_address_id_s;
            rd_address_ex_s  <= rd_address_id_s;
            rd_we_ex_s       <= rd_we_id_s;
            data_mem_we_ex_s <= data_mem_we_id_s;
         end if;
      end if;
   end process;

   --EX/MEM registar
   ex_mem : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            data_mem_we_mem_s <= '0';
            rd_we_mem_s       <= '0';
            mem_to_reg_mem_s  <= '0';
            rd_address_mem_s  <= (others => '0');
            funct3_mem_s <= (others => '0');
         else
            data_mem_we_mem_s <= data_mem_we_ex_s;
            rd_we_mem_s       <= rd_we_ex_s;
            mem_to_reg_mem_s  <= mem_to_reg_ex_s;
            rd_address_mem_s  <= rd_address_ex_s;
            funct3_mem_s <= funct3_ex_s;
         end if;
      end if;
   end process;

   --MEM/WB registar
   mem_wb : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            rd_we_wb_s      <= '0';
            mem_to_reg_wb_s <= '0';
            rd_address_wb_s <= (others => '0');
            rd_be_wb_s <= (others => '0');
            mem_unsigned_wb_s <= '0';
         else
            rd_we_wb_s      <= rd_we_mem_s;
            mem_to_reg_wb_s <= mem_to_reg_mem_s;
            rd_address_wb_s <= rd_address_mem_s;
            rd_be_wb_s <= rd_be_mem_s;
            mem_unsigned_wb_s <= mem_unsigned_mem_s;
         end if;
      end if;
   end process;



   --*********** Instanciranje ******************

   -- Dekoder za kontrolne signale
   ctrl_dec : entity work.ctrl_decoder(behavioral)
      port map(
         opcode_i      => instruction_i(6 downto 0),
         branch_o      => branch_id_s,
         mem_to_reg_o  => mem_to_reg_id_s,
         data_mem_we_o => data_mem_we_id_s,
         alu_src_b_o   => alu_src_b_id_s,
         rd_we_o       => rd_we_id_s,
         rs1_in_use_o  => rs1_in_use_id_s,
         rs2_in_use_o  => rs2_in_use_id_s,
         alu_2bit_op_o => alu_2bit_op_id_s);

   -- Dekoder za ALU operaciju
   alu_dec : entity work.alu_decoder(behavioral)
      port map(
         alu_2bit_op_i => alu_2bit_op_ex_s,
         funct3_i      => funct3_ex_s,
         funct7_i      => funct7_ex_s,
         alu_op_o      => alu_op_o);

   -- Jedinica za prosledjivanje operanada
   forwarding_u : entity work.forwarding_unit(behavioral)
      port map (
         rd_we_mem_i        => rd_we_mem_s,
         rd_address_mem_i   => rd_address_mem_s,
         rd_we_wb_i         => rd_we_wb_s,
         rd_address_wb_i    => rd_address_wb_s,
         rs1_address_ex_i   => rs1_address_ex_s,
         rs2_address_ex_i   => rs2_address_ex_s,
         rs1_address_id_i   => rs1_address_id_s,
         rs2_address_id_i   => rs2_address_id_s,
         alu_forward_a_o    => alu_forward_a_o,
         alu_forward_b_o    => alu_forward_b_o,
         branch_forward_a_o => branch_forward_a_o,
         branch_forward_b_o => branch_forward_b_o);

   -- Jedinica za razresavanje hazarda
   hazard_u : entity work.hazard_unit(behavioral)
      port map (
         rs1_address_id_i => rs1_address_id_s,
         rs2_address_id_i => rs2_address_id_s,
         rs1_in_use_i     => rs1_in_use_id_s,
         rs2_in_use_i     => rs2_in_use_id_s,
         branch_id_i      => branch_id_s,

         rd_address_ex_i => rd_address_ex_s,
         mem_to_reg_ex_i => mem_to_reg_ex_s,
         rd_we_ex_i      => rd_we_ex_s,

         rd_address_mem_i => rd_address_mem_s,
         mem_to_reg_mem_i => mem_to_reg_mem_s,

         pc_en_o        => pc_en_o,
         if_id_en_o     => if_id_en_s,
         control_pass_o => control_pass_s);



   --********** Izlazi **************

   -- prosledi kontrolne signale datapath-u
   if_id_en_o    <= if_id_en_s;
   mem_to_reg_o  <= mem_to_reg_wb_s;
   alu_src_b_o   <= alu_src_b_ex_s;
   rd_we_o       <= rd_we_wb_s;
   if_id_flush_o <= if_id_flush_s;
   id_ex_flush_o <= id_ex_flush_s;


    branch_predict_u: entity work.branch_predict_unit(behavioral)
        generic map (
            BTB_ADDR_WIDTH => 5,
            CNT_WIDTH => 2
        )
        port map (
            clk => clk,
            reset => reset,
            pc_if_i => pc_if_i,
            pred_taken_o => pred_taken_s,
            pred_address_o => pred_address_s,
            pc_id_i => pc_id_i,
            target_addr_id_i => branch_adder_id_i,
            btb_bht_we_i => btb_bht_we_s,
            branch_taken_id_i => branch_taken_s,
            en_i => bpu_en_s
        );
        
    pred_taken_o <= pred_taken_s;
    pred_address_o <= pred_address_s;
    
    -- kontrolni signal za biranje bitova za prosledjivanje u wb fazu
    -- ( za read byte i read half word instrukcije)
    
    rd_be_mem_s <= funct3_mem_s(1 downto 0);  -- 00 - byte, 01 - half, 10 - word
               
    rd_be_o <= rd_be_mem_s;
    
    sext_op_o <= rd_be_wb_s;
    
    mem_unsigned_mem_s <= '1' when funct3_mem_s(2) = '1' else
                          '0';
                          
    mem_unsigned_o <= mem_unsigned_wb_s;

end architecture;

