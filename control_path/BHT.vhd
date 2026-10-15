-- Branch History Table

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

entity BHT is
    generic (
        CNT_WIDTH: positive; -- broj bita brojaca sa zasicenjem
        AWIDTH : positive   -- broj bitova adrese
    );
    port (
        clk: in std_logic;
        reset: in std_logic;
        rd_addr_i: in std_logic_vector (AWIDTH - 1 downto 0);
        taken_o : out std_logic;
        wr_addr_i : in std_logic_vector (AWIDTH - 1 downto 0);
        taken_i : in std_logic;
        we_i: in std_logic;
        en_i: in std_logic
    );
end BHT;

architecture behavioral of BHT is
    type taken_type is array (0 to 2**AWIDTH-1) of std_logic_vector (CNT_WIDTH-1 downto 0);
    signal taken_s : taken_type := (others => (others => '0'));
begin

    -- asinhrono citanje
    
    taken_o <= taken_s (to_integer(unsigned(rd_addr_i)))(CNT_WIDTH-1) when en_i = '1' else '0';

    -- sinhroni upis
    process (clk) 
        variable wr_idx : integer range 0 to 2**AWIDTH - 1 := 0;
        constant all_ones : unsigned := to_unsigned(2**CNT_WIDTH-1,CNT_WIDTH);
        constant all_zeroes: unsigned := to_unsigned(0,CNT_WIDTH);
    begin
        if(falling_edge(clk)) then --
            if (reset = '0') then
                taken_s <= (others => (others => '0'));
            elsif(we_i = '1' and en_i = '1') then
                wr_idx := to_integer(unsigned(wr_addr_i));
                if (taken_i = '1') then --taken_s(wr_idx)(CNT_WIDTH-1)
                    -- sabiraj sa zasicenjem
                    if (unsigned(taken_s(wr_idx)) < all_ones) then
                        taken_s(wr_idx) <= std_logic_vector(unsigned(taken_s(wr_idx)) + to_unsigned(1,CNT_WIDTH));
                    end if;
                else -- taken_i = '0'
                    -- oduzimaj ali zakucaj na nuli
                    if (unsigned(taken_s(wr_idx)) > all_zeroes) then
                        taken_s(wr_idx) <= std_logic_vector(unsigned(taken_s(wr_idx)) - to_unsigned(1,CNT_WIDTH));
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;