--===========================================================================--
-- 
-- FFR16 TESTBENCH
--
--  - JANUARY 2003
--  - UPV / EHU.  
--
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
-- File name      : cf_file_read_tb.vhd
--
-- Purpose        : 
--                  
-- Library        : WORK
--
-- Dependencies   : IEEE.Std_Logic_1164
--
-- Simulator      : ModelSim XE version 5.5b on a Windows98 PC
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date           Changes
--
-- 140103     Armando Astarloa     	03 January	 		First VHDL compilable code
-------------------------------------------------------------------------------
-- Description    : testbench for cfemulator+cfsectorreader cosimulation
--                  
-------------------------------------------------------------------------------
-- Entity sector reader testbench Unit 		                                --
-------------------------------------------------------------------------------
library IEEE; 
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
USE STD.TEXTIO.ALL;

library WORK;
use WORK.cf_package.ALL;


entity cf_file_read_tb is
		generic (
						size_en_bytes: integer := 68052
						); 
end cf_file_read_tb;

architecture tb of cf_file_read_tb is
--
-- ARRAY INCLUDES LBA DIRECTIONATION FOR ECHA SECTOR
--
-- LBA_7_0 : std_logic_vector(7 downto 0);LBA_15_8 : std_logic_vector(7 downto 0);
--
-- LBA_27_24, LBA_23_26,LBA_15_8,LBA_7_0,BYTES OF THE SECTOR
--
type CHR_BUFFER is array (0 to (size_en_bytes-1)) of std_logic_vector(7 downto 0);
signal data_buffer : CHR_BUFFER;
--
-- SLAVE INTERFACE (fot p.to p. connection with the data processor module)
--
signal	RST_I:  std_logic;																				-- WB : Global RESET signal
signal	ACK_O:  std_logic;																				-- WB : Ack to the master
signal CLK_I:  std_logic;																					-- WB : Global bus clock
--       ADR_I:  in  std_logic_vector(1 downto 0 ); 							-- WB : Register selection
signal DAT_I_O:  std_logic_vector(15 downto 0 ); 						-- WB : 16 bits data bus input
signal STB_I:  std_logic;													-- WB : Access qualify from master
signal WE_I:   std_logic;													-- WB : Read/write request from master
signal	TAG0_WORD_AVAILABLE_O:  std_logic;							
signal	TAG1_ERROR_O:  std_logic;	
signal	TAG2_FORCE_RESET_I : std_logic	;		


--
-- INTERCONEXION SIGNALS
--
signal stb_internal : std_logic;
signal ack_internal : std_logic;
signal data_internal : std_logic_vector(15 downto 0 );
signal we_internal : std_logic;	
signal adr_i_internal : std_logic;
signal error_internal : std_logic;	

signal tag0_word_available_internal : std_logic;
signal tag1_word_request_internal : std_logic;

--
-- IDE INTERCONECTION SIGNALS
--

	signal IDE_BUS: std_logic_vector(15 downto 0 ); 					-- IDE DATA bidirectional bus

	signal NIOWR:  std_logic;														-- IDE : Write Strobe
	signal NIORD:  std_logic;														-- IDE : Read Strobe
	signal NCE1:  std_logic;														 -- IDE : CE1
	signal NCE0:  std_logic;															-- IDE : CE2
	signal A2:  std_logic;																 -- IDE : Address bit 2
	signal A1:  std_logic;																 -- IDE : Address bit 1
	signal A0:  std_logic;																 -- IDE : Address bit 0

	signal ERROR:  std_logic;															-- Error on cf access
	signal RESET:  std_logic;																-- Force reset


--
-- TESTBENCH SIGNALS
--
--signal DAT_O:  std_logic_vector(15 downto 0 ); 			-- WB : 16 bits data bus input
	signal word_rd_from_fat32 : std_logic_vector (15 downto 0);
	signal data_to_controller :  std_logic_vector(15 downto 0 ); 
	signal end_sim : boolean := false;
	
	constant tdelay : time := 10 ns;
	constant tper : time := 50 ns; 				  


begin
--
-- ARRAY FILL
--

FILL_ARRAY:process
	--
	-- FILE VARIABLES
	--
	--
	-- content of the compact flash
	--
	type IntegerFileType is file of integer;
   file dataout:IntegerFileType;
	variable fstatus: FILE_OPEN_STATUS;

	variable line_sector:line;																-- lines read from file (one line => one sector)
  
	variable integer_readed : integer;
	variable vector_readed : std_logic_vector (31 downto 0);
	variable error_on_read : boolean;

	begin
-- example files...
-- RAW0_255.CHK is the first file stored into the fat16 ROOT DIR of the IDE device
-- The image file associated is DUM0511.BIN in cf_emulator that corresponds with
-- the 512 first LBA sectors of the volume
file_open(fstatus, dataout,"./RAW0_255.chk");

	L1 :

		for integer_pos in 0 to ((size_en_bytes/4)-1)loop

			read(dataout, integer_readed);
			vector_readed := CONV_STD_LOGIC_VECTOR(integer_readed,32);		

			data_buffer (integer_pos*4) <= vector_readed (7 downto 0) ; 
			data_buffer ((integer_pos*4)+1) <= vector_readed (15 downto 8);
			data_buffer ((integer_pos*4)+2) <= vector_readed (23 downto 16);
			data_buffer ((integer_pos*4)+3) <= vector_readed (31 downto 24);


--			assert error_on_read report "File read error" severity note;
	  end loop;
		wait;
	end process;
--
-- COMPONENT INSTANTATION 
--

--
-- COMPACT FLASH EMULATOR
--	
	compact_flash :cf_emulator port map ( 	
	 			--
				-- GLOBAL INPUTS
				--
				CLK_I => CLK_I,
				RST_I => RST_I,
	 			--
				-- IDE BUS
				--
				IDE_BUS => IDE_BUS,
				NIOWR => NIOWR,
				NIORD => NIORD,
			   NCE1 => NCE1,
				NCE0 => NCE0,
				A2 => A2,
				A1 => A1,
				A0 => A0,
	
				ERROR => ERROR,
				RESET => RESET
				);

--
-- RAW SECTORS READER 
--
   controller : cf_sector_reader
    Port map( 
	 			--
				-- WISHBONE SIGNALS
				--
				RST_I => RST_I,
 				ACK_O => ack_internal,
	       ADR_I => adr_i_internal, 				
         CLK_I => CLK_I,
         DAT_I_O => data_internal,
         STB_I => stb_internal,
	       WE_I => we_internal,
				TAG0_WORD_AVAILABLE => tag0_word_available_internal,				
				TAG1_WORD_REQUEST => tag1_word_request_internal,					
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
	
				ERROR => error_internal,
				RESET => RESET
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

	 			ACK_O_S => ACK_O,
				--          ADR_I:  in  std_logic_vector(1 downto 0 ); 							-- WB : Register selection
          DAT_O_S => DAT_I_O,
          STB_I_S => STB_I,
          WE_I_S => WE_I,
		  		TAG0_WORD_AVAILABLE_O_S => TAG0_WORD_AVAILABLE_O,
	 			TAG1_ERROR_O_S => TAG1_ERROR_O,											-- Error on cf access
				TAG2_FORCE_RESET_I_S => TAG2_FORCE_RESET_I							-- Force reset
																
				);

--
-- SIGNALS CONTROL
--

-- DAT_I_O <= DAT_O when WE_I = '1' else (others => 'Z');
--
-- CLK PROCESS
--
	process
	begin
		while not end_sim loop
				CLK_I <= '0';
			wait for tper/2;
				CLK_I <= '1';
			wait for tper/2;
		end loop;
		wait;
	end process;	

--
-- SIMULATION PROCESS
--
--
-- note : this testbench is valid for the 8 bit version of the wishbone interface
-- If 16 bits version is used the only change needed must be done at the check
-- section :
-- 			   assert word_rd_from_fat32 (15 downto 0) = data_buffer (i+1) & data_buffer (i)	
	process
		variable i,j : integer;


	begin	

		--
		-- RESET DELAY
		--					 
		RST_I <= '1';
		wait for tdelay;
		RST_I <= '0';
		wait for tdelay;

		-- no force reset
		RESET <= '0';
		-- not implemented
		tag1_word_request_internal <= '0';
		TAG2_FORCE_RESET_I <= '0';
		--
		-- READ DATA FROM THE FAT32 PROCESSOR AND STORE THEN INTO A FILE
		--


		for i in 0 to (size_en_bytes-1) loop

				wait for tdelay;
			 	read_from_the_fat32(CLK_I,ACK_O,STB_I,WE_I,DAT_I_O,word_rd_from_fat32);
				wait for tdelay;
			   assert word_rd_from_fat32 (7 downto 0) = data_buffer (i)

				report "No coincide el valor leido con el esperado - Read value not match"
				severity note;

--			assert error_on_read report "File read error" severity note;
	  end loop;

		end_sim <= true;
		assert false report "Simulacion correcta - Simulation OK" severity note;
		wait;
		
	end process;
	
				

end tb;
		
	
