--===========================================================================--
-- 
-- CF SECTOR READER - HOST ATAPI UNIT (HAU)
--
--  - SEPTEMBER 2002
--  - UPV / EHU
--  
--  - APPLIED ELECTRONICS RESEARCH TEAM (APERT)-
--  DEPARTMENT OF ELECTRONICS AND TELECOMMUNICATIONS - BASQUE COUNTRY UNIVERSITY
--
-- THIS CODE IS DISTRIBUTED UNDER :
-- OpenIPCore Hardware General Public License "OHGPL" 
-- http://www.opencores.org/OIPC/OHGPL.shtml
--
-- Design units   : COMPACT FLASH TOOLS
--
-- File name      : cf_sector_reader.vhd
--
-- Purpose        : IDE interface and ATAPI p. managment
--                  
-- Library        : WORK
--
-- Dependencies   : IEEE.Std_Logic_1164
--
-- Simulator      : ModelSim SE version 5.5e on a WindowsXP PC
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date           Changes
--
-- 270902     Armando Astarloa     27 September			First VHDL synthesizable code
-- 070103	  Armando Astarloa	  07 January			Included address 0 for wb bus
-- 090103	  Armando Astarloa	  09 January			Included wb_in_bus inputs 
--																			Changed DAT_O to DAT_I_O (inout)
-- 200103	  Armando Astarloa	  20 January			Changed triestate control of the WB bus 
-- 280503	  Armando Astarloa	  28 May					KCPSM V.1002 - with reset
-- 240603	  Armando Astarloa	  24 June				Quit soft reset signals (with kcpsm 
--																		v.1002)
-------------------------------------------------------------------------------
-- Description    : This module is an "active" IDE interface for sector
-- reading. Through the WB interface the LBA of the desired sector is written and
-- the module reads it from the IDE device following the ATAPI procol. The sector
-- data are given through doing consecutive requests.
-- NOTE : The WB interface of this module is not full Wishbone compatible due to
-- the "soft" proc. of the signals. If the designer wants to use it independently
-- an state machine for the ack signal should be added as the one added in 
-- "cf_file_reader.vhd"                 
-------------------------------------------------------------------------------
-- Entity for cf_sector_reader Unit 		                                   	  --
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cf_sector_reader is
    Port ( 
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I:  in  std_logic;														-- WB : Global RESET signal
	 			ACK_O:  out std_logic;														-- WB : Ack to the master
				ADR_I:  in  std_logic; 														-- WB : Register selection
	        	CLK_I:  in  std_logic;														-- WB : Global bus clock
          	DAT_I_O:  inout  std_logic_vector(15 downto 0 ); 					-- WB : 16 bits data bus input
          	STB_I:  in  std_logic;														-- WB : Access qualify from master
          	WE_I:   in  std_logic;														-- WB : Read/write request from master
				TAG0_WORD_AVAILABLE:  out  std_logic;									-- 
				TAG1_WORD_REQUEST:  in  std_logic;										-- IDE : Write Strobe

				--
				-- NON WISHBONE SIGNALS
				--
				IDE_BUS: inout  std_logic_vector(15 downto 0 ); 					-- IDE DATA bidirectional bus

				NIOWR:  out  std_logic;														-- IDE : Write Strobe
				NIORD:  out  std_logic;														-- IDE : Read Strobe
			   NCE1:  out  std_logic;														-- IDE : CE1
				NCE0:  out  std_logic;														-- IDE : CE2
				A2:  out  std_logic;															-- IDE : Address bit 2
				A1:  out  std_logic;															-- IDE : Address bit 1
				A0:  out  std_logic;															-- IDE : Address bit 0
	
				ERROR:  out  std_logic														-- Error on cf access

				);
end cf_sector_reader;

architecture Behavioral of cf_sector_reader is
--
-- COMPONENT : KCPSM MICRO PICOBLAZE
--
component kcpsm is 
		Port (
					  address:	out std_logic_vector(7 downto 0);
	         instruction : in std_logic_vector(15 downto 0);
	             port_id : out std_logic_vector(7 downto 0);
	        write_strobe : out std_logic;
	            out_port : out std_logic_vector(7 downto 0);
	         read_strobe : out std_logic;
	             in_port : in std_logic_vector(7 downto 0);
	           interrupt : in std_logic;
	               reset : in std_logic;
	                 clk : in std_logic
				);
end component;

--
-- COMPONENT :FIRMWARE ROM
--
component cfreader is
    Port (
				instruction: out std_logic_vector(15 downto 0);
				address: in std_logic_vector(7 downto 0);
				clk: in std_logic
			);
	
end component;
--
-- MODULE INTERCONNECTION SIGNALS
--
signal ADDRESS_BUS : std_logic_vector(7 downto 0);						-- FIRMWARE ROM ADDRESSES BUS
signal INSTRUCTIONS_BUS : std_logic_vector(15 downto 0);				-- INSTRUCTIONS BUS
signal INPUTS_BUS : std_logic_vector(7 downto 0);						-- INPUTS BUS
signal OUTPUTS_BUS : std_logic_vector(7 downto 0);						-- OUTPUTS BUS
signal PORTS_ID : std_logic_vector(7 downto 0);							-- PORTS ID
signal READ_STROBE : std_logic;
signal WRITE_STROBE : std_logic;
signal INTERRUPT : std_logic;

--
-- INTERNAL REGISTERS
--


signal DATA_IDE_OUT_7_0: std_logic_vector(7 downto 0);				-- IDE DATA OUTPUT BUS
signal DATA_IDE_OUT_15_8: std_logic_vector(7 downto 0);				-- IDE DATA OUTPUT BUS
signal IDE_CONTROL_OUT: std_logic_vector(1 downto 0);					-- IDE BUS CONTROL SIGNALS
signal IDE_ADDRESS_OUT: std_logic_vector(4 downto 0);					-- IDE ADDRESS SIGNALS
signal DATA_WB_OUT_7_0: std_logic_vector(7 downto 0);					-- WISHBONE DATA OUTPUT BUS
signal DATA_WB_OUT_15_8: std_logic_vector(7 downto 0);				-- WISHBONE DATA OUTPUT BUS 
signal CONTROL_WB_OUT: std_logic_vector(1 downto 0);					-- WISHBONE CONTROL SIGNALS
signal CONTROL_OUT: std_logic_vector(2 downto 0);						-- GENERAL CONTROL SIGNALS
signal DATA_IDE_IN_7_0: std_logic_vector(7 downto 0);					-- IDE DATA OUTPUT BUS										
signal DATA_IDE_IN_15_8: std_logic_vector(7 downto 0);				-- IDE DATA OUTPUT BUS
signal CONTROL_WB_IN:std_logic_vector(4 downto 0);						-- WISHBONE CONTROL INPUT SIGNALS
signal DATA_WB_IN_7_0: std_logic_vector(7 downto 0);					-- WISHBONE DATA INPUT BUS
signal DATA_WB_IN_15_8: std_logic_vector(7 downto 0);					-- WISHBONE DATA INPUT BUS 

--
-- CLOCK ENABLE FOR THE REGISTERS
--
signal DATA_IDE_OUT_7_0_CE : std_logic;
signal DATA_IDE_OUT_15_8_CE : std_logic;
signal IDE_CONTROL_OUT_CE : std_logic; 
signal IDE_ADDRESS_OUT_CE : std_logic; 
signal DATA_WB_OUT_7_0_CE : std_logic; 
signal DATA_WB_OUT_15_8_CE : std_logic;
signal CONTROL_WB_OUT_CE : std_logic; 
signal CONTROL_OUT_CE : std_logic; 
signal DATA_IDE_IN_7_0_CE : std_logic;										
signal DATA_IDE_IN_15_8_CE : std_logic;
signal CONTROL_WB_IN_CE : std_logic; 
signal DATA_WB_IN_7_0_CE : std_logic; 
signal DATA_WB_IN_15_8_CE : std_logic;			
			
--
-- INTERNAL SIGNALS
--
signal IDE_BUS_WRITE_ENABLE : std_logic;
signal WB_BUS_WRITE_ENABLE : std_logic;


begin

--
-- COMPONENTS INSTANTATION
--

--
-- KCPSM INSTANTATION
--
micro:kcpsm port map (
				address => ADDRESS_BUS,
				instruction => INSTRUCTIONS_BUS,
				port_id => PORTS_ID,
				write_strobe => WRITE_STROBE,
				out_port => OUTPUTS_BUS,
				read_strobe => READ_STROBE,
				in_port => INPUTS_BUS,
				interrupt => INTERRUPT,
				reset => RST_I,
				clk => CLK_I);
--
-- FIRMWARE ROM INSTANTATION
--
rom:cfreader port map (
				instruction => INSTRUCTIONS_BUS,
				address => ADDRESS_BUS,
				clk => CLK_I);

--
-- BUSES CONTROL
--
	DAT_I_O <= (DATA_WB_OUT_15_8 & DATA_WB_OUT_7_0) when WB_BUS_WRITE_ENABLE = '1' else (others => 'Z');
	DATA_WB_IN_15_8 <= DAT_I_O(15 downto 8);
  DATA_WB_IN_7_0 <= DAT_I_O(7 downto 0);
																			-- WISHBONE BUS COMPOSITION

	DATA_IDE_IN_15_8 <= IDE_BUS(15 downto 8);					-- IDE INPUT BUS
	DATA_IDE_IN_7_0 <= IDE_BUS(7 downto 0);
	IDE_BUS <= (DATA_IDE_OUT_15_8 & DATA_IDE_OUT_7_0) 
		when IDE_BUS_WRITE_ENABLE='1' else (others =>'Z');	-- WRITING INTO IDE BIDIR BUS



--
-- SIGNALS CONNECTIONS
--
   interrupt <= '0';
 	NIOWR <= IDE_CONTROL_OUT(1);
	NIORD <= IDE_CONTROL_OUT(0);

 	NCE1 <= IDE_ADDRESS_OUT(4);
	NCE0 <= IDE_ADDRESS_OUT(3);
	A2 <= IDE_ADDRESS_OUT(2);
	A1 <= IDE_ADDRESS_OUT(1);
	A0 <= IDE_ADDRESS_OUT(0);

 	TAG0_WORD_AVAILABLE <= CONTROL_WB_OUT(1);
	ACK_O <= CONTROL_WB_OUT(0);

 	ERROR <= CONTROL_OUT(2);
	WB_BUS_WRITE_ENABLE <= CONTROL_OUT(1);
	IDE_BUS_WRITE_ENABLE <= CONTROL_OUT(0);					--	EXTRACT WRITE ENABLE SIGNAL FROM THE PORT

		-- INPUTS
 	CONTROL_WB_IN (4) <= ADR_I;
 	CONTROL_WB_IN (2) <= WE_I;
 	CONTROL_WB_IN (1) <= TAG1_WORD_REQUEST;	
 	CONTROL_WB_IN (0) <= STB_I;

--
-- INPUT PORTS DECODING
--
-- KCPSM DATASHEET NOTE: 
-- The user interface logic is required to decode the port address value 
-- and supply the correct data. Note that the Read_Strobe provides an 
-- indicator that a port has been read, but in not vital to qualify a valid address.
--
process (CLK_I, RST_I)
begin
	 			--
				-- INPUT PORTS RESET STATE
				--
	if RST_I='1' then

				INPUTS_BUS <= (others => '0'); 	-- WISHBONE CONTROL INPUT SIGNALS
				--
				-- SYNCRONOUS INPUT SIGNALS SAMPLE
				--
	elsif (CLK_I='1' and CLK_I'event) then
				if CONTROL_WB_IN_CE='1' then
					INPUTS_BUS(7 downto 4) <= (others => '0');
					INPUTS_BUS(4 downto 0) <= CONTROL_WB_IN;
				elsif DATA_IDE_IN_7_0_CE='1' THEN
					INPUTS_BUS <= DATA_IDE_IN_7_0;
				elsif DATA_IDE_IN_15_8_CE='1' THEN
					INPUTS_BUS <= DATA_IDE_IN_15_8;
				elsif DATA_WB_IN_7_0_CE='1' THEN
					INPUTS_BUS <= DATA_WB_IN_7_0;
				elsif DATA_WB_IN_15_8_CE='1' THEN
					INPUTS_BUS <= DATA_WB_IN_15_8;
				end if;

	end if;
end process;

--
-- OUTPUT PORTS DECODING
--
-- KCPSM DATASHEET NOTE: The user interface logic is required to decode the port 
-- address value and enable the correct logic to capture the data value. The
---Write_Strobe must be used in this case ensure the transfer of valid data only.
--
--
process (CLK_I, RST_I)
begin
	 			--
				-- OUTPUT PORTS RESET STATE
				--
	if	RST_I = '1' then
--				NIOWR <= '1'; 
--				NIORD <= '1';
--			   NCE1 <= '1';
--				NCE0 <= '1';
--				A2 <= '0';
--				A1 <= '0';
--				A0 <= '0';
			DATA_IDE_OUT_7_0 <= (others => 'Z');
			DATA_IDE_OUT_15_8 <= (others => 'Z');
			IDE_CONTROL_OUT <= (others => 'Z');
			IDE_ADDRESS_OUT <= (others => 'Z');
			DATA_WB_OUT_7_0 <= (others => 'Z');
			DATA_WB_OUT_15_8 <= (others => 'Z');
			CONTROL_WB_OUT <= (others => 'Z');
			CONTROL_OUT <=(others => 'Z');
	
				--
				-- SYNC LOAD
				--
	elsif (CLK_I='1' and CLK_I'event) then
		if DATA_IDE_OUT_7_0_CE='1' then
			DATA_IDE_OUT_7_0 <= OUTPUTS_BUS;
	  	elsif DATA_IDE_OUT_15_8_CE='1' then
			DATA_IDE_OUT_15_8 <= OUTPUTS_BUS;
	  	elsif IDE_CONTROL_OUT_CE='1' then
			IDE_CONTROL_OUT <= OUTPUTS_BUS(1 downto 0);
	  	elsif IDE_ADDRESS_OUT_CE='1' then
			IDE_ADDRESS_OUT <= OUTPUTS_BUS(4 downto 0);
	  	elsif DATA_WB_OUT_7_0_CE='1' then
			DATA_WB_OUT_7_0 <= OUTPUTS_BUS;
	  	elsif DATA_WB_OUT_15_8_CE='1' then
			DATA_WB_OUT_15_8 <= OUTPUTS_BUS;
	  	elsif CONTROL_WB_OUT_CE='1' then
			CONTROL_WB_OUT <= OUTPUTS_BUS(1 downto 0);
	  	elsif CONTROL_OUT_CE='1' then
			CONTROL_OUT <= OUTPUTS_BUS(2 downto 0);
		else
			null;
		end if;
	end if;
end process;
--
-- CLOCK ENABLE GENERATION (COMBINATIONAL => STUDY SYNC. IMPROVEMENTS)
--
--
-- OUTPUTS
--
process (WRITE_STROBE,PORTS_ID)
begin
	if WRITE_STROBE = '1' then
		case PORTS_ID is
			when "00000000" =>
				DATA_IDE_OUT_7_0_CE <= '1';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000001" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '1';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000010" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '1'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000011" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '1'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000100" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '1'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000101" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '1';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
			when "00000110" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '1'; 
				CONTROL_OUT_CE <= '0'; 
		 	when "00000111" =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '1'; 
		 	when others =>
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
		end case;
	else
				DATA_IDE_OUT_7_0_CE <= '0';
				DATA_IDE_OUT_15_8_CE <= '0';
				IDE_CONTROL_OUT_CE <= '0'; 
				IDE_ADDRESS_OUT_CE <= '0'; 
				DATA_WB_OUT_7_0_CE <= '0'; 
				DATA_WB_OUT_15_8_CE <= '0';
				CONTROL_WB_OUT_CE <= '0'; 
				CONTROL_OUT_CE <= '0'; 
	end if;
end process;
--
-- INPUTS
--
process (PORTS_ID)
begin
	case PORTS_ID is
		when "00000000" =>
			DATA_IDE_IN_7_0_CE <= '1';
			DATA_IDE_IN_15_8_CE <= '0';
			CONTROL_WB_IN_CE <= '0';
			DATA_WB_IN_7_0_CE <= '0'; 
			DATA_WB_IN_15_8_CE <= '0';			

	  	when "00000001" =>
			DATA_IDE_IN_7_0_CE <= '0';
			DATA_IDE_IN_15_8_CE <= '1';
			CONTROL_WB_IN_CE <= '0';
			DATA_WB_IN_7_0_CE <= '0'; 
			DATA_WB_IN_15_8_CE <= '0';			

	 	when "00000010" =>
			DATA_IDE_IN_7_0_CE <= '0';
			DATA_IDE_IN_15_8_CE <= '0';
			CONTROL_WB_IN_CE <= '1';
			DATA_WB_IN_7_0_CE <= '0'; 
			DATA_WB_IN_15_8_CE <= '0';			

	 	when "00000011" =>
			DATA_IDE_IN_7_0_CE <= '0';
			DATA_IDE_IN_15_8_CE <= '0';
			CONTROL_WB_IN_CE <= '0';
			DATA_WB_IN_7_0_CE <= '1'; 
			DATA_WB_IN_15_8_CE <= '0';			


	 	when "00000100" =>
			DATA_IDE_IN_7_0_CE <= '0';
			DATA_IDE_IN_15_8_CE <= '0';
			CONTROL_WB_IN_CE <= '0';
			DATA_WB_IN_7_0_CE <= '0'; 
			DATA_WB_IN_15_8_CE <= '1';			



	 	when others =>
			DATA_IDE_IN_7_0_CE <= '0';
			DATA_IDE_IN_15_8_CE <= '0';
			CONTROL_WB_IN_CE <= '0';
			DATA_WB_IN_7_0_CE <= '0'; 
			DATA_WB_IN_15_8_CE <= '0';			
	end case;

end process;

end Behavioral;
