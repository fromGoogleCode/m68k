*-----------------------------------------------------------
* Program    : bootloader writer
* Written by : Luis Alves (ljalvs@gmail.com)
* Date       : 2012.01.27
* Description: Writes the bootloader to the flash
*
* This program is baddly written and badly organized.
* Its only purpose is to write the bootloader to the flash.
*
*-----------------------------------------------------------




* write ram from $100000 to first sector @ $800000
* write len = $4000
*
*
*
*

ESC     EQU $1B
CR      EQU 13
LF      EQU 10
SP      EQU 32
BS      EQU 8
RS      EQU $1E




	ORG	$1000
START:				; first instruction of program

	MOVEA.L	#$E00000, A4
*	MOVEA.L	#$200001, A1



	BSR	READ_S_REC
	BSR	WR_FLASH

enda:
	bra	enda




READC:

	MOVE.B	(A1), D0
	AND.B	#1, D0
	CMP.B	#1, D0
	BEQ	READC
	
	MOVE.B	(A0), D0
	
	RTS
	




INCHNE:
	MOVE.B	1(A0),D1
	ANDI.B	#$1,D1
	BNE.S   INCHNE
	MOVE.B  (A0),D0
	RTS



OUTCH:
	MOVE.B	1(A0),D1
	ANDI.B	#$2,D1
	BNE.S   OUTCH
	MOVE.B  D0,(A0)
	RTS








COUT	MOVE.B	2(A4),D1
	ANDI.B	#$2,D1
	BNE.S   COUT
	
	*BTST.B #TDRE,ACIAC.L
        *  BEQ.S  COUT
        *  MOVE.B D0,ACIAD.L
        MOVE.B  D0,(A4)
	RTS


CINS      
	MOVE.B	2(A4),D1
	ANDI.B	#$1,D1
	BNE.S   CINS
	MOVE.B  (A4),D0


	*BTST.B #RDRF,ACIAC.L
         * BEQ.S  CINS
         * MOVE.B ACIAD.L,D0
          RTS


CIN      MOVE.B	2(A4),D1
	ANDI.B	#$1,D1
	BNE.S   CIN
	MOVE.B  (A4),D0

	*BTST.B #RDRF,ACIAC.L
        * BEQ.S  CIN
        * MOVE.B ACIAD.L,D0
         BSR COUT
         RTS

; A3 POINTED TO FIRST BYTE
; END WITH 0

PSTR     MOVE.B (A3)+,D0
         CMP.B  #0,D0
         BEQ.S PSTR1
         BSR COUT
         BRA.S PSTR

PSTR1    RTS


NEW_LINE MOVE.L D0,-(SP)
         MOVE.B #CR,D0
         BSR COUT
         MOVE.B #LF,D0
         BSR COUT
         MOVE.L (SP)+,D0
         RTS




PRINT_DEC MOVE.L D0,-(SP)  ; SAVE D0
          MOVEA.L #$2000,A5
          *ADDA.L #BUFFER,A5
          BSR HEX2DEC
          MOVEA.L #$2000,A3
          *ADDA.L #BUFFER,A3
          BSR PSTR
          MOVE.L (SP)+,D0 ; RESTORE D0
          RTS

HEX2DEC  MOVEM.L D1-D7,-(SP)   ;SAVE REGISTERS
         MOVE.L  D0,D7               ;SAVE IT HERE
         BPL.S   HX2DC
         NEG.L   D7             ;CHANGE TO POSITIVE
         BMI.S   HX2DC57        ;SPECIAL CASE (-0)
         MOVE.B  #'-',(A5)+     ;PUT IN NEG SIGN
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
         MOVE.B  D0,(A5)+       ;PUT IN BUFFER
         MOVE.B  D0,D4          ;MARK AS NON ZERO SURPRESS
HX2DC5   SUBQ.L  #1,D6          ;NEXT POWER
         BNE     HX2DC0
         TST.W   D4             ;SEE IF ANYTHING PRINTED
         BNE.S   HX2DC6
HX2DC57  MOVE.B  #'0',(A5)+     ;PRINT AT LEST A ZERO
HX2DC6   MOVE.B  #0,(A5)        ; PUT TERMINATOR
         MOVEM.L (SP)+,D1-D7   ;RESTORE REGISTERS
         RTS                    ;END OF ROUTINE

GET_HEXS   BSR CINS
         BSR TO_HEX
         ROL.B #4,D1
         MOVE.B D1,D2
         BSR CINS
         BSR TO_HEX
         ADD.B D2,D1
         RTS


TO_HEX SUBI.B #$30,D0
       CMPI.B #$A,D0
       BMI  ZERO_TO_NINE
       AND.B #%11011111,D0
       SUBI.B #7,D0

ZERO_TO_NINE

       MOVE.B D0,D1

        RTS












READ_S_REC      LEA.L LOAD.L,A3
                BSR PSTR
                CLR.L D4     ; CLEAR NUMBER OF BYTE 
                CLR.L D5     ; CLEAR CHECK SUM AND ERROR BYTE

READ_S_REC1     BSR CINS
                CMP.B #'S',D0
                BNE.S CHECK_ESC
                BRA.S GET_TYPE


CHECK_ESC       CMP.B #ESC,D0
                BNE.S READ_S_REC1

                RTS


GET_TYPE        BSR CINS
                CMP.B #'8',D0
                BNE CHECK_START

WAIT_CR         BSR CINS
                CMP.B #CR,D0
                BNE.S WAIT_CR

                BSR NEW_LINE
                BSR NEW_LINE
                MOVE.L D4,D0
                BSR PRINT_DEC     ; SHOW NUMBER OF BYTE RECEIVED
                MOVEA.L #NUMBER,A3
                BSR PSTR

                SWAP.W D5
                CLR.L D0
                MOVE.W D5,D0
                BSR PRINT_DEC
                MOVEA.L #ERROR,A3
                BSR PSTR
                RTS


CHECK_START     CMP.B #'2',D0
                BEQ.S START_FOUND

                CMP.B #'0',D0
                BEQ.S READ_S_REC1
                BRA.S READ_S_REC1


START_FOUND     CLR.W D5          ; CLEAR BYTE CHECK SUM

                BSR GET_HEXS
                CLR.L D7
                MOVE.B D1,D7       ; NUMBER OF BYTE SAVED TO D7
                SUBQ.B #5,D7
                MOVE.L D7,D0

                ADD.B  D1,D5       ; ADD CHECK SUM

; GET 24-BIT ADDRESS, SAVE TO A6

              CLR.L D6
              BSR GET_HEXS
              MOVE.B D1,D6
              ADD.B  D1,D5

              ROL.L #8,D6
              BSR GET_HEXS
              MOVE.B D1,D6
              ADD.B D1,D5

              ROL.L #8,D6

              BSR GET_HEXS
              MOVE.B D1,D6
              ADD.B D1,D5


	subi.l	#($800000-$100000),D6
	
              MOVEA.L D6,A6
                         
READ_DATA     BSR GET_HEXS
              ADD.B  D1,D5      ; ADD CHECK SUM
              MOVE.B D1,(A6)+

              not.b d1          ; complement before sending

              *MOVE.B D1,DOUT.L  ; INDICATOR WHILE LOADING

              ADDQ.L #1,D4      ; BUMP NUMBER OF BYTE RECEIVED
              DBF D7,READ_DATA

              NOT.B D5          ; ONE'S COMPLEMENT OF BYTE CHECK SUM         

              BSR GET_HEXS      ; GET BYTE CHECK SUM

              CMP.B D1,D5       ; COMPARE CHECK SUM
              BEQ.S NO_ERROR

              ADD.L #$10000,D5  ; ADD 1 TO UPPER WORD
              MOVE.B #'X',D0    ; IF NOT EQUAL SEND "X" FOR ERROR
              BRA CHECKSUM_ERROR

NO_ERROR      MOVE.B #'_',D0      ; "_" NO ERROR RECORD
CHECKSUM_ERROR BSR COUT

              BRA READ_S_REC1


LOOP_BACK     BSR CIN
              CMP.B #10,D0
              BNE LOOP_BACK
              RTS

















WR_FLASH:

	move.b	#'1',$E00000

	* check if blank
	movea.l	#$800000,A0
	movea.l	#$804000,A1
	bsr	f_blank
	cmpi.b	#1,D1
	beq	is_blank
	
	* erase sector
	
	move.b	#'2',$E00000

	bsr	f_erase
	
	move.b	#'3',$E00000
	
	
is_blank:



	* SOURCE ADDR
	MOVEA.L	#$100000, A0
	MOVEA.L	#$100000, A5
	* DESTINATION ADDR
	MOVEA.L	#$800000, A1
	MOVEA.L	#$800000, A6
	* FLASH END
	*MOVEA.L	#$80000, D4



	move.L	#0,D2
	
	
fwr_loop:
	bsr	wr_fword
	addi.l	#1,D2


	cmpi.l	#128,D2
	bne	no_print_info
	move.b	#'w',$E00000
	move.L	#0,D2
no_print_info:
	
		
	CMPA.L	#$104000,A0
	BNE	fwr_loop

	MOVE.B	#'E',$E00000

	
	RTS
	






*	check addres from A0 to A1 if flash is blank
*	return 0 if not blank, 1 if blank
f_blank:
	move.b	#1,D1
next_blank:
	move.w	(A0)+,D0
	cmpi.w	#$FFFF,D0
	bne	not_blank
	cmpa.l	A0,A1
	bne	next_blank
	rts
not_blank:
	clr.b	D1
	rts
	


*	erase flash sector
f_erase:

	move.w	#$00AA,$800AAA
	move.w	#$0055,$800554
	move.w	#$0080,$800AAA

	move.w	#$00AA,$800AAA
	move.w	#$0055,$800554
	move.w	#$0030,$800000

f_erase1:
	move.w	$800000,D0
	andi.w	#$0080,D0
	cmpi.w	#$0080,D0
	bne	f_erase1

	rts




*	write a word in flash at addr A0 to addr A1 and increment regs
wr_fword:
	* unlock cycle
	move.w	(A0)+,D0
	
	cmpi.w	#$FFFF,D0
	bne	wr_fword0
	adda.l	#2,A1
	rts
	
wr_fword0:
	move.w	#$00AA,$800AAA
	move.w	#$0055,$800554
	move.w	#$00A0,$800AAA
	move.w	D0,(A1)

	andi.w	#$0080,D0
wr_fword1:
	move.w	(A1),D1
	andi.w	#$0080,D1
	cmp.w	D0,D1
	bne	wr_fword1
	adda.l	#2,A1
	rts

	
	






* Variables and Strings

ERROR	DC.B ' records checksum error',13,10,0
LOAD	DC.B 'Send bootloader now...',13,10,0
NUMBER	DC.B ' bytes loaded, ',0
	END	START		; last line of source











*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
