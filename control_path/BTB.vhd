-- Branch-Target Address Cache
-- sinhroni upis, asinhrono citanje

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

entity BTB is
    generic (
        WIDTH : positive
    );
    port (
        clk: in std_logic;
        reset: in std_logic;
        rd_address_i : in std_logic_vector (WIDTH - 1 downto 0);
        target_o : out std_logic_vector (31 downto 0);
        tag_o : out std_logic_vector (32-2-WIDTH-1 downto 0);
        wr_address_i : in std_logic_vector (WIDTH - 1 downto 0);
        target_i : in std_logic_vector (31 downto 0);
        tag_i : in std_logic_vector (32-2-WIDTH-1 downto 0);
        we_i : in std_logic;
        valid_o: out std_logic;
        en_i: in std_logic;
        branch_type_i: in std_logic_vector (1 downto 0);
        branch_type_o: out std_logic_vector (1 downto 0)
    );
end BTB;

architecture behavioral of BTB is
   type target_type is array (0 to 2**WIDTH - 1) of std_logic_vector (31 downto 0); 
   signal target_s : target_type := (others => (others => '0'));
   type tag_type is array (0 to 2**WIDTH - 1) of std_logic_vector (32-2-WIDTH-1 downto 0);
   signal tag_s : tag_type := (others => (others => '0'));
   signal valid_s : std_logic_vector (0 to 2**WIDTH - 1) := (others => '0');
   constant cond: std_logic := '0';
   constant uncond: std_logic := '1';
   type branch_type_t  is array (0 to 2**WIDTH - 1) of std_logic_vector (1 downto 0);
   signal branch_type_s : branch_type_t := (others => (others => '0')); --meta podaci, tip skoka
begin

    -- sinhroni upis
    process (clk) 
    begin
        if(falling_edge(clk)) then -- nisam siguran
            if (reset = '0') then
                valid_s <= (others => '0');
            elsif(we_i = '1' and en_i = '1') then
                target_s(to_integer(unsigned(wr_address_i))) <= target_i;
                tag_s(to_integer(unsigned(wr_address_i))) <= tag_i;
                valid_s(to_integer(unsigned(wr_address_i))) <= '1';
                branch_type_s(to_integer(unsigned(wr_address_i))) <= branch_type_i;
            end if;
        end if;
    end process;
    
    -- asinhrono citanje
    target_o <= target_s (to_integer(unsigned(rd_address_i)));
    tag_o <= tag_s (to_integer(unsigned(rd_address_i)));
    valid_o <= valid_s (to_integer(unsigned(rd_address_i)));
    branch_type_o <= branch_type_s (to_integer(unsigned(rd_address_i)));
    

end architecture;