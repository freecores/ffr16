
============================
FFR16 - FIRST FILE READER 16
============================

  - AUGUST 2003
  - UPV / EHU.  

  - APPLIED ELECTRONICS RESEARCH TEAM (APERT)-
  - Armando Astarloa - email : jtpascua@bi.ehu.es
  - DEPARTMENT OF ELECTRONICS AND TELECOMMUNICATIONS - BASQUE COUNTRY UNIVERSITY -
 
 THE ASSEMBLER CODE IS DISTRIBUTED UNDER GPL License

 THE VHDL CODE IS DISTRIBUTED UNDER :
 OpenIPCore Hardware General Public License "OHGPL" 
 http://www.opencores.org/OIPC/OHGPL.shtml

============================
070803

DIRECTORIES:

	\SOURCES
	
		\FPU : FAT PROCESSOR UNIT
			FAT16RD.PSM - SOURCE CODE
			\COMPILE : DO.BAT to compile and generate VHD file for the BlockRAM 
		\HAU : HOST ATAPI UNIT
			CFREADER.PSM - SOURCE CODE
			\COMPILE : DO.BAT to compile and generate VHD file for the BlockRAM

	\RTL

		CF_FILE_READER.VHD : FFR16 vhdl top file.
			CF_FAT16_READER.VHD : FPU vhdl file.
				FAT16RD.VHD : BlockRAM (SOFT) for FPU.
			CF_SECTOR_READER.VHD : HAU vhdl file.
				FAT16RD.VHD : BlockRAM (SOFT) for HAU.
			CF_PACKAGE.VHD : Package for high level VHDL functions.
		KCPSM : Ken Chapman KCPSM (Picoblaze) microprocessor. See Xilinx web site (http://www.xilinx.com)

	\TEST
	\DOC 