library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.pcie_tx_engine_pkg.all;
use work.pci_wrapper_pkg.all;
use work.top_pkg.all;

package BP_x86_tb_pkg is

    constant C_PACKET_LEN         : integer := 24;
    constant C_TEST_LEN           : integer := 50;
    constant C_MODULE_IN_TEST     : std_logic_vector (31 downto 0) := X"FFFFFFFF";
    constant FH_TRAFFIC_GENERATOR : boolean := false;
    constant TEST_MODUL_GENERATE  : boolean := false;

    -- type to store memory read tlp requestions
    type t_read_mem is record
        requester_id    : std_logic_vector (15 downto 0);
        tag             : std_logic_vector (7 downto 0);
        dw              : std_logic_vector (7 downto 0);
        length          : std_logic_vector (9 downto 0);
        address         : std_logic_vector (31 downto 0);
        ena             : boolean;
        tlp_type        : std_logic_vector(6 downto 0);
    end record;

    -- array to store memory read tlp requestions
    type t_read_mem_arr is array (0 to 32) of t_read_mem;

    -- array event index
    type t_tx_evt_idx is array (0 to 31) of std_logic_vector (1 downto 0);

    -- this function converts string to std_logic_vector (32 downto 0)
    -- or std_logic_vector (15 downto 0) or std_logic_vector (7 downto 0)
    -- string as input (8,4 or 2 character)
    function x_read_f (s : string)return STD_LOGIC_VECTOR;
    -- this function calculates FirstDW and LastDW fields
    function dw_assign (addr : std_logic_vector(1 downto 0); len : integer) return std_logic_vector;
    -- this procedure prepares and send 3DW TLP Header
    procedure header_f (signal clk : in std_logic;
                        constant addr : in std_logic_vector(31 downto 0);
                        constant fmt : in std_logic_vector (6 downto 0);
                        constant len : in integer;
                        signal tlp_in : in t_tx_tlp_intf_q;
                        signal tlp_out : out t_tx_tlp_intf_d);
    -- this procedure handle ptm mechanism
    procedure ptm_handle (signal clk : in std_logic;
                        signal ptm_timer    : in std_logic_vector (63 downto 0);
                        signal requests : in t_read_mem;
                        signal tlp_in : in t_tx_tlp_intf_q;
                        signal tlp_out : out t_tx_tlp_intf_d);

    -- this procedure prepares and sends 3DW TLP Header for CplD packet
    procedure header_cpl (signal clk : in std_logic;
                          constant addr : in std_logic_vector (31 downto 0);
                          constant len : in integer;
                          constant req_id : std_logic_vector (15 downto 0);
                          constant dw : std_logic_vector (7 downto 0);
                          constant tag : std_logic_vector (7 downto 0);
                          signal tlp_in : in t_tx_tlp_intf_q;
                          signal tlp_out : out t_tx_tlp_intf_d);
    -- this procedure sends data payload
    type payload_t is array (0 to 128) of std_logic_vector (7 downto 0);

    -- interrupt counter to place in packet
    type interrupt_num_t is array(0 to 31) of std_logic_vector (7 downto 0);

    -- constants used as payload for completion tlps
    constant GET_MODULE_TABLE_ADDRESS : payload_t := (X"01", X"00", X"00", X"12", X"80", X"02", others => X"00");
    constant GET_MODUL_ID_PLD : payload_t := (X"08", X"80", X"10", X"20", X"30", X"10", X"01", others => X"00");
    constant GET_STATUS_INF   : payload_t := (X"09", X"80", X"10", X"20", X"31", X"10", X"FF", others => X"00");
    constant NONVOL_GET_DATA  : payload_t := (X"10", X"00", X"10", X"20", X"30", X"40", X"80", X"81", X"82", X"83", X"10", X"01", others => X"00");
    constant SET_DATA_2       : payload_t := (X"21", X"00", X"00", X"A1", X"FF", others => X"00");
    constant GET_DATA_2       : payload_t := (X"25", X"00", X"00", X"00", X"00", X"04", X"02", others => X"00");

    -- this procedure prepares tlp payload
    procedure payload_f (signal clk : in std_logic;
                         constant payload : in payload_t;
                         signal tlp_out : out t_tx_tlp_intf_d
                        );
    -- this procedure send burst of data
    procedure payload_brst_f (signal clk : in std_logic;
                         constant payload : in payload_t;
                         constant len : in integer;
                         signal tlp_out : out t_tx_tlp_intf_d
                        );
    -- this procedure send data to frame handler
    procedure fh_write (signal clk : in std_logic;
                        constant payload : in payload_t;
                        constant len : in integer;
                        constant modul_num : in integer;
                        signal tx_ready : in std_logic_vector (MODUL_NUM_CONST - 1 downto 0);
                        signal tx_valid : out std_logic_vector (MODUL_NUM_CONST - 1 downto 0);
                        signal tx_data : out std_logic_vector (7 downto 0);
                        signal tx_last : out std_logic_vector (MODUL_NUM_CONST - 1 downto 0)
                        );

    -- test vector file example :
    --
    -- m__8  XXXXXXXX  XX  XX  XX;
    --  |        |     ---------- Data
    --  |         --------------- Address
    --   ------------------------ Write 8-bit data single packets
    -- m_16  XXXXXXXX  XXXX  XXXX  XXXX;
    --  |        |     ---------- Data
    --  |         --------------- Address
    --   ------------------------ Write 16-bit data single packets
    -- m_32  XXXXXXXX  XXXXXXXX  XXXXXXXX;
    -- m_br  XXXXXXXX  XXXXXXXX  XXXXXXXX;
    --  |        |     ---------- Data
    --  |         --------------- Address
    --   ------------------------ Write 32-bit data burst or single packets
    -- w_fh  XXXXXXXX  XX  XX  XX  XX  XX;
    --  |        |     ---------- Data
    --  |         --------------- Modul number
    --   ------------------------ Write 8-bit data to bus
    -- evnt  XXXXXXXX  XX;
    --  |        |     ---------- Event idx 
    --  |         --------------- modul select (bit 0 - modul 0, bit 31 - modul 31)
    --   ------------------------ event
    -- m_cf  XXXXXXXX  XXXXXXXX;
    --  |        |     ---------- Data
    --  |         --------------- Address
    --   ------------------------ Write config packet
    -- d_cf  XXXXXXXX  XXXXXXXX;
    --  |        |     ---------- Data
    --  |         --------------- Address
    --   ------------------------ Read config packet
    -- d_32  XXXXXXXX  XX;
    --  |        |     ---------- Data length
    --  |         --------------- Address
    --   ------------------------ Read data packet
    -- wait  XXXXXXXX  XXXXXXXX;
    --  |        |     ---------- Time for wait us
    --  |         --------------- unused
    --   ------------------------ Wait command
    --------------------------------------------------------------------------------
    -- this procedure reads stimulus vectors from test file
    procedure stim_file_read (
        constant stim_file  : in string;
        signal ptm_time     : in std_logic_vector (63 downto 0);
        signal clk          : in std_logic;
        signal clk_100      : in std_logic;
        signal tlp_in       : in t_tx_tlp_intf_q;
        signal np_req_pend  : in std_logic;
        signal tlp_out      : out t_tx_tlp_intf_d;
        signal tx_ready : in std_logic_vector (31 downto 0);
        signal tx_valid : out std_logic_vector (31 downto 0);
        signal tx_data : out std_logic_vector (7 downto 0);
        signal tx_last : out std_logic_vector (31 downto 0);
        signal tx_evt_req   : out std_logic_vector (31 downto 0);
        signal tx_evt_idx   : out t_tx_evt_idx;
        signal tx_evt_rdy   : in std_logic_vector(31 downto 0);
        signal requests     : in t_read_mem;
        signal comment  : out string
    );


end package;
package body BP_x86_tb_pkg is
    -- array for x_read_f
    type indexed_char is array (0 to 15) of character;
    constant HEX_VALUE : indexed_char :=
                ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

--------------------------------------------------------------------------------
-- read hex string
--------------------------------------------------------------------------------
    function x_read_f (s: string) return std_logic_vector is
        variable k : integer;
        variable v : std_logic_vector ((s'high*4)-1 downto 0);
        variable r : integer;
    begin
        k:= s'high - s'low;
        r:= s'high*4-1;
        for i in 0 to k loop
            for j in 0 to 15 loop
                if (s(i+1)=HEX_VALUE(j)) then
                    v((r-i*4) downto ((r-3)-i*4)):= std_logic_vector (to_signed(j,4));
                end if;
            end loop;
        end loop;
        return v;
    end x_read_f;

--------------------------------------------------------------------------------
-- assign dw field
--------------------------------------------------------------------------------
    function dw_assign (addr : std_logic_vector(1 downto 0); len : integer) return std_logic_vector is
        variable dw : std_logic_vector (7 downto 0);
        variable len_temp : integer;
        variable i : integer;
    begin
        i := 0;
        dw := "00000000";
        len_temp := len;
        -- assign first dw
        len_1dw: loop
            if i >= addr then
                dw(i) := '1';
                len_temp := len_temp - 1;
            end if;
            if i = 3 or len_temp = 0 then
                i := i + 1;
                exit len_1dw;
            end if;
            i := i + 1;
        end loop;
        while len_temp > 4 loop
            len_temp := len_temp - 4;
        end loop;
        -- assign last dw
        len_2dw : loop
            if len_temp /= 0 then dw(i) := '1'; end if;
            if i = 7 or len_temp = 0 then
                exit len_2dw;
            end if;
            len_temp := len_temp - 1;
            i := i + 1;
        end loop;
        return dw;
    end dw_assign;

--------------------------------------------------------------------------------
-- write tlp header
--------------------------------------------------------------------------------
    procedure header_f (signal clk : in std_logic;
                        constant addr : in std_logic_vector(31 downto 0);
                        constant fmt : in std_logic_vector (6 downto 0);
                        constant len : in integer;
                        signal tlp_in : in t_tx_tlp_intf_q;
                        signal tlp_out : out t_tx_tlp_intf_d) is
    begin
        -- set request signal
        tlp_out.tx_data_vc0 <= (others => '0');
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_end_vc0 <= '0';
        wait until clk = '1';
        tlp_out.tx_req_vc0 <= '1';
        -- wait for ready to send
        wait until tlp_in.tx_rdy_vc0 = '1';
        wait until clk = '1';
        tlp_out.tx_req_vc0 <= '0';
        -- set start and send packet format
        wait until clk = '1';
        tlp_out.tx_st_vc0 <= '1';
        tlp_out.tx_data_vc0(15) <= '0';
        tlp_out.tx_data_vc0(14 downto 8) <= fmt;
        tlp_out.tx_data_vc0(7 downto 0) <= (others => '0');
        wait until clk = '1';
        -- send length of packet
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_req_vc0 <= '0';
        if len >= 4 then tlp_out.tx_data_vc0(9 downto 0) <=  std_logic_vector (to_signed(((len-1)/4)+1,10)) ; end if;
        if len < 4 then
            tlp_out.tx_data_vc0(9 downto 0) <= len_calc(addr(1 downto 0), (std_logic_vector(to_signed(len,7))));
        end if;
        tlp_out.tx_data_vc0(15 downto 10) <= (others => '0');
        wait until clk = '1';
        -- send requester id
        tlp_out.tx_data_vc0 <= (others => '0');
        wait until clk = '1';
        -- send tag and FirstDW/LastDW
        tlp_out.tx_data_vc0(15 downto 8) <= X"54"; --(others => '0');
        tlp_out.tx_data_vc0(7 downto 0) <= dw_assign (addr(1 downto 0), len);
        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
        wait until clk = '1';
        -- send address
        tlp_out.tx_data_vc0(15 downto 0) <= addr (31 downto 16);
        wait until clk = '1';
        tlp_out.tx_data_vc0(15 downto 0) <= addr(15 downto 2) & "00";
        if fmt = RX_MEM_RD_FMT_TYPE or fmt = RX_CFG_RD_FMT_TYPE then
            tlp_out.tx_end_vc0 <= '1';
        end if;
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '0';
    end header_f;

    procedure header_cpl (signal clk : in std_logic;
                          constant addr : in std_logic_vector (31 downto 0);
                          constant len : in integer;
                          constant req_id : std_logic_vector (15 downto 0);
                          constant dw : std_logic_vector (7 downto 0);
                          constant tag : std_logic_vector (7 downto 0);
                          signal tlp_in : in t_tx_tlp_intf_q;
                          signal tlp_out : out t_tx_tlp_intf_d) is
    begin
        -- set request signal
        tlp_out.tx_data_vc0 <= (others => '0');
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_end_vc0 <= '0';
        wait until clk = '1';
        tlp_out.tx_req_vc0 <= '1';
        -- wait for ready to send
        wait until tlp_in.tx_rdy_vc0 = '1';
        tlp_out.tx_req_vc0 <= '0';
        -- set start and send packet format
        tlp_out.tx_st_vc0 <= '1';
        tlp_out.tx_data_vc0(15) <= '0';
        tlp_out.tx_data_vc0(14 downto 8) <= RX_CPLD_FMT_TYPE;
        tlp_out.tx_data_vc0(7 downto 0) <= (others => '0');
        wait until clk = '1';
        -- send length of packet
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_req_vc0 <= '0';
        tlp_out.tx_data_vc0(9 downto 0) <=  std_logic_vector (to_signed(len,10));
        tlp_out.tx_data_vc0(15 downto 10) <= (others => '0');
        wait until clk = '1';
        -- send completer id
        tlp_out.tx_data_vc0 <= (others => '0');
        wait until clk = '1';
        -- send Cmpl Stauts and Byte count
        tlp_out.tx_data_vc0(15 downto 13) <= (others => '0');
--      tlp_out.tx_data_vc0(15 downto 13) <= "100";
            case dw is
                when "00001111" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"04";
                when "00000111" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"03";
                when "00001110" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"03";
                when "00000011" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"02";
                when "00000110" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"02";
                when "00001100" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"02";
                when "00000001" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"01";
                when "00000010" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"01";
                when "00000100" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"01";
                when "00001000" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"01";
                when "00000000" => tlp_out.tx_data_vc0(10 downto 0) <= "000" & X"01";
                when "11111111" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11));
                when "01111111" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 1;
                when "00111111" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 2;
                when "00011111" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 3;
                when "11111110" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 1;
                when "01111110" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 2;
                when "00111110" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 3;
                when "00011110" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 4;
                when "11111100" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 2;
                when "01111100" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 3;
                when "00111100" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 4;
                when "00011100" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 5;
                when "11111000" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 3;
                when "01111000" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 4;
                when "00111000" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 5;
                when "00011000" => tlp_out.tx_data_vc0(10 downto 0) <= std_logic_vector(to_signed(len *4,11)) - 6;
                when others =>  tlp_out.tx_data_vc0(10 downto 0) <= (others => '0');
            end case;
        wait until clk = '1';
        -- send req_id
        tlp_out.tx_data_vc0(15 downto 0) <= req_id;
        wait until clk = '1';
        tlp_out.tx_data_vc0(15 downto 8) <= tag;
            if dw(3 downto 0) = "1111" or dw(3 downto 0) = "0111" or
               dw(3 downto 0) = "0011" or dw(3 downto 0) = "0001" then
                 tlp_out.tx_data_vc0(6 downto 0) <= (addr(6 downto 0));
            end if;
            if dw(3 downto 0) = "1110" or dw(3 downto 0) = "0110" or
               dw(3 downto 0) = "0010" then
                 tlp_out.tx_data_vc0(6 downto 0) <= (addr(6 downto 0)) + 1;
             end if;
             if dw(3 downto 0) = "1100" or dw(3 downto 0) = "0100" then
                 tlp_out.tx_data_vc0(6 downto 0) <= (addr(6 downto 0)) + 2;
             end if;
             if dw(3 downto 0) = "1000" then
                 tlp_out.tx_data_vc0(6 downto 0) <= (addr(6 downto 0)) + 3;
             end if;
--      tlp_out.tx_end_vc0 <= '1';
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '0';
    end header_cpl;


--------------------------------------------------------------------------------
-- write payload
--------------------------------------------------------------------------------

    procedure payload_f (signal clk : in std_logic;
                         constant payload : in payload_t;
                         signal tlp_out : out t_tx_tlp_intf_d
                        ) is
    begin
        tlp_out.tx_data_vc0(15 downto 8) <= payload(0);
        tlp_out.tx_data_vc0(7 downto 0) <= payload(1);
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '1';
        tlp_out.tx_data_vc0(15 downto 8) <= payload(2);
        tlp_out.tx_data_vc0(7 downto 0) <= payload(3);
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '0';
    end payload_f;

--------------------------------------------------------------------------------
-- write burst payload
--------------------------------------------------------------------------------

    procedure payload_brst_f (signal clk : in std_logic;
                         constant payload : in payload_t;
                         constant len : in integer;
                         signal tlp_out : out t_tx_tlp_intf_d
                        ) is
        variable counter : integer := 0;
    begin
        counter := 0;
        while counter /= len loop
            tlp_out.tx_data_vc0(15 downto 8) <= payload(counter + 0);
            tlp_out.tx_data_vc0(7 downto 0) <= payload(counter + 1);
            wait until clk = '1';
            if counter = len - 4 then
                tlp_out.tx_end_vc0 <= '1';
            end if;
            tlp_out.tx_data_vc0(15 downto 8) <= payload(counter + 2);
            tlp_out.tx_data_vc0(7 downto 0) <= payload(counter + 3);
            wait until clk = '1';
            counter := counter + 4;
        end loop;
        tlp_out.tx_end_vc0 <= '0';

    end payload_brst_f;

--------------------------------------------------------------------------------
-- write frame handler packet
--------------------------------------------------------------------------------
    procedure fh_write (signal clk : in std_logic;
                        constant payload : in payload_t;
                        constant len : in integer;
                        constant modul_num : in integer;
                        signal tx_ready : in std_logic_vector (MODUL_NUM_CONST - 1 downto 0);
                        signal tx_valid : out std_logic_vector (MODUL_NUM_CONST - 1 downto 0);
                        signal tx_data : out std_logic_vector (7 downto 0);
                        signal tx_last : out std_logic_vector (MODUL_NUM_CONST - 1 downto 0)
                        )is
        variable counter : integer := 0;
    begin
        wait until clk = '1';
        tx_valid <= (others => '0');
        tx_last <= (others => '0');
        tx_data <= (others => '0');
        if tx_ready(modul_num) = '0' then
            wait until tx_ready(modul_num) = '1';
        end if;
        wait until clk = '1';
        send: loop
            tx_valid(modul_num) <= '1';
            tx_data <= payload(counter);
            if counter = len-1 then
                tx_last(modul_num) <= '1';
                wait until clk = '1';
                tx_last(modul_num) <= '0';
                tx_valid(modul_num) <= '0';
                exit send;
            end if;
            if tx_ready(modul_num) = '1' then
                wait until clk = '1';
                counter := counter + 1;
            end if;
        end loop;
    end fh_write;

--------------------------------------------------------------------------------
-- ptm handle
--------------------------------------------------------------------------------
procedure ptm_handle (signal clk : in std_logic;
                        signal ptm_timer    : in std_logic_vector (63 downto 0);
                        signal requests : in t_read_mem;
                        signal tlp_in : in t_tx_tlp_intf_q;
                        signal tlp_out : out t_tx_tlp_intf_d) is
        begin
        -- set request signal
        tlp_out.tx_data_vc0 <= (others => '0');
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_end_vc0 <= '0';
        wait until clk = '1';
        tlp_out.tx_req_vc0 <= '1';
        -- wait for ready to send
        wait until tlp_in.tx_rdy_vc0 = '1';
        tlp_out.tx_req_vc0 <= '0';
        -- set start and send packet format
        tlp_out.tx_st_vc0 <= '1';
        tlp_out.tx_data_vc0(15) <= '0';
        tlp_out.tx_data_vc0(14 downto 8) <= TX_MSG_RQ_FMT_TYPE;
        tlp_out.tx_data_vc0(7 downto 0) <= (others => '0');
        wait until clk = '1';
        -- send length of packet
        tlp_out.tx_st_vc0 <= '0';
        tlp_out.tx_req_vc0 <= '0';
        tlp_out.tx_data_vc0(15 downto 0) <= (others => '0');
        wait until clk = '1';
        -- send completer id
        tlp_out.tx_data_vc0 <= requests.requester_id;
        wait until clk = '1';
        tlp_out.tx_data_vc0(15 downto 0) <= X"00" & X"53";
        wait until clk = '1';
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '1';
        wait until clk = '1';
        tlp_out.tx_end_vc0 <= '0';

    end ptm_handle;

--------------------------------------------------------------------------------
-- stim file read
--------------------------------------------------------------------------------

    procedure stim_file_read (
        constant stim_file  : in string;
        signal ptm_time     : in std_logic_vector (63 downto 0);
        signal clk          : in std_logic;
        signal clk_100      : in std_logic;
        signal tlp_in       : in t_tx_tlp_intf_q;
        signal np_req_pend  : in std_logic;
        signal tlp_out      : out t_tx_tlp_intf_d;
        signal tx_ready : in std_logic_vector (31 downto 0);
        signal tx_valid : out std_logic_vector (31 downto 0);
        signal tx_data : out std_logic_vector (7 downto 0);
        signal tx_last : out std_logic_vector (31 downto 0);
        signal tx_evt_req   : out std_logic_vector (31 downto 0);
        signal tx_evt_idx   : out t_tx_evt_idx;
        signal tx_evt_rdy   : in std_logic_vector (31 downto 0);
        signal requests     : in t_read_mem;
        signal comment  : out string
    ) is
        file pcie_stim_file : text open READ_MODE is stim_file;
        variable l : line;
        variable c : character;
        variable s_32 : string(1 to 8);
        variable s_16 : string(1 to 4);
        variable s_8 : string(1 to 2);
        variable command : string (1 to 4);
        variable len    : integer;
        variable payload : payload_t;
        variable addr_v : std_logic_vector (31 downto 0);
        variable addr_s : std_logic_vector (31 downto 0);
        variable modul_sel                  : integer;
        variable wait_loop : integer := 0;
        variable payload_send : payload_t;
        variable interrupt_send : interrupt_num_t := (others => X"00");
        variable exit_wait_loop : boolean := true;
    begin
        main_loop : loop

            if requests.ena = true then
                -- creating payload
                for i in 0 to to_integer(unsigned(requests.length))*4 loop
                    payload(i) := std_logic_vector(to_unsigned(i + 1,8));
                end loop;
                -- sending completion header with data
                if (requests.tlp_type /= TX_MSG_RQ_FMT_TYPE) then
                    header_cpl (clk, requests.address, to_integer(unsigned(requests.length)), requests.requester_id, requests.dw, requests.tag, tlp_in, tlp_out);
                    case requests.address(15 downto 8) is
                    when GET_MODULE_TABLE_ADDRESS(0) =>
                        payload_send := GET_MODULE_TABLE_ADDRESS;
                        payload_send(5) := interrupt_send(to_integer(unsigned(requests.tag(4 downto 0))));
                        payload_brst_f (clk, payload_send, to_integer(unsigned(requests.length))*4, tlp_out);
                    when GET_MODUL_ID_PLD(0) =>
                        payload_brst_f (clk, GET_MODUL_ID_PLD, to_integer(unsigned(requests.length))*4, tlp_out);
                    when NONVOL_GET_DATA(0) =>
                        payload_send := NONVOL_GET_DATA;
                        payload_send(11) := interrupt_send(to_integer(unsigned(requests.tag(4 downto 0))));
                        payload_brst_f (clk, payload_send, to_integer(unsigned(requests.length))*4, tlp_out);
                    when SET_DATA_2(0) =>
                        payload_brst_f (clk, SET_DATA_2, to_integer(unsigned(requests.length))*4, tlp_out);
                    when GET_DATA_2(0) =>
                        payload_send := GET_DATA_2;
                        payload_send(6) := interrupt_send(to_integer(unsigned(requests.tag(4 downto 0))));
                        payload_brst_f (clk, GET_DATA_2, to_integer(unsigned(requests.length))*4, tlp_out);
                    when others =>
                        payload_brst_f (clk, payload, to_integer(unsigned(requests.length))*4, tlp_out);
                    end case;
                    if (interrupt_send(to_integer(unsigned(requests.tag(4 downto 0))))<7) then
                        interrupt_send(to_integer(unsigned(requests.tag(4 downto 0)))):= interrupt_send(to_integer(unsigned(requests.tag(4 downto 0))))+ 1;
                    else
                        interrupt_send(to_integer(unsigned(requests.tag(4 downto 0)))):= X"00";
                    end if;
                    wait until clk = '1';
                    next;
                -- sending ptm data
            elsif (requests.tlp_type = TX_MSG_RQ_FMT_TYPE) then
                    report "sending ptm packet";
                    ptm_handle(clk,ptm_time, requests, tlp_in, tlp_out);
                end if;
            end if;

            if wait_loop = 0 and exit_wait_loop = true then
                if endfile(pcie_stim_file) then wait for 1 ns; next; end if;
                readline (pcie_stim_file, l);
                if l.all(1) = ';' then
                    --comment <= ("                                                            ");
                    --comment(1 to l'length) <= l.all;
                    report l.all;
                    next;
                end if;
                read (l, command);

                if command = "exit" then
                    report "exit command";
                    wait for 10 us;
                    --std.env.stop(0);
                    --next;
                    exit_wait_loop := false;
                    exit main_loop;
                else
                    read (l,c);
                end if;

                read (l,s_32); read (l, c);
                addr_s := x_read_f(s_32);
                addr_v := x_read_f(s_32);
                modul_sel := to_integer(unsigned(x_read_f(s_32)));
                len := 0;
                read_line: loop
                    if c = ';' then
                        exit read_line;
                    end if;
                    c := nul;
                    case command is
                        when "d_cf" =>
                            header_f (clk, addr_v, RX_CFG_RD_FMT_TYPE, 4, tlp_in, tlp_out);
                            exit read_line;
                        when "d_cb" =>
                            header_f (clk,addr_v,RX_CFG_RD_FMT_TYPE,1,tlp_in,tlp_out);
                            exit read_line;
                        when "m_cf" =>
                            read(l,s_32); read (l,c);
                            payload(3) := x_read_f(s_32)(31 downto 24);
                            payload(2) := x_read_f(s_32)(23 downto 16);
                            payload(1) := x_read_f(s_32)(15 downto 8);
                            payload(0) := x_read_f(s_32)(7 downto 0);
                            header_f (clk, addr_v, RX_CFG_WR_FMT_TYPE, 4, tlp_in, tlp_out);
                            payload_f (clk, payload, tlp_out);
                            addr_v := addr_v + 4;
                        when "m_32" =>
                            read(l,s_32); read (l,c);
                            payload(3) := x_read_f(s_32)(31 downto 24);
                            payload(2) := x_read_f(s_32)(23 downto 16);
                            payload(1) := x_read_f(s_32)(15 downto 8);
                            payload(0) := x_read_f(s_32)(7 downto 0);
                            header_f (clk, addr_v, RX_MEM_WR_FMT_TYPE, 4, tlp_in, tlp_out);
                            payload_f (clk, payload, tlp_out);
                            addr_v := addr_v + 4;
                        when "m_16" =>
                            read(l,s_16); read (l,c);
                            if addr_v(1 downto 0) = "00" then
                                payload(3) := (others => '0');
                                payload(2) := (others => '0');
                                payload(1) := x_read_f(s_16)(15 downto 8);
                                payload(0) := x_read_f(s_16)(7 downto 0);
                            end if;
                            if addr_v (1 downto 0) = "10" then
                                payload(3) := x_read_f(s_16)(15 downto 8);
                                payload(2) := x_read_f(s_16)(7 downto 0);
                                payload(1) := (others => '0');
                                payload(0) := (others => '0');
                            end if;
                            header_f (clk, addr_v, RX_MEM_WR_FMT_TYPE, 2, tlp_in, tlp_out);
                            payload_f (clk, payload, tlp_out);
                            addr_v := addr_v + 2;
                        when "m__8" =>
                            read(l,s_8);
                            case addr_v(1 downto 0) is
                            when "00" =>
                                payload(3) := (others => '0');
                                payload(2) := (others => '0');
                                payload(1) := (others => '0');
                                payload(0) := x_read_f(s_8)(7 downto 0);
                            when "01" =>
                                payload(3) := (others => '0');
                                payload(2) := (others => '0');
                                payload(1) := x_read_f(s_8)(7 downto 0);
                                payload(0) := (others => '0');
                            when "10" =>
                                payload(3) := (others => '0');
                                payload(2) := x_read_f(s_8)(7 downto 0);
                                payload(1) := (others => '0');
                                payload(0) := (others => '0');
                            when "11" =>
                                payload(3) := x_read_f(s_8)(7 downto 0);
                                payload(2) := (others => '0');
                                payload(1) := (others => '0');
                                payload(0) := (others => '0');
                            when others =>
                            end case;
                            header_f (clk, addr_v, RX_MEM_WR_FMT_TYPE, 1, tlp_in, tlp_out);
                            payload_f (clk, payload, tlp_out);
                            addr_v := addr_v + 1;
                            read (l,c);
                        when "w_fh" =>
                            read(l,s_8); read(l,c);
                            payload(len) := x_read_f(s_8)(7 downto 0);
                            len := len + 1;
                        when "m_br" =>
                            read(l,s_32); read (l,c);
                            payload(len + 3) := x_read_f(s_32)(31 downto 24);
                            payload(len + 2) := x_read_f(s_32)(23 downto 16);
                            payload(len + 1) := x_read_f(s_32)(15 downto 8);
                            payload(len + 0) := x_read_f(s_32)(7 downto 0);
                            len := len + 4;
                        when "d_32" =>
                            read(l,s_8); read (l,c);
                            len := to_integer(unsigned(x_read_f(s_8)));
                            header_f (clk, addr_v, RX_MEM_RD_FMT_TYPE, len, tlp_in, tlp_out);
                        when "evnt" =>
                            read(l,s_8); read (l,c);
                            len := to_integer(unsigned(x_read_f(s_8)));

                        when "wait" =>
                            read(l,s_32); read (l,c);
                            len := to_integer(unsigned(x_read_f(s_32)));
                            wait_loop := len;
                            exit read_line;
                        when "exit" =>
                            report "exit command 1";
                            exit_wait_loop := false;
                            --exit main_loop;

                        when others =>
                            read (l,c);
                    end case;
                    wait until clk = '1';
                end loop;
            else
                wait_loop:= wait_loop - 1;
                wait until clk = '1';
            end if;

            if command = "m_br" then
                header_f (clk, addr_s, RX_MEM_WR_FMT_TYPE, len, tlp_in, tlp_out);
                payload_brst_f (clk, payload, len, tlp_out);
            end if;
            if command = "w_fh" then
                fh_write ( clk_100, payload, len, modul_sel, tx_ready, tx_valid, tx_data, tx_last);
            end if;
            if command = "evnt" then
                for i in 0 to 31 loop
                    tx_evt_idx(i) <= std_logic_vector(to_unsigned(len,2));
                end loop;
                tx_evt_req <= addr_v;
                wait until clk = '1';
                tx_evt_idx <= (others => (others => '0'));
                tx_evt_req <= (others => '0');
            end if;

            wait for 10 ns;
        end loop;
        file_close(pcie_stim_file);
        report "test file closed";
    end stim_file_read;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end package body;