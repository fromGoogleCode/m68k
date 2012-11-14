*-----------------------------------------------------------
* Program    : bootloader
* Written by : ljalvs@gmail.com
* Date       : 2012.01.27
* Description: bootloader for the 68000
*
* 2012.02.10, ljalves, modified for 39SF040 flash memory
*                      flash has a 4k sector size
*                      available space starts at 0x2000 (2x4Kb)
*                      flash position moved to 0x400000 (4Mb)
*                      FTDI position moved to 0x600000
*
* 2012.04.04, ljalves, modified for Alcetronics M68K board
*                      8 Mb RAM from 0x0 - 0x7FFFFF
*                      (Initially 4Mb installed)
*                      4 Mb Flash (AM29F800B) from 0x800000 - 0xBFFFFF
*                      FTDI position at 0xF00000
*
* 2012.11.13, lajlves, added auto-programming FPGA at boot time
*                      added option to boot directly from FLASH base addr
*
*-----------------------------------------------------------

FLASH_START	EQU $800000

* Flash sector address table
FSA0		EQU $000000	* 16Kb (bootloader)
FSA1		EQU $004000	* 8Kb
FSA2		EQU $006000	* 8Kb
FSA3		EQU $008000	* 32Kb (fpga bitstream)
FSA4_18		EQU $010000	* 64Kb (15 blocks)

* Flash chip address table
FCHIP1		EQU $800000
FCHIP2		EQU $900000
FCHIP3		EQU $A00000
FCHIP4		EQU $B00000



* FTDI data
FTDI_DATA	EQU $E00000
* FTDI status
* 7 6 5 4 3 2 1 0
*             | \- ftdi_rxf
*             \--- ftdi_txe 
FTDI_STAT	EQU $E00002


* System control byte
* 7 6 5 4 3 2 1 0
* |             \- /FPGA_PGM
* \--------------- /FPGA_BUSY
SYS_CTRL	EQU $E00004

* FPGA programming address
FPGA_ADDR	EQU $F00000
FPGA_BITSIZE	EQU 22268


* FPGA config
* 7 6 5 4 3 2 1 0
*             | \- Load FPGA on startup
*             \--- FLASH has FPGA configuration (not used)
FPGA_CONFIG	EQU $80FFFE


DELAY     EQU $BFFFF



ESC       EQU $1B

	* VARIABLES
	ORG	$400

MAGIC		DS.L	1
ST_VEC		DS.L	1
SIZE		DS.L	1
FIRST_ADDR	DS.L	1
OFFSET		DS.L	1
FSTART		DS.L	1
FLAG		DS.L	1


*	ROM START ADDR
	ORG	$800000

*	SSP ADDR
	DC.L	$00000500
*	BOOT JUMP ADDR
	DC.L	$00800008


START:

****************************
*	bootloader start
****************************

* copy booloader to ram
* execute from there to be able to write the flash

	
*	lea	boot_real_start,A0
*	lea	0,A1
*	move.l	#(END-boot_real_start),D0
*	clr.l	D1
*copy_me:
*	move.w	(A0)+,(A1)+
*	addi.l	#1,D1
*	cmp.l	D0,D1
*	bls	copy_me
*	nop
*	jmp	$0


main_start:

	bsr 	flush_ftdi

*	Display boot message
	lea	boot_message1,A0
	bsr	printstr

	
*	wait around 3 sec for a key press
	move.l	#DELAY,D0
	lea	FTDI_STAT,A0
	lea	FTDI_DATA,A1

waitboot:
	move.b	(A0),D1
	btst	#0, D1
	bne	key_wait
	
	move.b	(A1),D1
	cmpi.b	#' ',D1
	beq	loader
	
	
key_wait:
	sub.l	#1,D0
	bne	waitboot

*	No key pressed

	* check fpga autoload bit
	move.w	FPGA_CONFIG,D0
	btst	#0,D0
	bne	no_fpga_autoload

	lea	FCHIP1,A1
	adda.l	#FSA3,A1
	bsr	program_fpga

no_fpga_autoload:

*	Start program in flash or last loaded program from ram
	lea	boot_message2,A0
	bsr	printstr
	
*	check magic number
	move.l	MAGIC,D0
	cmpi.l	#$CACABABA,D0
	bne	go_flash
	
	move.l	ST_VEC,D0
	movea.l	D0,A0
	jmp	(A0)

go_flash:	
	jmp	FLASH_START_
	





*********************************************************








	

*	Key pressed, start loader & flasher
loader:	
	lea	menu_msg,A0
	bsr	printstr
	bsr	flush_ftdi


	* get one char
	bsr	rdchar
	
	cmp.b	#'1',D0
	beq	_load_srec

	cmp.b	#'2',D0
	beq	_load_bin_ram

	cmp.b	#'4',D0
	beq	_erase_flash
	
	cmp.b	#'5',D0
	beq	_load_fpga_ram

	cmp.b	#'6',D0
	beq	_load_fpga_flash

	cmp.b	#'7',D0
	beq	_load_fpga

	cmp.b	#'8',D0
	beq	_set_autoload_fpga

	cmp.b	#'9',D0
	beq	_tutor

	cmp.b	#'a',D0
	beq	_run_flash
	
	bra	loader


_tutor:
	jmp	$804000

_run_flash:
	clr.l	MAGIC
	jmp	$810000

_set_autoload_fpga:
	bsr	set_autoload_fpga
	bra	loader

_load_fpga:
	lea	FCHIP1,A1
	adda.l	#FSA3,A1
	bsr	program_fpga
	bra	loader

_load_fpga_flash:
	bsr	load_srec
	bsr	WRITE_FLASH
	bra	loader

_load_fpga_ram:
	bsr	load_srec
	lea	$10000,A1
	bsr	program_fpga
	bra	loader

_load_bin_ram:
	bsr	load_bin_ram
	bra	loader


_erase_flash:
	bsr	erase_flash
	bsr	rdchar
	bra	loader


_load_srec:
	bsr	load_srec
	
	cmpi.b	#2,D3
	bne	ram_only
	
*	write flash	
	bsr	WRITE_FLASH


ram_only:

*	store magic number
	move.l	#$CACABABA,D0
	move.l	D0,MAGIC

	* start prog
	move.l	ST_VEC,D0
	movea.l	D0,A0
	jmp	(A0)

	
	bra	loader





******************************************************************
******************************************************************
******************************************************************
* Load a binary stream to RAM
* Input starting address and total bytes
* Execution starts at starting address

load_bin_ram:
	* read starting address
	* 24bit = 3 bytes, msb first
	bsr	rdchar
	move.b	D0,D7
	lsl.w	#8,D7
	bsr	rdchar
	move.b	D0,D7
	lsl.l	#8,D7
	bsr	rdchar
	move.b	D0,D7
	andi.l	#$00FFFFFF,D7
	move.l	D7,A0
	movea.l	A0,A3
	
	* get size
	* 3 bytes
	bsr	rdchar
	move.b	D0,D7
	lsl.w	#8,D7
	bsr	rdchar
	move.b	D0,D7
	lsl.l	#8,D7
	bsr	rdchar
	move.b	D0,D7
	andi.l	#$00FFFFFF,D7
	move.l	D7,D6
	
	lea	FTDI_DATA,A1
	lea	FTDI_STAT,A2
	
	* load stream to ram
_lram_wait_byte:
	move.b	(A2),D0
	btst	#0,D0
	bne	_lram_wait_byte
	
	* byte incoming
	move.b	(A1),(A0)+
	
	subq.l	#1,D6
	bne	_lram_wait_byte
	
	
	jmp	(A3)




******************************************************************
******************************************************************
******************************************************************





* load an srecord to memory
load_srec:

	lea	load_srec_msg,A0
	bsr	printstr


	lea	FTDI_DATA,A6
	lea	FTDI_STAT,A5

	clr.l	D3
	
*	Load S-record
	clr.l	D4     ; CLEAR NUMBER OF BYTE 
	clr.l	D5     ; CLEAR CHECK SUM AND ERROR WORDs
wait_srec:
	bsr	CINS
        cmp.b	#'S',D0
        bne.s	wait_srec

get_type:
	bsr	CINS
	cmp.b	#'8',D0
	bne	check_start


* read start address
	clr.l	D6
	
	bsr	GET_HEXS	; ignore

	bsr	GET_HEXS
        move.b	D1,D6
	rol.l	#8,D6

	bsr	GET_HEXS
        move.b	D1,D6
	rol.l	#8,D6

	bsr	GET_HEXS
        move.b	D1,D6

	movea.l	D6,A0
	
*	store start addr
	move.l	A0,D0
	move.l	D0,ST_VEC
	




*WAIT_LINE:
*	bsr	CINS
*	cmp.b	#10,D0
*	bne.s	WAIT_LINE

*	Finished loading file
	lea.l	load_message7,A0
	bsr	printstr
	
	move.l	D4,SIZE
	move.l	D4,D0
	BSR	PRINT_DEC     ; SHOW NUMBER OF BYTE RECEIVED

	lea	load_message8,A0
	bsr	printstr

	SWAP.W D5
	CLR.L D0
	MOVE.W D5,D0
	BSR PRINT_DEC

	lea	load_message9,A0
	bsr	printstr

	bsr 	flush_ftdi

	rts



****************************************************
****************************************************







*	D0,D1 - local vars
*	D5 - checksum byte
*	D4 - total bytes
*	D7 - line bytes
*	D6 - temporary address
*	D3 - ram/flash flag

check_start:
	cmp.b	#'2',D0
	beq.s	start_found2

	cmp.b	#'1',D0
	beq.s	start_found1

	bra	wait_srec

start_found2:
	clr.w	D5          ; CLEAR BYTE CHECK SUM

	bsr	GET_HEXS
	clr.l	D7
	move.b	D1,D7       ; NUMBER OF BYTE SAVED TO D7
	subq.b	#5,D7
	*move.l	D7,D0
	add.b	D1,D5       ; ADD CHECK SUM

* GET 24-BIT ADDRESS, SAVE TO A0

	clr.l	D6
	bsr	GET_HEXS
        move.b	D1,D6
	add.b	D1,D5
	rol.l	#8,D6

	bra	common

start_found1:
	clr.w	D5          ; CLEAR BYTE CHECK SUM

	bsr	GET_HEXS
	clr.l	D7
	move.b	D1,D7       ; NUMBER OF BYTE SAVED TO D7
	subq.b	#4,D7
	*move.l	D7,D0
	add.b	D1,D5       ; ADD CHECK SUM
	
	clr.l	D6


common:

	bsr	GET_HEXS
	move.b	D1,D6
	add.b	D1,D5
	rol.l	#8,D6

	bsr	GET_HEXS
	move.b	D1,D6
	add.b	D1,D5

	
*	if its a flash address, offset addresses to RAM
*	and then flash to rom

	tst.b	D3
	bne	not_first
	
	* check is less than FCHIP1 addr
	* if yes, then is loading to ram
	cmpi.l	#FCHIP1,D6
	blo.s	is_in_ram_msg
	
	* loading to flash, check if not overwriting bootloader!
	cmpi.l	#(FCHIP1+FSA1),D6
	blo	panic_over_bl
	
	* writing to FLASH
	lea.l	load_message6,A0
	bsr	printstr
	
	move.l	D6,FIRST_ADDR
	move.l	D6,OFFSET
	subi.l	#$10000,OFFSET
	moveq	#2,D3	; 2=flash
	bra.s	not_first
is_in_ram_msg:
	lea.l	load_message5,A0
	bsr	printstr
	moveq	#1,D3	; 1=ram
not_first:

	cmpi.b	#2,D3
	*cmpi.l	#(FCHIP1+FSA1),D6
	bne	is_in_ram	; if D6 is less than its in ram = no offset
	sub.l	OFFSET,D6
is_in_ram:	

	movea.l	D6,A0
                         
READ_DATA:
	bsr	GET_HEXS
	add.b	D1,D5      ; ADD CHECK SUM

	move.b	D1,(A0)+

	addq.l	#1,D4      ; BUMP NUMBER OF BYTE RECEIVED
	dbf	D7,READ_DATA

	not.b	D5          ; ONE'S COMPLEMENT OF BYTE CHECK SUM         
	bsr	GET_HEXS      ; GET BYTE CHECK SUM

	CMP.B	D1,D5       ; COMPARE CHECK SUM
	BEQ.S	NO_ERROR

	ADDI.L	#$10000,D5  ; ADD 1 TO UPPER WORD
	MOVE.B	#'X',D0    ; IF NOT EQUAL SEND "X" FOR ERROR
	BRA	CHECKSUM_ERROR

NO_ERROR:
	MOVE.B	#'_',D0      ; "_" NO ERROR RECORD
CHECKSUM_ERROR:
	move.b	D0,(A6)

	bra	wait_srec




panic_over_bl:
	lea	panic_msg,A0
	bsr	printstr
	rts
	
	




*******************************************************************
*******************************************************************
*******************************************************************
*******************************************************************
************************ WRITE FLASH ******************************
*******************************************************************
*******************************************************************
*******************************************************************
*******************************************************************
WRITE_FLASH:
	MOVEM.L A5,-(SP)
	* SOURCE ADDR
	move.l	FIRST_ADDR,D1
	
	* check if not overwriting bootloader!
	cmpi.l	#(FCHIP1+FSA1),D1
	blo	panic_over_bl


_wrflash_blank:

	* nr of bytes
	* make this number odd and round up
	move.l	SIZE,D6
	addq.l	#1,D6
	andi.l	#$FFFFFFFE,D6
	move.l	FIRST_ADDR,A5

	* size in D6, addr in A5
	bsr	blank_check
	tst.b	D0
	beq	_wrflash_isblank
	
	suba.l	#2,A5
	
	* get sector for the non-blank address
	move.l	A5,A0
	bsr	get_sector
	
	* sector addr in A1
	move.l	A0,A1
	* chip address in A4
	move.l	A0,D0
	andi.l	#$F00000,D0
	move.l	D0,A4
	
	bsr	_erase_not_blank
	
	bra	_wrflash_blank
	



_wrflash_isblank:

	lea	is_blanked_msg,A0
	bsr	printstr

	* size in D2
	move.l	SIZE,D2
	addq.l	#1,D2
	andi.l	#$FFFFFFFE,D2

	* Flash contents always offseted to 0x10000
	
	lea	$10000,A0
	
	* unlock addresses in A4 and A5
	move.l	FIRST_ADDR,D0
	movea.l	D0,A1
	
	andi.l	#$F00000,D0
	
	lea	$554,A4
	lea	$AAA,A5
	adda.l	D0,A4
	adda.l	D0,A5

	


	* copy code to ram and execute from there
	movem.l	A0-A2,-(SP)
	lea	__wr_flash_code_start,A0
	lea	__wr_flash_code_end,A1
	lea	$1000,A2
__wr_flash_code_copy:
	move.w	(A0)+,(A2)+
	cmpa.l	A0,A1
	bne	__wr_flash_code_copy

	movem.l	(SP)+,A0-A2

	lea	$1000,A3
	jsr	(A3)

	bra	__wr_flash_code_end

***************************************************************
***************************************************************
__wr_flash_code_start:

	clr.l	D3
	
*	write a word in flash at addr A0 to addr A1 and increment regs
wr_fword:
	* skip if data = 0xFFFF
	move.w	(A0)+,D0
	cmpi.w	#$FFFF,D0
	beq	wr_fword2

	* unlock cycle
	move.w	#$00AA,(A5)
	move.w	#$0055,(A4)
	move.w	#$00A0,(A5)
	move.w	D0,(A1)

	andi.w	#$0080,D0
wr_fword1:
	move.w	(A1),D1
	andi.w	#$0080,D1
	cmp.w	D0,D1
	bne	wr_fword1
wr_fword2:
	adda.l	#2,A1
	
	
	addq.l	#2,D3
	cmpi.l	#1024,D3
	blo	_no_out_st
	clr.l	D3
	move.b	#'.',FTDI_DATA

_no_out_st:

	
	* update chip unlock addresses
	move.l	A1,D0
	andi.l	#$F00000,D0
	lea	$554,A4
	lea	$AAA,A5
	adda.l	D0,A4
	adda.l	D0,A5
	
	
	* -2 to size counter
	subi.l	#2,D2
	bne	wr_fword
	
	rts

__wr_flash_code_end:
***************************************************************
***************************************************************


	lea	verify_msg,A0
	bsr	printstr


	clr.l	D1

	* verify written stuff
	movea.l	FIRST_ADDR,A0
	lea	$10000,A1
	move.l	SIZE,D2
verify_next:
	cmp.b	(A0)+,(A1)+
	beq	verify_eq
	addq.l	#1,D1
verify_eq:
	subq.l	#1,D2
	bne	verify_next

	
	tst.l	D1
	bne	verify_err

	* verify ok
	lea	verify_ok_msg,A0
	bsr	printstr

	MOVEM.L (SP)+,A5
	RTS

verify_err:
	* verify error
	lea	verify_err_msg,A0
	bsr	printstr
	
	MOVEM.L (SP)+,A5
	RTS






















*	Converts a 2 hex char to number
*	Uses: D0, D1
*	Output: D1
GET_HEXS:
	bsr	CINS
	bsr	TO_HEX
	move.b	D0,D1
	rol.b	#4,D1
	*move.b	D1,D2
	bsr	CINS
	bsr	TO_HEX
	add.b	D0,D1
	rts
TO_HEX:
	subi.b	#$30,D0
	cmpi.b	#$A,D0
	bmi	ZERO_TO_NINE
	and.b	#%11011111,D0
	subi.b	#7,D0
ZERO_TO_NINE:
	*move.b	D0,D1
	rts






* reads a character from the ftdi
CINS:
	move.b	(A5),D0
	andi.b	#1,D0
	tst.b	D0
	bne	CINS
	move.b	(A6),D0
	rts


***************************
* prints a number in ascii
* Input: D0
PRINT_DEC:
	*MOVE.L D0,-(SP)  ; SAVE D0
          *MOVEA.L #$400,A5
	*BSR	HEX2DEC
          *MOVEA.L #$2000,A0
	*BSR	PUTSTR
	*MOVE.L (SP)+,D0 ; RESTORE D0
	*RTS

HEX2DEC  MOVEM.L D0-D7,-(SP)   ;SAVE REGISTERS
         MOVE.L  D0,D7               ;SAVE IT HERE
         BPL.S   HX2DC
         NEG.L   D7             ;CHANGE TO POSITIVE
         BMI.S   HX2DC57        ;SPECIAL CASE (-0)
         MOVE.B  #'-',(A6)     ;PUT IN NEG SIGN
HX2DC    CLR.W   D4             ;FOR ZERO SURPRESS
         MOVEQ.L   #10,D6         ;COUNTER
HX2DC0   MOVEQ.L   #1,D2          ;VALUE TO SUB
         MOVE.L  D6,D1          ;COUNTER
         SUBQ.L  #1,D1          ;ADJUST - FORM POWER OF TEN
         BEQ.S   HX2DC2         ;IF POWER IS ZERO
HX2DC1   MOVE.W  D2,D3          ;D3=LOWER WORD
         MULU.W    #10,D3
         SWAP.W    D2             ;D2=UPPER WORD
         MULU.W    #10,D2
         SWAP.W    D3             ;ADD UPPER TO UPPER
         ADD.W   D3,D2
         SWAP.W    D2             ;PUT UPPER IN UPPER
         SWAP.W    D3             ;PUT LOWER IN LOWER
         MOVE.W  D3,D2          ;D2=UPPER & LOWER
         SUBQ.L  #1,D1
         BNE     HX2DC1
HX2DC2   CLR.L   D0             ;HOLDS SUB AMT
HX2DC22  CMP.L   D2,D7
         BLT.S   HX2DC3         ;IF NO MORE SUB POSSIBLE
         ADDQ.L  #1,D0          ;BUMP SUBS
         SUB.L   D2,D7          ;COUNT DOWN BY POWERS OF TEN
         BRA.S   HX2DC22        ;DO MORE
HX2DC3   TST.B   D0             ;ANY VALUE?
         BNE.S   HX2DC4
         TST.W   D4             ;ZERO SURPRESS
         BEQ.S   HX2DC5
HX2DC4   ADDI.B  #$30,D0        ;BINARY TO ASCII
         MOVE.B  D0,(A6)       ;PUT IN BUFFER
         MOVE.B  D0,D4          ;MARK AS NON ZERO SURPRESS
HX2DC5   SUBQ.L  #1,D6          ;NEXT POWER
         BNE     HX2DC0
         TST.W   D4             ;SEE IF ANYTHING PRINTED
         BNE.S   HX2DC6
HX2DC57  MOVE.B  #'0',(A6)     ;PRINT AT LEST A ZERO
HX2DC6   *MOVE.B  #0,(A5)        ; PUT TERMINATOR
         MOVEM.L (SP)+,D0-D7   ;RESTORE REGISTERS
         RTS                    ;END OF ROUTINE




* read a character from the ftdi
rdchar:
	move.b	FTDI_STAT,D0
	btst	#0,D0
	bne	rdchar
	move.b	FTDI_DATA,D0
	rts




*	flush ftdi buffer
flush_ftdi:
	movem.l	A1-A2/D0,-(A7)
	lea	FTDI_DATA, A1
	lea	FTDI_STAT, A2
flush_ftdi2:
	move.b	(A1),D0
	move.b	(A2),D0
	andi.b	#1,D0
	beq	flush_ftdi2
	movem.l	(A7)+,A1-A2/D0
	rts


*	Print a null terminated string in A0
printstr:
	move.l	A1,-(A7)
	lea	FTDI_DATA, A1
printstr1:
	move.b	(A0)+,(A1)
	bne	printstr1
	move.l	(A7)+,A1
	rts





set_autoload_fpga:

	lea	bitset_msg,A0
	bsr	printstr
	
	move.w	FPGA_CONFIG,D0
	
	btst	#0,D0
	beq	set_autoload_fpga_1
	

	* unlock addresses in A4 and A5
	move.l	#FPGA_CONFIG,D0
	movea.l	D0,A1
	
	andi.l	#$F00000,D0
	
	lea	$554,A4
	lea	$AAA,A5
	adda.l	D0,A4
	adda.l	D0,A5
	

	* clear bit 0
	move.w	#$FFFE,D0
	
	
	* run the write code from ram
	lea	$1000,A6
	lea	set_autoload_fpga_wrcodestart,A2
	lea	set_autoload_fpga_wrcodeend,A3
set_autoload_fpga_copycode:	
	move.w	(A2)+,(A6)+
	cmpa.l	A2,A3
	bne	set_autoload_fpga_copycode
	
	lea	$1000,A0
	jsr	(A0)

	* skip already executed code
	bra	set_autoload_fpga_wrcodeend


	
set_autoload_fpga_wrcodestart:
	* unlock cycle
	move.w	#$00AA,(A5)
	move.w	#$0055,(A4)
	move.w	#$00A0,(A5)
	move.w	D0,(A1)


	andi.w	#$0080,D0
set_autoload_fpga2:
	move.w	(A1),D1
	andi.w	#$0080,D1
	cmp.w	D0,D1
	bne	set_autoload_fpga2


set_autoload_fpga_wrcodeend

	lea	done_msg,A0
	bsr	printstr
	rts
set_autoload_fpga_1:	
	lea	bitset_msg1,A0
	bsr	printstr
	rts





*************************************************************
** ERASE FLASH COMAND
** Always run in RAM to avoid lockups (erase flash chip
** where bootloader resides)
*************************************************************
erase_flash:
	* select flash msg
	lea	erase_msg,A0
	bsr	printstr
	
	* get flash chip nr
	bsr	rdchar
	
	cmpi.b	#'1',D0
	beq	erase_flash_1
	
	cmpi.b	#'2',D0
	beq	erase_flash_2
	
	cmpi.b	#'3',D0
	beq	erase_flash_3
	
	cmpi.b	#'4',D0
	beq	erase_flash_4

	* Invalid selection
	rts

erase_flash_1:
	* Base address in A1
	lea	$800000,A1
	bra	get_sector_nr

erase_flash_2:
	* Base address in A1
	lea	$900000,A1
	bra	get_sector_nr

erase_flash_3:
	* Base address in A1
	lea	$A00000,A1
	bra	get_sector_nr

erase_flash_4:
	* Base address in A1
	lea	$B00000,A1
	*bra	get_sector_nr



get_sector_nr:
	
	movea.l	A1,A4

	lea	erase_msg1,A0
	bsr	printstr
	
	bsr	rdchar
	
	cmpi.b	#'0',D0
	beq	_erase_sa0
	
	cmpi.b	#'1',D0
	beq	_erase_sa1
	
	cmpi.b	#'2',D0
	beq	_erase_sa2
	
	cmpi.b	#'3',D0
	beq	_erase_sa3
	
	cmpi.b	#'4',D0
	beq	_erase_sa4
	
	cmpi.b	#'5',D0
	beq	_erase_sa5
	
	cmpi.b	#'6',D0
	beq	_erase_sa6
	
	cmpi.b	#'7',D0
	beq	_erase_sa7
	
	cmpi.b	#'8',D0
	beq	_erase_sa8
	
	cmpi.b	#'9',D0
	beq	_erase_sa9
	
	cmpi.b	#'a',D0
	beq	_erase_sa10
	
	cmpi.b	#'b',D0
	beq	_erase_sa11
	
	cmpi.b	#'c',D0
	beq	_erase_sa12
	
	cmpi.b	#'d',D0
	beq	_erase_sa13
	
	cmpi.b	#'e',D0
	beq	_erase_sa14
	
	cmpi.b	#'f',D0
	beq	_erase_sa15
	
	cmpi.b	#'g',D0
	beq	_erase_sa16
	
	cmpi.b	#'h',D0
	beq	_erase_sa17
	
	cmpi.b	#'i',D0
	beq	_erase_sa18
	
	cmpi.b	#'j',D0
	beq	_erase_chip
	
	* Invalid selection
	rts


_erase_sa0:
	* In flash 1, need to avoid erasing bootloader (SA0)

	cmpa.l	#$800000,A1
	bne	_not_chip1

	lea	erase_msg2,A1
	bsr	printstr
	
	bsr	rdchar

	rts
_not_chip1:
	move.l	#FSA1,D7	
	bra	_erase_sec_now
	
_erase_sa1:
	move.l	#(FSA2-FSA1),D7
	adda.l	#FSA1,A1
	bra	_erase_sec_now

_erase_sa2:
	move.l	#(FSA3-FSA2),D7
	adda.l	#FSA2,A1
	bra	_erase_sec_now

_erase_sa3:
	move.l	#(FSA4_18-FSA3),D7
	adda.l	#FSA3,A1
	bra	_erase_sec_now

_erase_sa4:
	move.l	#FSA4_18,D7
	adda.l	#FSA4_18,A1
	bra	_erase_sec_now

_erase_sa5:
	move.l	#FSA4_18,D7
	lea	$20000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa6:
	move.l	#FSA4_18,D7
	lea	$30000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa7:
	move.l	#FSA4_18,D7
	lea	$40000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa8:
	move.l	#FSA4_18,D7
	lea	$50000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa9:
	move.l	#FSA4_18,D7
	lea	$60000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa10:
	move.l	#FSA4_18,D7
	lea	$70000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa11:
	move.l	#FSA4_18,D7
	lea	$80000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa12:
	move.l	#FSA4_18,D7
	lea	$90000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa13:
	move.l	#FSA4_18,D7
	lea	$A0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa14:
	move.l	#FSA4_18,D7
	lea	$B0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa15:
	move.l	#FSA4_18,D7
	lea	$C0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa16:
	move.l	#FSA4_18,D7
	lea	$D0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa17:
	move.l	#FSA4_18,D7
	lea	$E0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_sa18:
	move.l	#FSA4_18,D7
	lea	$F0000,A2
	adda.l	A2,A1
	bra	_erase_sec_now

_erase_chip:
	cmpa.l	#$800000,A1
	bne	_erase_chip_now
	
	lea	erase_msg3,A0
	bsr	printstr
	
	bsr	rdchar
	
	rts

_erase_sec_now:

	* check if blank
	movea.l	A1,A5
	move.l	D7,D6
	
	bsr	blank_check
	
	tst.l	D0
	bne	_erase_not_blank

	lea	erase_msg4,A0
	bsr	printstr

	bsr	rdchar
	
	rts

_erase_not_blank:
	movea.l	A4,A5
	add.l	#$AAA,A5

	movea.l	A4,A6
	add.l	#$554,A6



****************************
* copy code to ram and exec
****************************
	movem.l	A1-A2,-(SP)
	lea	__erase_sec_code,A0
	lea	__erase_sec_code_end,A1
	lea	$1000,A2
__erase_sec_code_copy:
	move.w	(A0)+,(A2)+
	cmpa.l	A0,A1
	bne	__erase_sec_code_copy

	movem.l	(SP)+,A1-A2
	lea	$1000,A0
	jsr	(A0)
****************************
****************************

	* skip already executed code
	bra	__erase_sec_code_end

__erase_sec_code:
	* erase commands
	move.w	#$00AA,(A5)
	move.w	#$0055,(A6)
	move.w	#$0080,(A5)
	move.w	#$00AA,(A5)
	move.w	#$0055,(A6)
	move.w	#$0030,(A1)

	move.l	#$FFFFF,D1

_wait_erase_finish:
	subi.l	#1,D1
	beq	_erase_timeout
	
	move.w	(A1),D0
	andi.w	#$0080,D0
	cmpi.w	#$0080,D0
	bne	_wait_erase_finish

	rts
__erase_sec_code_end:

	* check if blank after erasure
	movea.l	A1,A5
	move.l	D7,D6
	bsr	blank_check
	
	tst.l	D0
	beq	_erase_isblank

	* erase did not complete
	lea	erase_msg5,A0
	bsr	printstr

	*bsr	rdchar
	rts

_erase_isblank:
	* erase successfull
	lea	erase_msg6,A0
	bsr	printstr

	*bsr	rdchar
	rts


_erase_timeout:
	lea	erase_msg5,A0
	bsr	printstr
	lea	erase_msg7,A0
	bsr	printstr

	*bsr	rdchar
	rts



_erase_chip_now:

	rts



sdelay:
	subi.l	#1,D7
	bne	sdelay
	rts



program_fpga:
	
	lea	FPGA_ADDR,A2
	move.l	#FPGA_BITSIZE,D2
	
	lea	SYS_CTRL,A3
	lea	FTDI_DATA,A4
	
	* clear fpga config
	move.b	#0,(A3)

	*move.l	#100,D7
	*jsr	sdelay
	
	move.b	#1,(A3)

	move.l	#1000,D7
	jsr	sdelay


_wait_notbusy0:
	move.b	(A3),D0
	btst	#7,D0
	beq	_wait_notbusy0

_pgmfpga_loop:
	
	* send one byte of data
	move.b	(A1)+,(A2)
	*move.b	#'.',(A4)
	
_wait_notbusy1:
	move.b	(A3),D0
	btst	#7,D0
	beq	_wait_notbusy1

	subi.l	#1,D2
	bne	_pgmfpga_loop
	
	
	lea	fpgapgm_msg,A0
	bsr	printstr
	
	rts








* A5 = start address
* D6 = length
blank_check:
	clr.l	D0
	ror.l	#1,D6
_blank_check1:
	move.w	(A5)+,D1
	cmpi.w	#$FFFF,D1
	bne	_not_blank
	
	subi.l	#1,D6
	bne	_blank_check1

	rts
_not_blank:
	addi.l	#1,D0
	rts








*************************************************************************************
* Returns a sector address based on a random address
*
* Input:
*  A0: random address
* Output:
*  A0: sector address
*  D7: sector size
*
*************************************************************************************
get_sector:
	movem.l D0-D1,-(SP)

	* get chip address in D1
	move.l	A0,D1
	andi.l	#$F00000,D1

	* get sector in D0
	move.l	A0,D0
	andi.l	#$0FE000,D0
	cmpi.l	#FSA4_18,D0
	bhs	_get_sector_hi
	
	cmpi.l	#FSA1,D0
	blo	_get_sector_0
	
	cmpi.l	#FSA2,D0
	blo	_get_sector_1

	cmpi.l	#FSA3,D0
	blo	_get_sector_2

	* if it gets here then is sector 3
	move.l	#FSA3,D0
	move.l	#(FSA4_18-FSA3),D7
	bra	get_sector_done

_get_sector_0:
	clr.l	D0
	move.l	#FSA1,D7
	bra	get_sector_done

_get_sector_1:
	move.l	#FSA1,D0
	move.l	#(FSA2-FSA1),D7
	bra	get_sector_done

_get_sector_2:
	move.l	#FSA2,D0
	move.l	#(FSA3-FSA2),D7
	bra	get_sector_done
	
_get_sector_hi:
	move.l	#FSA4_18,D7
	andi.l	#$0F0000,D0
get_sector_done:
	add.l	D0,D1
	movea.l	D1,A0
	movem.l (SP)+,D0-D1
	rts








done_msg	dc.b	10,13,'Done!',10,13,0

boot_message1	dc.b	10,13,'Alcetronics M68K v0.3 (2012)',10,13,'Booting in 3...',10,13,0
boot_message2	dc.b	'Booting...',10,13,0

fpgapgm_msg	dc.b	10,13,'FPGA bitstream sent.',10,13,0

bitset_msg	dc.b	10,13,'Setting FPGA autoload bit.',10,13,0
bitset_msg1	dc.b	10,13,'Autoload bit already set!',10,13,0

erase_msg	dc.b	10,13,'Select FLASH chip [1-4]',0
erase_msg1	dc.b	10,13,'Select FLASH sector:',10,13
		dc.b	'0 - SA0  - 16kB',10,13
		dc.b	'1 - SA1  - 8kB',10,13
		dc.b	'2 - SA2  - 8kB',10,13
		dc.b	'3 - SA3  - 32kB',10,13
		dc.b	'4 - SA4  - 64kB',10,13
		dc.b	'5 - SA5  - 64kB',10,13
		dc.b	'6 - SA6  - 64kB',10,13
		dc.b	'7 - SA7  - 64kB',10,13
		dc.b	'8 - SA8  - 64kB',10,13
		dc.b	'9 - SA9  - 64kB',10,13
		dc.b	'A - SA10 - 64kB',10,13
		dc.b	'B - SA11 - 64kB',10,13
		dc.b	'C - SA12 - 64kB',10,13
		dc.b	'D - SA13 - 64kB',10,13
		dc.b	'E - SA14 - 64kB',10,13
		dc.b	'F - SA15 - 64kB',10,13
		dc.b	'G - SA16 - 64kB',10,13
		dc.b	'H - SA17 - 64kB',10,13
		dc.b	'I - SA18 - 64kB',10,13
		dc.b	'J - Full chip erase',10,13,0
		
erase_msg2	dc.b	'Cannot erase SA0 in FLASH chip...',10,13,0
erase_msg3	dc.b	'Cannot erase FLASH chip...',10,13,0
erase_msg4	dc.b	'Sector already blank...',10,13,0
erase_msg5	dc.b	'Sector did NOT erase!',10,13,0
erase_msg6	dc.b	'Sector erased.',10,13,0
erase_msg7	dc.b	'Timeout waiting for erase completion!',10,13,0


load_srec_msg	dc.b	'Waiting for S-Record file...',10,13,0


load_message5	dc.b	'Loading to RAM...',10,13,0
load_message6	dc.b	'Loading to FLASH...',10,13,0

load_message7	dc.b	10,13,'Load finished. ',0
load_message8	dc.b	' bytes, ',0
load_message9	dc.b	' errors',10,13,0

panic_msg	dc.b	10,13,'Error: overlaping bootloader!',10,13
panic_msg2	dc.b	10,13,'Error: image too big!',10,13
panic_msg3	dc.b	10,13,'Error: image not aligned to a 8Kb address!',10,13



menu_msg	dc.b	10,13,10,13,'-----------------------------'
		dc.b    10,13,'Memory options:'
		dc.b	10,13,' 1 - Load S-Record'
		dc.b	10,13,' 2 - Load BIN to RAM'
		dc.b	10,13,' 3 - Load BIN to FLASH'
		dc.b	10,13,' 4 - Erase FLASH',10,13
		dc.b	10,13,'FPGA options'
		dc.b	10,13,' 5 - Load S-Record to FPGA'
		dc.b	10,13,' 6 - Load S-Record to FLASH'
		dc.b	10,13,' 7 - Program with FLASH contents'
		dc.b	10,13,' 8 - Set FPGA autoload bit',10,13
		dc.b	10,13,'Utilities'
		dc.b	10,13,' 9 - Boot Tutor @ 0x804000'
		dc.b	10,13,' a - Boot Flash @ 0x810000'
		
		
		dc.b	10,13,10,13,'?',0


verify_ok_msg	dc.b	10,13,'Verify OK',10,13,0
verify_err_msg	dc.b	10,13,'Verify ERROR!',10,13,0



lbin_addr_msg	dc.b	10,13,'Start address: ',0
lbin_size_msg	dc.b	10,13,'Size: ',0
bytes_msg	dc.b	' bytes',0

is_blanked_msg	dc.b	10,13,'Erased. Programming now.',0
verify_msg	dc.b	10,13,'Programmed. Verifying now.',0

END:

	org	FCHIP1+FSA4_18
FLASH_START_:
	
	

	END	START
















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
