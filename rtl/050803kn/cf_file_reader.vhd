--===========================================================================--
-- 
-- FAT16 FIRST FILE READER
--
--  - DECEMBER 2002
--  - UPV / EHU.  
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
-- File name      : cf_file_reader.vhd
--
-- Purpose        : 
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
-- 280103     Armando Astarloa     28 January	 FAT16 VERSION (FROM FAT32)
-- 300403     Armando Astarloa     28 January	 Data out 8 bits
-- 200503     Armando Astarloa     20 May	 		 Quit debug signals
-- 030603	  Armando Astarloa	  03 June		 Ack_comrx lasts only one period	
-- 240603	  Armando Astarloa	  24 	June		 Quit soft reset signals (with kcpsm 
--																	v.1002)
-------------------------------------------------------------------------------
-- Description    : Top VHDL file for FFR16
--                  
-------------------------------------------------------------------------------
-- Entity for cf_file_reader Unit 		                                   	  --
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library WORK;
use WORK.cf_package.ALL;

entity cf_file_reader is
    Port (

	 			--
				-- WISHBONE GLOBAL SIGNALS
				--
				RST_I:  in  std_logic;														-- WB : Global RESET signal
            CLK_I:  in  std_logic;		
		
	 			--
				-- NON WISHBONE SIGNALS (IDE SIGNALS) 
				--
				IDE_BUS: inout  std_logic_vector(15 downto 0 ); 					-- IDE DATA bidirectional bus

				NIOWR:  out  std_logic;														-- IDE : Write Strobe
				NIORD:  out  std_logic;														-- IDE : Read Strobe
			   NCE1:  out  std_logic;														-- IDE : CE1
				NCE0:  out  std_logic;														-- IDE : CE2
				A2:  out  std_logic;															-- IDE : Address bit 2
				A1:  out  std_logic;															-- IDE : Address bit 1
				A0:  out  std_logic;															-- IDE : Address bit 0
	
				ERROR:  out  std_logic;														-- Error on cf access

				--
				-- SLAVE INTERFACE
				--

	 			ACK_O:  out std_logic;														-- WB : Ack to the master
--          ADR_I:  in  std_logic_vector(1 downto 0 ); 							-- WB : Register selection
--          DAT_O:  out  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
		      DAT_O:  out  std_logic_vector(7 downto 0 ); 						-- WB : 16 bits data bus input
				STB_I:  in  std_logic;													-- WB : Access qualify from master
            WE_I:   in  std_logic;													-- WB : Read/write request from master
				TAG0_WORD_AVAILABLE_O:  out  std_logic;							
				TAG1_ERROR_O:  out  std_logic	

	 		);
end cf_file_reader;

architecture Behavioral of cf_file_reader is

-- ack_comrx active only one period
type ack_state is (ackone_wait, ackactive, ackzero_wait); 
signal act_ack : ack_state;
signal next_ack: ack_state;
signal ack_slave_int: std_logic;

--
-- INTERCONEXION SIGNALS
--
signal stb_internal : std_logic;
signal ack_internal : std_logic;
signal data_internal : std_logic_vector(15 downto 0 );
signal data_internal_reg : std_logic_vector(15 downto 0 );
signal we_internal : std_logic;	
signal adr_i_internal : std_logic;
signal error_internal : std_logic;	

signal tag0_word_available_internal : std_logic;
signal tag1_word_request_internal : std_logic;

-- for the 8 bit version only LSB is valid
signal data_out_full : std_logic_vector(15 downto 0 );
begin

-- ack_comrx active only one period
ack_control: process (rst_i, clk_i)
-- declarations
begin  
	if rst_i = '1' then
		act_ack <= ackone_wait;
  	elsif (clk_i'event and clk_i = '1') then
		act_ack <= next_ack;
	end if;
end process;

process(act_ack, ack_slave_int)
begin
		case act_ack is
			when ackone_wait =>
				if ack_slave_int ='1' then
					next_ack <= ackactive;
			 	else
					next_ack <= ackone_wait;
				end if;
			when ackactive =>
				next_ack <= ackzero_wait;
		  	when ackzero_wait =>
				if ack_slave_int = '0' then
					next_ack <= ackone_wait;
			  	else
					next_ack <= ackzero_wait;
			 	end if;
		 	when others =>
				next_ack <= ackone_wait;
	  	end case;
 end process;

with act_ack select
	ACK_O <= '1' when ackactive,
				'0' when others;


--
-- COMPONENT INSTANTATION
--
--
-- SECTOR READER
--
sector_reader:cf_sector_reader port map (
				--
				-- WISHBONE SIGNALS
				--
				RST_I => RST_I,
 				ACK_O => ack_internal,
				ADR_I =>	adr_i_internal,
            CLK_I => CLK_I,
            DAT_I_O => data_internal,
            STB_I => stb_internal,
	         WE_I => we_internal,
				TAG0_WORD_AVAILABLE => tag0_word_available_internal,				-- 
				TAG1_WORD_REQUEST => tag1_word_request_internal,					-- IDE : Write Strobe

				--
				-- NON WISHBONE SIGNALS
				--
				IDE_BUS => IDE_BUS,

				NIOWR => NIOWR,
				NIORD => NIORD,
			   NCE1 => NCE1,
  				NCE0 => NCE0,
				A2 => A2,
				A1 => A1,
				A0 => A0,
				ERROR => error_internal					
				);

--
-- FAT PROCESSOR
--
fat_processor:cf_fat16_reader port map (
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I => RST_I,
  				CLK_I => CLK_I,
				--
				-- MASTER INTERFACE
				--
	 			ACK_I_M => ack_internal,
            ADR_O_M => adr_i_internal,
            DAT_M => data_internal,
            STB_O_M => stb_internal,
	         WE_O_M => we_internal,
				TAG0_ERROR_I_M => error_internal,							
				--
				-- SLAVE INTERFACE
				--

	 			ACK_O_S => ack_slave_int,
				--          ADR_I:  in  std_logic_vector(1 downto 0 ); 			-- WB : Register selection
            DAT_O_S => data_out_full,
            STB_I_S => STB_I,
            WE_I_S => WE_I,
		  		TAG0_WORD_AVAILABLE_O_S => TAG0_WORD_AVAILABLE_O,
	 			TAG1_ERROR_O_S => TAG1_ERROR_O											-- Error on cf access																
				);
				
				--
				-- COMB. ASIGMENTS
				--
				ERROR <= error_internal;
				DAT_O <= data_out_full(7 downto 0);

end Behavioral;
