*-----------------------------------------------------------
* Program    : bootloader
* Written by : ljalvs@gmail.com
* Date       : 2012.01.27
* Description: bootloader for the 68000
*-----------------------------------------------------------

FLASH     EQU $100500

FTDI_DATA EQU $200000
FTDI_STAT EQU $200001

DELAY     EQU $BFFFF

ESC       EQU $1B


MAGIC	EQU	$450
ST_VEC	EQU	$454
SIZE	EQU	$458
FSTART	EQU	$45C
FLAG	EQU	$460


*	ROM START ADDR
	ORG	$00100000

*	SSP ADDR
	DC.L	$00000500
*	BOOT JUMP ADDR
	DC.L	$00100008

START:

****************************
*	bootloader start
****************************

* copy booloader to ram
* execute from there to be able to write the flash

	
	lea	boot_real_start,A0
	lea	0,A1
	move.l	#(END-boot_real_start),D0
	clr.l	D1
copy_me:
	move.w	(A0)+,(A1)+
	addi.l	#1,D1
	cmp.l	D0,D1
	bls	copy_me
	nop
	jmp	$0


boot_real_start:

	lea.l	FTDI_STAT, A5
	lea.l	FTDI_DATA, A6


flush:
*	flush ftdi buffer
	move.b	(A6),D0
	nop
	nop
	nop
	nop
	move.b	(A5),D0
	btst	#0,D0
	beq	flush

*	Display boot message
	lea	boot_message1,A0
	bsr	PUTSTR

	
*	wait around 3 sec for a key press
	move.l	#DELAY,D0
waitboot:
	move.b	(A5),D1
	btst	#0, D1
	beq	loader

	sub.l	#1,D0
	bne	waitboot

*	No key pressed
*	Start program in flash
	lea	boot_message2,A0
	bsr	PUTSTR
	
*	check magic nuumber
	move.l	MAGIC,D0
	cmpi.l	#$CACABABA,D0
	bne	go_flash
	
	move.l	ST_VEC,D0
	movea.l	D0,A0
	jmp	(A0)

go_flash:	
	jmp	FLASH_START
	
	

*	Key pressed, start loader & flasher
loader:	
	lea	load_message1,A0
	bsr	PUTSTR

flush3:
*	flush ftdi buffer
	move.b	(A6),D0
	nop
	nop
	nop
	nop
	move.b	(A5),D0
	andi.b	#1,D0
	cmpi.b	#1,D0
	bne	flush3
	

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
	bsr	PUTSTR
	
	move.l	D4,SIZE
	move.l	D4,D0
	BSR	PRINT_DEC     ; SHOW NUMBER OF BYTE RECEIVED

	lea	load_message8,A0
	bsr	PUTSTR

	SWAP.W D5
	CLR.L D0
	MOVE.W D5,D0
	BSR PRINT_DEC

	lea	load_message9,A0
	bsr	PUTSTR



flush2:
*	flush ftdi buffer
	move.b	(A6),D0
	nop
	nop
	nop
	nop
	
	move.b	(A5),D0
	btst	#0,D0
	beq	flush2


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
	
	cmpi.l	#FLASH,D6
	blo.s	is_in_ram_msg
	lea.l	load_message6,A0
	bsr	PUTSTR
	move.l	D6,FSTART
	moveq	#2,D3	; 2=flash
	bra.s	not_first
is_in_ram_msg:
	lea.l	load_message5,A0
	bsr	PUTSTR
	moveq	#1,D3	; 1=ram
not_first:
	cmpi.l	#FLASH,D6
	blo.s	is_in_ram	; if D6 is less than its in ram = no offset

	subi.l	#$100000,D6
	
is_in_ram:	
	movea.l	D6,A0
                         
READ_DATA:
	bsr	GET_HEXS
	add.b	D1,D5      ; ADD CHECK SUM
	move.b	D1,(A0)+

	*not.b	D1          ; complement before sending
	*MOVE.B D1,DOUT.L  ; INDICATOR WHILE LOADING

	addq.l	#1,D4      ; BUMP NUMBER OF BYTE RECEIVED
	dbf	D7,READ_DATA

	not.b	D5          ; ONE'S COMPLEMENT OF BYTE CHECK SUM         
	bsr	GET_HEXS      ; GET BYTE CHECK SUM

	CMP.B	D1,D5       ; COMPARE CHECK SUM
	BEQ.S	NO_ERROR

	ADD.L	#$10000,D5  ; ADD 1 TO UPPER WORD
	MOVE.B	#'X',D0    ; IF NOT EQUAL SEND "X" FOR ERROR
	BRA	CHECKSUM_ERROR

NO_ERROR:
	MOVE.B	#'_',D0      ; "_" NO ERROR RECORD
CHECKSUM_ERROR:
	move.b	D0,(A6)

	bra	wait_srec








WRITE_FLASH:
	MOVEM.L A5,-(SP)
	* SOURCE ADDR
	move.l	FSTART,D0
	
	* check if not overwriting bootloader!
	cmpi.l	#FLASH,D0
	bge	no_panic
	

	lea.l	panic_msg,A0
	bsr	PUTSTR
panic:
	bra	panic
	
	
no_panic:
		
	* nr of bytes
	move.l	SIZE,D2
	clr.l	d4

	* flash start addr
	movea.l	D0,A1
	movea.l	D0,A3

	* source addr
	subi.l	#$100000,D0
	
	movea.l	D0,A0
	movea.l	D0,A2



	* SOFT UNPROTECT ADDRS
	MOVEA.L	#$10AAAA, A5
	MOVEA.L	#$105554, A4
S1:

	* AA -> $5555
	MOVE.W	#$AAAA,(A5)

	* 55 -> $2AAA
	MOVE.W	#$5555,(A4)

	* A0 -> $5555
	MOVE.W	#$A0A0,(A5)


	
	*MOVE.B	#'W',$200000
	
	* WRITE PAGE (128 BYTES * 2)
	MOVE.B	#0, D1
LOOPZ:
	MOVE.W	(A0)+, (A1)+
	ADDQ	#1,D1
	NOP
	CMP.B	#128,D1
	BNE	LOOPZ
	

	*MOVE.B	#'S',$200000


	* WAIT 10ms
	MOVE.L	#$FFF, D0
LOOP2Z:
	SUB.L	#1, D0
	CMP.L	#0, D0
	BNE	LOOP2Z
	


	*MOVE.B	#'V',$200000

	* VERIFY PAGE (128 BYTES * 2)
	MOVE.B	#0, D1
	CLR.b	D3
LOOP3Z:
	CMP.W	(A2)+, (A3)+
	BEQ	GOOD
	ADDQ.b	#1,D3
GOOD:

	ADDQ.b	#1,D1
	CMP.B	#128,D1
	BNE	LOOP3Z
	

	tst.b	D3
	BEQ	GOOD2
	
	MOVE.B	#'x',(A6)
	BRA	BAD
GOOD2:
	MOVE.B	#'_',(A6)
BAD:
	
	addi.l	#256,D4
	
	
	cmp.l	#$180000,A1
	bge	panic2
	
	
	cmp.l	D2,D4
	BLO	S1
	
	
	
	

	MOVE.B	#'.',(A6)
	
	MOVEM.L (SP)+,A5
	RTS

panic2:
	lea.l	panic_msg2,A0
	bsr	PUTSTR

panic3:
	bra.s	panic3








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





*	Print a null terminated string in A0
PUTSTR:
	move.b	(A0)+,(A6)
	bne	PUTSTR
	rts


boot_message1	dc.b	10,13,'68000 bootloader v0.2 (2012)',10,13,'Booting in 3...',10,13,0
boot_message2	dc.b	'Booting...',10,13,0

load_message1	dc.b	'Entering loader...',10,13
load_message2	dc.b	'Waiting for S-Record file...',10,13,0


load_message5	dc.b	'Loading to RAM...',10,13,0
load_message6	dc.b	'Loading to FLASH...',10,13,0

load_message7	dc.b	10,13,'Load finished. ',0
load_message8	dc.b	' bytes, ',0
load_message9	dc.b	' errors',10,13,0

panic_msg	dc.b	10,13,'Error: overlaping bootloader!',10,13
panic_msg2	dc.b	10,13,'Error: image too big!',10,13

END:

	org	FLASH
FLASH_START:
	
	

	END	START




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
