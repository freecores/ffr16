--===========================================================================--
-- 
-- FAT16 FAT PROCESSOR UNIT (FPU)
--
--  - JANUARY 2003
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
-- File name      : cf_fat16_reader.vhd
--
-- Purpose        : fat16 computations
--                  
-- Library        : WORK
--
-- Dependencies   : IEEE.Std_Logic_1164,IEEE.STD_LOGIC_ARITH,IEEE.STD_LOGIC_UNSIGNED
--
-- Simulator      : ModelSim SE version 5.5e on a WindowsXP PC
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author                 Date           Changes
--
-- 240103     Armando Astarloa     24	January			First VHDL synthesizable code
-- 190503     Armando Astarloa     19	May				Added four more external TMP reg
-- 280503	  Armando Astarloa	  28 May					KCPSM V.1002 - with reset
-- 240603	  Armando Astarloa	  24 	June		 		Quit soft reset signals (with kcpsm 
--																		v.1002)
-------------------------------------------------------------------------------
-- Description    : FA16 Computations. KCPSM & SOFT Instantation and ports.
--                  
-------------------------------------------------------------------------------
-- Entity for cf_fat16_reader Unit 		                                   	  --
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cf_fat16_reader is
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
end cf_fat16_reader;

architecture Behavioral of cf_fat16_reader is
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
component fat16rd is
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


signal DATA_WB_OUT_7_0_MASTER: std_logic_vector(7 downto 0);		-- WISHBONE DATA OUTPUT BUS
signal DATA_WB_OUT_15_8_MASTER: std_logic_vector(7 downto 0);		-- WISHBONE DATA OUTPUT BUS 
signal CONTROL_WB_OUT_MASTER: std_logic_vector(2 downto 0);			-- WISHBONE CONTROL SIGNALS
signal DATA_WB_OUT_7_0_SLAVE: std_logic_vector(7 downto 0);			-- WISHBONE DATA OUTPUT BUS
signal DATA_WB_OUT_15_8_SLAVE: std_logic_vector(7 downto 0);		-- WISHBONE DATA OUTPUT BUS 
signal CONTROL_WB_OUT_SLAVE: std_logic_vector(2 downto 0);			-- WISHBONE CONTROL SIGNALS
signal CONTROL_OUT_MASTER: std_logic;										-- WRITE ENABLE FOR TRIESTATE BUSES
signal CONTROL_OUT_SLAVE: std_logic;										-- WRITE ENABLE FOR TRIESTATE BUSES

signal TMP_0 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 0
signal TMP_1 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 1
signal TMP_2 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 2
signal TMP_3 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 3
signal TMP_4 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 0
signal TMP_5 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 1
signal TMP_6 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 2
signal TMP_7 : std_logic_vector(7 downto 0);								-- EXTERNAL TEMPORAL REGISTER 3

signal DATA_WB_IN_7_0_MASTER: std_logic_vector(7 downto 0);			-- WISHBONE DATA OUTPUT BUS
signal DATA_WB_IN_15_8_MASTER: std_logic_vector(7 downto 0);		-- WISHBONE DATA OUTPUT BUS 

signal CONTROL_WB_IN_MASTER : std_logic_vector(1 downto 0); 
signal CONTROL_WB_IN_SLAVE : std_logic_vector(1 downto 0); 							 

--
-- CLOCK ENABLE FOR THE REGISTERS
--
signal DATA_WB_OUT_7_0_MASTER_CE : std_logic; 
signal DATA_WB_OUT_15_8_MASTER_CE : std_logic;
signal CONTROL_WB_OUT_MASTER_CE : std_logic; 
signal DATA_WB_OUT_7_0_SLAVE_CE : std_logic; 
signal DATA_WB_OUT_15_8_SLAVE_CE : std_logic;
signal CONTROL_WB_OUT_SLAVE_CE : std_logic; 
signal CONTROL_OUT_MASTER_CE : std_logic; 
signal CONTROL_OUT_SLAVE_CE : std_logic; 

signal TMP_0_CE : std_logic;		
signal TMP_1_CE : std_logic;
signal TMP_2_CE : std_logic;
signal TMP_3_CE : std_logic;				 
signal TMP_4_CE : std_logic;		
signal TMP_5_CE : std_logic;
signal TMP_6_CE : std_logic;
signal TMP_7_CE : std_logic;	

--
-- OUTPUTS ENABLES (TO THE INPUTS BUS)FOR THE INPUTS REGISTER
--
signal DATA_WB_IN_7_0_MASTER_OE: std_logic;						
signal DATA_WB_IN_15_8_MASTER_OE: std_logic;

signal CONTROL_WB_IN_MASTER_OE : std_logic; 
signal CONTROL_WB_IN_SLAVE_OE : std_logic; 	

signal TMP_0_OE : std_logic;		
signal TMP_1_OE : std_logic;
signal TMP_2_OE : std_logic;
signal TMP_3_OE : std_logic;				 
signal TMP_4_OE : std_logic;		
signal TMP_5_OE : std_logic;
signal TMP_6_OE : std_logic;
signal TMP_7_OE : std_logic;	
--
-- INTERNAL SIGNALS
--

signal WB_MASTER_BUS_WRITE_ENABLE : std_logic;
signal WB_SLAVE_BUS_WRITE_ENABLE : std_logic;

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
rom:fat16rd port map (
				instruction => INSTRUCTIONS_BUS,
				address => ADDRESS_BUS,
				clk => CLK_I);

--
-- BUSES CONTROL
--
	INTERRUPT <= '0';
--
-- WB MASTER 
--
																			-- WISHBONE BUS COMPOSITION

	DAT_M <= (DATA_WB_OUT_15_8_MASTER & DATA_WB_OUT_7_0_MASTER) when 
	WB_MASTER_BUS_WRITE_ENABLE='1' else (others => 'Z');
	DATA_WB_IN_15_8_MASTER <= DAT_M(15 downto 8);
	DATA_WB_IN_7_0_MASTER <= DAT_M(7 downto 0);
																			-- WB MASTER INTERFACE CONTROL			
																			-- D2 = A0_MASTER
																			-- D1 = W_WE_MASTER
																			-- D0 = STB_O_MASTER
	ADR_O_M <= CONTROL_WB_OUT_MASTER(2);
 	WE_O_M <= CONTROL_WB_OUT_MASTER(1);
	STB_O_M <= CONTROL_WB_OUT_MASTER(0);
																			-- GENERAL CONTROL SIG. MASTER
 																			-- D0 = WB_BUS_MASTER_WRITE_ENABLE

	WB_MASTER_BUS_WRITE_ENABLE <= CONTROL_OUT_MASTER;
	

--
-- WB SLAVE 
--
	DAT_O_S <= DATA_WB_OUT_15_8_SLAVE & DATA_WB_OUT_7_0_SLAVE;
																			-- WB SLAVE INTERFACE CONTROL
																			-- D2 = TAG1_ERROR
																			-- D1 = TAG0_WORD_AVAILABLE
																			-- D0 = ACK_O_SLAVE

	TAG1_ERROR_O_S <= CONTROL_WB_OUT_SLAVE(2);																			
	TAG0_WORD_AVAILABLE_O_S <= CONTROL_WB_OUT_SLAVE(1);
	ACK_O_S <= CONTROL_WB_OUT_SLAVE(0);
																			-- GENERAL CONTROL SIG. SLAVE
 																			-- D0 = WB_BUS_SLAVE_WRITE_ENABLE

	WB_SLAVE_BUS_WRITE_ENABLE <= CONTROL_OUT_SLAVE;

--
-- INPUTS
--
--
-- WB MASTER 
--
																			-- D1 = ERROR_INPUT
																			-- D0 = ACK_I_MASTER


 	CONTROL_WB_IN_MASTER (1) <= TAG0_ERROR_I_M;	
 	CONTROL_WB_IN_MASTER (0) <= ACK_I_M;

--
-- WB SLAVE
--
																			-- D1 = TAG0_FORCE_RESET
																			-- D0 = STB_I_SLAVE	
 	CONTROL_WB_IN_SLAVE (0) <= STB_I_S;

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
				if DATA_WB_IN_7_0_MASTER_OE = '1' then
					INPUTS_BUS <= DATA_WB_IN_7_0_MASTER;
				elsif DATA_WB_IN_15_8_MASTER_OE = '1' THEN
					INPUTS_BUS <= DATA_WB_IN_15_8_MASTER;
				elsif CONTROL_WB_IN_MASTER_OE = '1' THEN
					INPUTS_BUS(7 downto 2) <= (others => '0');
					INPUTS_BUS(1 downto 0) <= CONTROL_WB_IN_MASTER;
				elsif CONTROL_WB_IN_SLAVE_OE = '1' THEN
					INPUTS_BUS(7 downto 2) <= (others => '0');
					INPUTS_BUS(1 downto 0) <= CONTROL_WB_IN_SLAVE;
			 	elsif TMP_0_OE = '1' THEN
					INPUTS_BUS <= TMP_0;
			 	elsif TMP_1_OE = '1' THEN
					INPUTS_BUS <= TMP_1;
			 	elsif TMP_2_OE = '1' THEN
					INPUTS_BUS <= TMP_2;
			 	elsif TMP_3_OE = '1' THEN
					INPUTS_BUS <= TMP_3;
			 	elsif TMP_4_OE = '1' THEN
					INPUTS_BUS <= TMP_4;
			 	elsif TMP_5_OE = '1' THEN
					INPUTS_BUS <= TMP_5;
			 	elsif TMP_6_OE = '1' THEN
					INPUTS_BUS <= TMP_6;
			 	elsif TMP_7_OE = '1' THEN
					INPUTS_BUS <= TMP_7;
				else
					INPUTS_BUS <= (others => '0');
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



			DATA_WB_OUT_7_0_MASTER <= (others => 'Z');
			DATA_WB_OUT_15_8_MASTER <= (others => 'Z');
			CONTROL_WB_OUT_MASTER <= (others => 'Z');
			DATA_WB_OUT_7_0_SLAVE <= (others => 'Z');
			DATA_WB_OUT_15_8_SLAVE <= (others => 'Z'); 
			CONTROL_WB_OUT_SLAVE <= (others => 'Z');
			CONTROL_OUT_MASTER <= 'Z';
			CONTROL_OUT_SLAVE <= 'Z';
	
				--
				-- SYNC LOAD
				--
	elsif (CLK_I='1' and CLK_I'event) then
		if DATA_WB_OUT_7_0_MASTER_CE='1' then
			DATA_WB_OUT_7_0_MASTER<= OUTPUTS_BUS;
	  	elsif DATA_WB_OUT_15_8_MASTER_CE='1' then
			DATA_WB_OUT_15_8_MASTER <= OUTPUTS_BUS;
	  	elsif CONTROL_WB_OUT_MASTER_CE='1' then
			CONTROL_WB_OUT_MASTER <= OUTPUTS_BUS(2 downto 0);
	  	elsif DATA_WB_OUT_7_0_SLAVE_CE='1' then
			DATA_WB_OUT_7_0_SLAVE <= OUTPUTS_BUS;
	  	elsif DATA_WB_OUT_15_8_SLAVE_CE='1' then
			DATA_WB_OUT_15_8_SLAVE <= OUTPUTS_BUS;
	  	elsif CONTROL_WB_OUT_SLAVE_CE='1' then
			CONTROL_WB_OUT_SLAVE <= OUTPUTS_BUS (2 downto 0);
	  	elsif CONTROL_OUT_MASTER_CE='1' then
			CONTROL_OUT_MASTER <= OUTPUTS_BUS(0);
	  	elsif CONTROL_OUT_SLAVE_CE='1' then
			CONTROL_OUT_SLAVE <= OUTPUTS_BUS(0);
	  	elsif TMP_0_CE='1' then
			TMP_0 <= OUTPUTS_BUS;
	  	elsif TMP_1_CE='1' then
			TMP_1 <= OUTPUTS_BUS;
	  	elsif TMP_2_CE='1' then
			TMP_2 <= OUTPUTS_BUS;
	  	elsif TMP_3_CE='1' then
			TMP_3 <= OUTPUTS_BUS;
	  	elsif TMP_4_CE='1' then
			TMP_4 <= OUTPUTS_BUS;
	  	elsif TMP_5_CE='1' then
			TMP_5 <= OUTPUTS_BUS;
	  	elsif TMP_6_CE='1' then
			TMP_6 <= OUTPUTS_BUS;
	  	elsif TMP_7_CE='1' then
			TMP_7 <= OUTPUTS_BUS;
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
				DATA_WB_OUT_7_0_MASTER_CE <= '1'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000001" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '1';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000010" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '1'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000011" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '1'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000100" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '1';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000101" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '1'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00000110" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '1'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

		 	when "00000111" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '1'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

		 	when "00001000" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '1';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

		 	when "00001001" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '1';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

		 	when "00001010" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '1';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

		 	when "00001011" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '1';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00001100" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '1';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00001101" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '1';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

			when "00001110" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '1';
				TMP_7_CE <= '0';

			when "00001111" =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '1';

		 	when others =>
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';
		end case;
	else
				DATA_WB_OUT_7_0_MASTER_CE <= '0'; 
				DATA_WB_OUT_15_8_MASTER_CE <= '0';
				CONTROL_WB_OUT_MASTER_CE <= '0'; 
	  			DATA_WB_OUT_7_0_SLAVE_CE <= '0'; 
				DATA_WB_OUT_15_8_SLAVE_CE <= '0';
				CONTROL_WB_OUT_SLAVE_CE <= '0'; 
				CONTROL_OUT_MASTER_CE <= '0'; 
				CONTROL_OUT_SLAVE_CE <= '0'; 
				TMP_0_CE <= '0';
				TMP_1_CE <= '0';
				TMP_2_CE <= '0';
				TMP_3_CE <= '0';
				TMP_4_CE <= '0';
				TMP_5_CE <= '0';
				TMP_6_CE <= '0';
				TMP_7_CE <= '0';

	end if;
end process;
--
-- INPUTS
--
process (PORTS_ID)
begin
if WRITE_STROBE = '0' then
	case PORTS_ID is
		when "00000000" =>
			CONTROL_WB_IN_MASTER_OE <= '1';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

	  	when "00000001" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '1';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

	 	when "00000010" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '1';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		 when "00000011" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '1';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		 when "00000100" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '1';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		when "00000101" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '1';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		when "00000110" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '1';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';


		when "00000111" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '1';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		when "00001000" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '1';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';	
	
	  	when "00001001" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '1';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		when "00001010" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '1';
			TMP_7_OE <= '0';

		when "00001011" =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '1';

	 	when others =>
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

		end case;

	else
			CONTROL_WB_IN_MASTER_OE <= '0';
			CONTROL_WB_IN_SLAVE_OE <= '0';
			DATA_WB_IN_7_0_MASTER_OE <= '0';
			DATA_WB_IN_15_8_MASTER_OE <= '0';
			TMP_0_OE <= '0';
			TMP_1_OE <= '0';
			TMP_2_OE <= '0';
			TMP_3_OE <= '0';
			TMP_4_OE <= '0';
			TMP_5_OE <= '0';
			TMP_6_OE <= '0';
			TMP_7_OE <= '0';

end if;

end process;

end Behavioral;
