--===========================================================================--
-- 
-- COMPACT FLASH MODULES PACKAGE
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
-- File name      : cf_package.vhd
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
-- 031202     Armando Astarloa     03 December	 		First release
-- 070103	  Armando Astarloa	  07	January			Added cf_emulator component
--																				 procedure write_to_controller
--																				 function read_from_controller			
--																				 Included address 0 for wb bus
-- 090103		Armando Astarloa	  07	January			Changes DAT_O to DAT_I_O in 
--																		cf_sector_reader
-- 100103		Armando Astarloa	  10	January			Bug in fuction read from controller
-- 140103		Armando Astarloa	  14	January			Added read_from_the_fat32 procedure
-- 240603	  	Armando Astarloa	  24 	June		 		Quit soft reset signals (with kcpsm 
--																		v.1002)
--
-------------------------------------------------------------------------------
-- Description    : 
--                  
-------------------------------------------------------------------------------
-- Entity for cf_package Unit 		                                   	  --
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package cf_package is

component cf_fat32_reader is
    Port ( 
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I:  in  std_logic;														-- WB : Global RESET signal
        		CLK_I:  in  std_logic;														-- WB : Global bus clock

				--
				-- MASTER INTERFACE
				--
	 			ACK_I_M:  in std_logic;														-- WB : Ack from the slave
            ADR_O_M:  out  std_logic; 													-- WB : Register selection
            DAT_M:  inout  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
            STB_O_M:  out std_logic;													-- WB : Access request to the slave
            WE_O_M:   out  std_logic;													-- WB : Read/write request to the slave
				TAG0_ERROR_I_M: in  std_logic;							
				--
				-- SLAVE INTERFACE
				--

	 			ACK_O_S:  out std_logic;														-- WB : Ack to the master
--          ADR_I:  in  std_logic_vector(1 downto 0 ); 							-- WB : Register selection
            DAT_O_S:  out  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
            STB_I_S:  in  std_logic;													-- WB : Access qualify from master
            WE_I_S:   in  std_logic;													-- WB : Read/write request from master
				TAG0_WORD_AVAILABLE_O_S:  out  std_logic;							
				TAG1_ERROR_O_S:  out  std_logic											-- Error on cf access

																																				
				);
end component;
component cf_fat16_reader is
    Port ( 
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I:  in  std_logic;														-- WB : Global RESET signal
        		CLK_I:  in  std_logic;														-- WB : Global bus clock

				--
				-- MASTER INTERFACE
				--
	 			ACK_I_M:  in std_logic;														-- WB : Ack from the slave
            ADR_O_M:  out  std_logic; 													-- WB : Register selection
            DAT_M:  inout  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
            STB_O_M:  out std_logic;													-- WB : Access request to the slave
            WE_O_M:   out  std_logic;													-- WB : Read/write request to the slave
				TAG0_ERROR_I_M: in  std_logic;							
				--
				-- SLAVE INTERFACE
				--

	 			ACK_O_S:  out std_logic;														-- WB : Ack to the master
--          ADR_I:  in  std_logic_vector(1 downto 0 ); 							-- WB : Register selection
            DAT_O_S:  out  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
            STB_I_S:  in  std_logic;													-- WB : Access qualify from master
            WE_I_S:   in  std_logic;													-- WB : Read/write request from master
				TAG0_WORD_AVAILABLE_O_S:  out  std_logic;							
				TAG1_ERROR_O_S:  out  std_logic											-- Error on cf access
																																				
				);
end component;

--
-- RAW SECTORS READER
--

component cf_sector_reader is
    Port ( 
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I:  in  std_logic;														-- WB : Global RESET signal
	 			ACK_O:  out std_logic;														-- WB : Ack to the master
          	ADR_I:  in  std_logic; 													-- WB : Register selection
            CLK_I:  in  std_logic;														-- WB : Global bus clock
            DAT_I_O:  inout  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
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
end component;
--
-- COMPACT FLASH EMULATOR
--

component cf_emulator 
    Port ( 	
	 			--
				-- GLOBAL INPUTS
				--
				CLK_I:  in  std_logic;														-- GLOBAL CLOCK
				RST_I:  in  std_logic;														-- GLOBAL RESET
	 			--
				-- IDE BUS
				--
				IDE_BUS: inout  std_logic_vector(15 downto 0 ); 					-- IDE DATA bidirectional bus

				NIOWR:  in  std_logic;														-- IDE : Write Strobe
				NIORD:  in  std_logic;														-- IDE : Read Strobe
			   NCE1:  in  std_logic;													 -- IDE : CE1
				NCE0:  in  std_logic;														 -- IDE : CE2
				A2:  in  std_logic;															-- IDE : Address bit 2
				A1:  in  std_logic;															-- IDE : Address bit 1
				A0:  in  std_logic;															-- IDE : Address bit 0
	
				ERROR:  out  std_logic;														-- Error on cf access
				RESET:  in  std_logic														-- Force reset
				);
end component;

--
-- FUNCTIONS AND PROCEDURES
--
		--
		-- WRITE DATA TO THE CONTROLLER (SECTOR READER)
		--
			procedure write_to_the_controller(signal CLK_I,ADR_I,ACK_O : in std_logic; 
																signal STB_I,WE_I : out std_logic;
																signal DAT_O : out std_logic_vector (15 downto 0);
																signal data_to_controller : in std_logic_vector (15 downto 0));
	
		--
		-- READ DATA FROM THE CONTROLLER (SECTOR READER)
		--
		procedure read_from_the_controller(signal CLK_I,ADR_I,ACK_O : in std_logic; 							
																signal STB_I,WE_I: out std_logic;
																signal DAT_O : in std_logic_vector (15 downto 0);
																signal read_from_the_controller : out std_logic_vector (15 downto 0));
		--
		-- READ DATA FROM THE FAT32 PROCESSOR (FILE READER)
		--
		procedure read_from_the_fat32(signal CLK_I,ACK_O : in std_logic; 							
																signal STB_I,WE_I: out std_logic;
																signal DAT_O : in std_logic_vector (15 downto 0);
																signal read_from_the_fat32 : out std_logic_vector (15 downto 0));
																
	
end package cf_package;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package body cf_package is

		--
		-- WRITE DATA TO THE CONTROLLER
		--
		procedure write_to_the_controller(signal CLK_I,ADR_I,ACK_O : in std_logic; 
																signal STB_I,WE_I : out std_logic;
																signal DAT_O : out std_logic_vector (15 downto 0);
																signal data_to_controller : in std_logic_vector (15 downto 0)) is
			begin
				STB_I <= '1';
				WE_I <= '1';
				DAT_O <= data_to_controller;
				-- wait till the ack
				wait until rising_edge(ACK_O);
				-- operate synchronously
				-- wait until rising_edge(CLK_I);
				STB_I <= '0';
				WE_I <= '0';
				--
				-- that´s not correct because
				-- in Wishbone Specification
          -- WISHBONE MASTER MUST CHECK ACK SIGNAL
	       --IN THE RISING EDGE OF THE CLOCK AND DEASSERT 
		     --  STROBE SIGNAL. SLAVE AUTOMATICALLY DEASSERT ACK
				wait until falling_edge(ACK_O);
				wait until rising_edge(CLK_I);
				-- end write-cycle
		end write_to_the_controller;

		--
		-- READ DATA FROM THE CONTROLLER
		--
		procedure read_from_the_controller(signal CLK_I,ADR_I,ACK_O : in std_logic; 							
																signal STB_I,WE_I: out std_logic;
																signal DAT_O : in std_logic_vector (15 downto 0);
																signal read_from_the_controller : out std_logic_vector (15 downto 0)) is
																
			begin
				STB_I <= '1';
				WE_I <= '0';
				-- wait till the ack
				wait until rising_edge(ACK_O);
				read_from_the_controller <= DAT_O;
				-- operate synchronously
				wait until rising_edge(CLK_I);
				STB_I <= '0';
				WE_I <= '0';
				-- end read-cycle
		end;
		--
		-- READ DATA FROM THE FAT32 PROCESSOR
		--
		procedure read_from_the_fat32(signal CLK_I,ACK_O : in std_logic; 							
																signal STB_I,WE_I: out std_logic;
																signal DAT_O : in std_logic_vector (15 downto 0);
																signal read_from_the_fat32 : out std_logic_vector (15 downto 0)) is
																
			begin
				STB_I <= '1';
				WE_I <= '0';
				-- wait till the ack
				wait until rising_edge(ACK_O);
				read_from_the_fat32 <= DAT_O;
				-- operate synchronously
				wait until rising_edge(CLK_I);
				STB_I <= '0';
				WE_I <= '0';
				-- end read-cycle
		end;

end package body cf_package;