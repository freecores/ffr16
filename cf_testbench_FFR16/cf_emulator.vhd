--===========================================================================--
-- 
-- CF EMULATOR
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
-- File name      : cf_emulator.vhd
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
-- 031202     Armando Astarloa     02 January	 First VHDL sintetizable code
-- 130103					Armando Astarloa					12 January		Added file use for cf content
-------------------------------------------------------------------------------
-- Description    : dummy cf model
--                  
-------------------------------------------------------------------------------
-- Entity for adress decoder Unit 		                                   	  --
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
USE STD.TEXTIO.ALL;

entity cf_emulator is
				--
				-- depends on the sectors written into the file and the memory
				-- available on the machine (all between 0 and 255)
				--
		generic (range_lba_27_24: integer := 0;
						range_lba_23_16: integer := 0;
						range_lba_15_8: integer := 1;
				--		range_lba_7_0: integer := 127;
						range_lba_7_0: integer := 255;
						bytes_per_sector: integer := 512
						); 
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
			   NCE1:  in  std_logic;														-- IDE : CE1
				NCE0:  in  std_logic;														-- IDE : CE2
				A2:  in  std_logic;															-- IDE : Address bit 2
				A1:  in  std_logic;															-- IDE : Address bit 1
				A0:  in  std_logic;															-- IDE : Address bit 0
	
				ERROR:  out  std_logic;														-- Error on cf access
				RESET:  in  std_logic														-- Force reset
				);
end cf_emulator;

architecture Behavioral of cf_emulator is

  
--
-- DUMMY MODEL FOR SIMULATION PURPOSE 
--
-- ONLY READ (IDE MODE)
-- 
-- returns data as :
--
-- D0 : LBA_7_0
-- D1 : LBA_15_8
-- D2 : LBA_23_16
--
--

signal internal_ide_bus : std_logic_vector(15 downto 0);
signal internal_data : std_logic_vector(15 downto 0);
signal internal_control : std_logic_vector(7 downto 0);
signal internal_feature : std_logic_vector(7 downto 0);
signal internal_sector_cnt : std_logic_vector(7 downto 0);
signal internal_sector_cnt_load : std_logic;
signal internal_sector_cnt_ce : std_logic;
signal internal_LBA_7_0 : std_logic_vector(7 downto 0);
signal internal_LBA_15_8 : std_logic_vector(7 downto 0);
signal internal_LBA_23_16 : std_logic_vector(7 downto 0);
signal internal_LD_LBA_27_24 : std_logic_vector(7 downto 0);
signal internal_LBA_27_24 : std_logic_vector(7 downto 0);
signal internal_command : std_logic_vector(7 downto 0);
signal internal_status : std_logic_vector(7 downto 0);
--												;    NCE1/NCE0/ A2/ A1/ A0
--							  CONTROL,0E	; 000   0    1   1   1   0
--							  DATA,10		; 000   1    0   0   0   0
--							  FEATURE,11	; 000   1    0   0   0   1
--							  SECTOR_COUNT ; 000   1    0   0   1   0
--							  LBA_7_0,13	; 000   1    0   0   1   1
--							  LBA_15_8,14	; 000   1    0   1   0   0
--							  LBA_23_16,15	; 000   1    0   1   0   1
--							  LD_LBA_27_24 ; 000   1    0   1   1   0
--							  COMMAND,17	; 000   1    0   1   1   1
--							  CF_OFF,18    ; 000	1    1	 0   0   0 		
--								;
--								; READ IDE REGISTERS
--												;    NCE1/NCE0/ A2/ A1/ A0
--							  A_STATUS,0E	; 000   0    1   1   1   0
--							  STATUS,17		; 000   1    0   1   1   1
--							  DATA,10		; 000   1    0   0   0   0

signal internal_bsy : std_logic;
signal internal_drq : std_logic;
signal sectors_read_request : std_logic;
signal end_sector_access_request : std_logic;
signal words_readed : integer;
signal temp : integer;
signal temp_ce : std_logic;
signal adr_agregate : std_logic_vector (2 downto 0);

--
-- CHARS, BUFFERS AND ARRAYS
--
--
-- 32 sectors * 512 bytes = 16384 byes
--

--
-- ARRAY INCLUDES LBA DIRECTIONATION FOR ECHA SECTOR
--
-- LBA_7_0 : std_logic_vector(7 downto 0);LBA_15_8 : std_logic_vector(7 downto 0);
--
-- LBA_27_24, LBA_23_26,LBA_15_8,LBA_7_0,BYTES OF THE SECTOR
--
type CHR_BUFFER is array (0 to range_lba_27_24,0 to range_lba_23_16,
											0 to range_lba_15_8,0 to range_lba_7_0,
											0 to (bytes_per_sector-1)) of std_logic_vector(7 downto 0);
signal cf_buffer : CHR_BUFFER;
signal cf_buffer_2_low_byte : std_logic_vector  (7 downto 0);
signal cf_buffer_2_high_byte : std_logic_vector  (7 downto 0);
--
-- STATE DEFINITIONS
--
type STATE_TYPE is (START, IDLE, CHIPSEL, CE0_SEL , CE1_SEL	,NIORD_SEL_CE0 , 
							NIOWR_SEL_CE0, NIORD_SEL_CE1 , NIOWR_SEL_CE1, PROCESS_DATA_READ,
							PROCESS_COMMAND, WAIT_CYCLE_END );
signal CS, NS: STATE_TYPE;


type STATE_TYPE_KERNEL is (START_KERNEL, IDLE_NBSY, BSY,DRQ_NALLOW, DRQ_ALLOW,
		CHECK_WORDS_READ, CHECK_SECTOR_COUNT );

signal CS_KERNEL, NS_KERNEL: STATE_TYPE_KERNEL;


begin

--
-- BUS SIGNALS CONTROL
--
IDE_BUS <= internal_ide_bus when NIORD = '0' else (others => 'Z');
adr_agregate <= A2 & A1 & A0;

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
file_open(fstatus, dataout,"./DUM0511.BIN");
	L1 :
		for LBA_27_24 in 0 to range_lba_27_24 loop
		for LBA_23_16 in 0 to range_lba_23_16 loop
		for LBA_15_8 in 0 to range_lba_15_8 loop
		for LBA_7_0 in 0 to range_lba_7_0 loop
		for integer_pos in 0 to ((bytes_per_sector/4)-1)loop

			read(dataout, integer_readed);
			vector_readed := CONV_STD_LOGIC_VECTOR(integer_readed,32);		

			cf_buffer (LBA_27_24,LBA_23_16,LBA_15_8,LBA_7_0,integer_pos*4) <= vector_readed (7 downto 0) ; 
			cf_buffer (LBA_27_24,LBA_23_16,LBA_15_8,LBA_7_0,(integer_pos*4)+1) <= vector_readed (15 downto 8);
			cf_buffer (LBA_27_24,LBA_23_16,LBA_15_8,LBA_7_0,(integer_pos*4)+2) <= vector_readed (23 downto 16);
			cf_buffer (LBA_27_24,LBA_23_16,LBA_15_8,LBA_7_0,(integer_pos*4)+3) <= vector_readed (31 downto 24);


--			assert error_on_read report "File read error" severity note;
	  end loop;
	  end loop;
	  end loop;
	  end loop;
	  end loop;
		wait;
	end process;

--
-- COMBINATIONAL ASIGNATIONS
	internal_lba_27_24 <= internal_ld_lba_27_24 and "00001111";
--
--
-- BSY : Está a nivel alto cuando el controlador interno de la CF está accediendo al buffer 
-- o al registro de comando (No se indica nada en el datasheet sobre el acceso a otros registros). 
-- El host no puede acceder al dispositivo ni los bits internos son válidos.
--
-- DRDY : Indica que el dispositivo puede admitir comandos. Después del encendido se pone 
-- a nivel 0 hasta que puede admitir comandos. Después de un error cambia una vez que el 
-- host haya leido el registro de status.
--
-- DWF : Drive Write Fault. Indica que se ha producido un error durante la escritura.
--
-- DSC : Drive Seek Complete. Indica que el sector seleccionado ha sido encontrado.
-- 
-- DRQ : Data Request. Indica que el adaptador está preparado para transferir un word 
-- o un byte entre el host y el adaptador.
--
-- ERR : Indica que se ha producido un error durante la ejecución del comando previo. 
-- Los bits en el registro de error indican la causa.
--
-- BSY / DRDY / DWF / DSC / DRQ / CORR / 0 / ERR
internal_status <= internal_bsy & '1' & '0' & '1' & internal_drq & '0'& '0'& '0' ; 
--
-- 
--
SYNC_PROC: process (CLK_I, RST_I)
    begin
       if (RST_I='1') then
              CS <= START;
	
--			   			REG_PRINT (i,j) <= '0';			-- RESET REGISTERS
--						end loop;
--					end loop;
					
	     elsif (CLK_I'event and CLK_I = '1') then
            CS <= NS;

       end if;
    end process;
 
--
-- COMBINATIONAL PROCESS FOR EACH STATE
--
    COMB_PROC: process (CS,NCE0,NCE1)

    begin
       case CS is
            when START =>
					internal_sector_cnt_load <= '0';			
				  internal_control <= ( others => '0');
				  internal_ide_bus <= ( others => '0');
				  internal_data <= ( others => '0');
				  internal_feature <= ( others => '0');
				  --internal_sector_cnt <= ( others => '0');
				  internal_LBA_7_0 <= ( others => '0');
				  internal_LBA_15_8 <= ( others => '0');
				  internal_LBA_23_16 <= ( others => '0');
				  internal_LD_LBA_27_24 <= ( others => '0');
				  internal_command <= ( others => '0');
				  --internal_status <= ( others => '0');
					end_sector_access_request <= '0';


				  sectors_read_request <= '0';
				  words_readed <= 0;

					ERROR <= '0';

					NS <= IDLE;						-- WAIT FOR A RD/WR OPERATION

				when IDLE =>
					if ((NCE0 = '0') or (NCE1 = '0')) then
						-- introduce delay for time model
						NS <= CHIPSEL;
				  	else
						NS <= IDLE;
					end if;

		  		when CHIPSEL =>

					if ((NCE0 = '0') and (NCE1 = '1')) then
						NS <= CE0_SEL;
					elsif ((NCE0 = '1') and (NCE1 = '0')) then
						NS <= CE1_SEL;
					else
						ERROR <= '1';
						NS <= IDLE;
					end if;

				when CE0_SEL =>

					if ((NIOWR  = '0') and (NIORD = '1'))  then
						NS <= NIOWR_SEL_CE0;
					elsif ((NIOWR = '1') and (NIORD = '0'))  then
						NS <= NIORD_SEL_CE0;
					else
						ERROR <= '1';
						NS <= IDLE;
					end if;

				when CE1_SEL =>

					if ((NIOWR  = '0') and (NIORD = '1'))  then
						NS <= NIOWR_SEL_CE1;
					elsif ((NIOWR = '1') and (NIORD = '0'))  then
						NS <= NIORD_SEL_CE1;
					else
						ERROR <= '1';
						NS <= IDLE;
					end if;
--							;
--							; WRITE IDE REGISTERS
--							;
--															    NCE1/NCE0/ A2/ A1/ A0
--							CONTROL					  ; 000   0    1   1   1   0
--							DATA						  ; 000   1    0   0   0   0
--							FEATURE					  ; 000   1    0   0   0   1
--							SECTOR_COUNT			  ; 000   1    0   0   1   0
--							LBA_7_0					  ; 000   1    0   0   1   1
--							LBA_15_8					  ; 000   1    0   1   0   0
--							LBA_23_16				  ; 000   1    0   1   0   1
--							LD_LBA_27_24			  ; 000   1    0   1   1   0
--							COMMAND					  ; 000   1    0   1   1   1
--							CF_OFF     				  ; 000	 1    1   0   0   0 		
--							;
--							; READ IDE REGISTERS
--														  ;    NCE1/NCE0/ A2/ A1/ A0
--							A_STATUS	              ; 000   0    1   1   1   0
--							STATUS	              ; 000   1    0   1   1   1
--							DATA						  ; 000   1    0   0   0   0
		--
		-- CF READ
		--
				when NIORD_SEL_CE1 =>

					--
					-- ALTERNATIVE STATUS REGISTER READ OPERATION
					--
					case adr_agregate is
						when "110" =>
								internal_ide_bus (7 downto 0) <= internal_status;
								NS <= WAIT_CYCLE_END;
						when others =>
								internal_ide_bus <= (others => '1');
								NS <= WAIT_CYCLE_END;	
					end case;

				when NIORD_SEL_CE0 =>

					--
					-- ALTERNATIVE STATUS REGISTER READ OPERATION
					--
					case adr_agregate is
						when "111" =>
								internal_ide_bus (7 downto 0) <= internal_status;
								NS <= WAIT_CYCLE_END;

						when "000" =>
								if internal_drq = '1' then
									-- data reading from buffer is allowed
									--
									-- if arrives to this state drq = 1
									--
									words_readed <= words_readed + 1;
									--
									-- data on the array are stored in little endian
									--

									cf_buffer_2_high_byte <= cf_buffer (CONV_INTEGER(internal_LBA_27_24),
																								CONV_INTEGER(internal_LBA_23_16),
																								CONV_INTEGER(internal_LBA_15_8),
																								CONV_INTEGER(internal_LBA_7_0),
																								(words_readed*2)+1);
				  					 cf_buffer_2_low_byte <= cf_buffer (CONV_INTEGER(internal_LBA_27_24),
																								CONV_INTEGER(internal_LBA_23_16),
																								CONV_INTEGER(internal_LBA_15_8),
																								CONV_INTEGER(internal_LBA_7_0),
																								words_readed*2);
									NS <= PROCESS_DATA_READ;
								else
									-- internal_ide_bus <= (others => '0');
									-- if drq=0 the buffer data transfer has finished or not started
									words_readed <= 0;
									NS <= WAIT_CYCLE_END;
								end if;

						when others =>
								internal_ide_bus <= (others => '1');
								NS <= WAIT_CYCLE_END;	
					end case;

				when PROCESS_DATA_READ =>

					internal_ide_bus <= cf_buffer_2_high_byte & cf_buffer_2_low_byte;

					NS <= WAIT_CYCLE_END;

		--
		-- CF WRITE
		--
				when NIOWR_SEL_CE1 =>
					--
					-- CONTROL REGISTER WRITE OPERATION
					--
					internal_control <= IDE_BUS(7 downto 0);
					NS <= WAIT_CYCLE_END;

				when NIOWR_SEL_CE0 =>
					--
					-- REGISTERS WRITE OPERATION
					--
					case adr_agregate is
					
						when "000" =>
							--
							-- attempt to write into data register - not implemented
							--
							null;
							NS <= WAIT_CYCLE_END;

						when "001" =>
							--
							-- FEATURE REGISTER WRITE OPERATION
							--
					      internal_feature <= IDE_BUS(7 downto 0);
							NS <= WAIT_CYCLE_END;

						when "010" =>
							--
							-- SECTOR COUNT REGISTER WRITE OPERATION
							--
					     internal_sector_cnt_load <= '1';
							NS <= WAIT_CYCLE_END;

						when "011" =>
							--
							-- LBA_7_0 REGISTER WRITE OPERATION
							--
					      internal_LBA_7_0 <= IDE_BUS(7 downto 0);
							NS <= WAIT_CYCLE_END;

					   when "100" =>
							--
							-- LBA_15_8 REGISTER WRITE OPERATION
							--
					      internal_LBA_15_8 <= IDE_BUS(7 downto 0);
							NS <= WAIT_CYCLE_END;

					 	when "101" =>
							--
							-- LBA_23_16 REGISTER WRITE OPERATION
							--
					      internal_LBA_23_16 <= IDE_BUS(7 downto 0);
							NS <= WAIT_CYCLE_END;

				   	when "110" =>
							--
							-- LD_LBA_27_24 REGISTER WRITE OPERATION
							--
					      internal_LD_LBA_27_24 <= IDE_BUS(7 downto 0);
							NS <= WAIT_CYCLE_END;

			   		when "111" =>
							--
							-- COMMAND REGISTER WRITE OPERATION
							--
					      internal_command <= IDE_BUS(7 downto 0);
							-- inform to the kernel that the sector access must be ended if
							-- it is doing
							words_readed <= 0;
							end_sector_access_request <= '1';
							NS <= PROCESS_COMMAND;
							--



				  		when others =>
							--
							-- attempt to write into data register - not implemented
							--
							null;
							NS <= WAIT_CYCLE_END;



			  		end case;

				when PROCESS_COMMAND =>
							--
							-- deassert crossed signal => RESET CURRENT SECTOR READ PROCESS IF RUNNING
							--
					
					end_sector_access_request <= '0';

					case internal_command is
						-- comand read sector
						when "00100000" =>					
							sectors_read_request <= '1';
							NS <= WAIT_CYCLE_END;
						when others =>
							--
							-- NOT IMPLEMENTED MORE THAN READ COMMAND
							--
							ERROR <= '1';
							NS <= START; -- RESET

					end case;

				when WAIT_CYCLE_END =>
					--
					-- 
					--

					internal_sector_cnt_load <= '0';

					if internal_sector_cnt = 0 then
						sectors_read_request <= '0';
					else
						sectors_read_request <= sectors_read_request;
					end if;

					if ((NCE0 = '1') and (NCE1 = '1')) then
						NS <= IDLE;	
					else
						NS <= WAIT_CYCLE_END;	
					end if;
		end case;
end process;

--
-- KERNEL SYNCRONUOS CONTROL PROCESS
--
KERNEL_SYNC_PROC: process (CLK_I, RST_I)
    begin
       if (RST_I='1') then
				--		internal_sector_cnt <= (others => '0');
              CS_KERNEL <= START_KERNEL;
						internal_sector_cnt <= (others => '0');
					
	     elsif (CLK_I'event and CLK_I = '1') then
            CS_KERNEL <= NS_KERNEL;

					if temp_ce = '1' then		-- temporal counter
						temp <= temp + 1;
					else
						temp <= 0;
					end if;
					
					-- Counters

					if internal_sector_cnt_load = '1'  then		-- sector counter
						internal_sector_cnt <= IDE_BUS(7 downto 0);
					elsif internal_sector_cnt_ce = '1' then
								internal_sector_cnt <= internal_sector_cnt - 1;
					else
							internal_sector_cnt <= internal_sector_cnt;
					end if;

					-- shared flags

       end if;
    end process;
 
--
-- COMBINATIONAL PROCESS FOR EACH STATE
--

--
--
--START_KER, IDLE_NBSY, BSY, DRQ_NALLOW, DRQ_ALLOW,
--		TEST_WORDS_READ, TEST_SEC_COUNT
KERNEL_COMB_PROC: process (CS_KERNEL,temp,words_readed,end_sector_access_request)

    begin
       case CS_KERNEL is
            when START_KERNEL =>
					internal_sector_cnt_ce <= '0';
					internal_bsy <= '0';	-- not busy
					internal_drq <= '0'; -- transfers not allowed
					temp_ce <= '0';
					
					NS_KERNEL <= IDLE_NBSY;

			  	when IDLE_NBSY =>
					internal_bsy <= '0';	-- not busy
					internal_drq <= '0';
					if temp = 10 then
						-- go to busy state
						-- each 5 not busy cycles one busy 
						--
						--

						NS_KERNEL <= BSY;
					else
						if sectors_read_request = '1' then
							temp_ce <= '0';
							NS_KERNEL <= DRQ_NALLOW;
						else
							temp_ce <= '1';
							NS_KERNEL <= IDLE_NBSY;
 					   end if;
					end if;
				 
				when BSY =>
					internal_bsy <= '1';	-- busy
					internal_drq <= '0'; -- transfers not allowed
					temp_ce <= '0';
					NS_KERNEL <= IDLE_NBSY;

				when DRQ_NALLOW =>
					--
					-- simulate delay of command execution and flash sector read
					--
					internal_bsy <= '1';	-- not busy
					internal_drq <= '0'; -- transfers not allowed
					if temp = 20 then
						temp_ce <= '0';
						NS_KERNEL <= DRQ_ALLOW;
					else
						temp_ce <= '1';
						NS_KERNEL <= DRQ_NALLOW;
					end if;

			  	when DRQ_ALLOW =>
					internal_bsy <= '0';	-- not busy
					internal_drq <= '1'; -- transfers allowed
												--
												-- this signal allow buffer data transfer in the other state machine
												--

					-- internal_sector_cnt <= internal_sector_cnt - 1;
					internal_sector_cnt_ce <= '1';
					NS_KERNEL <= CHECK_WORDS_READ;

				when CHECK_WORDS_READ =>
					internal_sector_cnt_ce <= '0';

					if (words_readed = 256 or end_sector_access_request = '1') then
						--
						-- all the 512 bytes buffer has been readed
						--
						internal_bsy <= '0';	-- not busy
						internal_drq <= '0'; -- transfers not allowed
						NS_KERNEL <= CHECK_SECTOR_COUNT;
					else
					 	--
					 	-- wait till the end of the reading process
						--
						internal_bsy <= '0';	-- not busy
						internal_drq <= '1'; -- transfersallowed


						NS_KERNEL <= CHECK_WORDS_READ;
					end if;
		
				when CHECK_SECTOR_COUNT =>
					internal_bsy <= '0';	-- not busy
					internal_drq <= '0'; -- transfers not allowed
					if internal_sector_cnt = 0 then
						-- reading operation has been finished
						NS_KERNEL <= IDLE_NBSY;
					else
						-- continue with another sector transfer
						--
						-- INSERT HERE LBA INCREMENTATION!!!!
						--
						NS_KERNEL <= DRQ_NALLOW;
				 	end if;
			end case;
end process;
end Behavioral;


