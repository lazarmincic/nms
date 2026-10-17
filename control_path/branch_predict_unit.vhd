library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity branch_predict_unit is
    generic (
        BTB_ADDR_WIDTH : positive := 5;
        CNT_WIDTH: positive := 2
    );
    port (
        clk : in std_logic;
        reset: in std_logic;
        pc_if_i : in std_logic_vector (31 downto 0);
        pred_taken_o : out std_logic; 
        pred_address_o : out std_logic_vector (31 downto 0);
        
        pc_id_i : in std_logic_vector (31 downto 0);
        target_addr_id_i: in std_logic_vector (31 downto 0);
        btb_bht_we_i : in std_logic_vector (1 downto 0);
        branch_taken_id_i : in std_logic;
        en_i : in std_logic
    );
end entity;

architecture Behavioral of branch_predict_unit is
    signal rd_index : std_logic_vector (BTB_ADDR_WIDTH-1 downto 0);
    signal rd_tag : std_logic_vector (32-2-BTB_ADDR_WIDTH-1 downto 0);
    signal target_addr : std_logic_vector (31 downto 0);
    signal target_tag: std_logic_vector (32-2-BTB_ADDR_WIDTH-1 downto 0);
    signal wr_index : std_logic_vector (BTB_ADDR_WIDTH-1 downto 0);
    signal wr_tag : std_logic_vector (32-2-BTB_ADDR_WIDTH-1 downto 0);
    signal btb_we : std_logic ;
    signal target_valid : std_logic;
    signal btb_hit: std_logic;
    signal bht_taken: std_logic;
    signal bht_we : std_logic ;
begin

    -- treba promeniti u gshare tip (ovo je smit)

    -- IF faza (data path a) - citanje
    rd_index <= pc_if_i (BTB_ADDR_WIDTH+2-1 downto 2);
    rd_tag <= pc_if_i (31 downto 2+BTB_ADDR_WIDTH);
    
    -- ID faza pisanje
    wr_index <= pc_id_i (BTB_ADDR_WIDTH+2-1 downto 2);
    wr_tag <= pc_id_i (31 downto 2+BTB_ADDR_WIDTH);
    
    btb_we <= btb_bht_we_i(1);
    bht_we <= btb_bht_we_i(0);
    
    -- instanca BTB
    btb: entity work.BTB
        generic map (
            WIDTH => BTB_ADDR_WIDTH
            )
        port map (
            clk => clk,
            reset => reset,
            rd_address_i => rd_index,
            target_o => target_addr,
            tag_o => target_tag,
            wr_address_i => wr_index,
            target_i => target_addr_id_i,
            tag_i => wr_tag,
            we_i => btb_we,
            valid_o => target_valid,
            en_i => en_i
        );
    
    btb_hit <= '1' when (rd_tag = target_tag) and target_valid = '1'
          else '0';
          
    pred_address_o <= target_addr;
    
    -- instanca BHT
    
    bht: entity work.BHT
        generic map (
            CNT_WIDTH => CNT_WIDTH,
            AWIDTH => BTB_ADDR_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            rd_addr_i => rd_index,
            taken_o => bht_taken,
            wr_addr_i => wr_index,
            taken_i => branch_taken_id_i,
            we_i => bht_we,
            en_i => en_i
        );
        
    pred_taken_o <= bht_taken and btb_hit ;

end architecture;