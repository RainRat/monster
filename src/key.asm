.include "macros.inc"
.include "zeropage.inc"

;******************************************************************************
; CONSTANTS
UNSHIFTED_KEY_TABLE = $ec5e
SHIFTED_KEY_TABLE   = $ec9f
CBM_KEY_TABLE       = $ece0
CTRL_KEY_TABLE      = $eda3
CURSOR_LR_MASK      = 2

REPEAT_TIME1 = 8	; time after 1st keypress to repeat
REPEAT_TIME2  = 1	; time after successive repeats to repeat

.CODE

;******************************************************************************
; GETCH
; Gets a key from the keyboard and returns it
; OUT:
;  - .A: the key code of the pressed key or 0 if no key is pressed
.export __key_getch
.proc __key_getch
@x=zp::tmpe
	jsr Keyboard
	pha


	; restore DDR
	lda #$00
	sta $9112
	lda #$80
	sta $9113

	lda rep_counter
	beq :+
	dec rep_counter
	bne :+
	lda #$00
	sta BufferOld
	sta BufferOld+1
	sta BufferOld+2
	lda #REPEAT_TIME2
	sta rep_counter

:	pla

	bcs @nokey
	cmp #$ff
	beq @nokey
	cmp #$0d
	bcc @nokey

	cmp #$8d	; treat SHIFT+RETURN as RETURN
	bne :+
	lda #$0d
:	cmp #$94	; treat SHIFT+DEL as DEL
	bne :+
	lda #$14
:	cmp #' '

@chkupper:
	bcc @ccodes
	cmp #$da+1	; > 'Z'
	bcs @ret
	cmp #$c1	; bcc @lower
	bcc @chklower
@upper: eor #$80	; convert to uppercase
	cmp #$00
	rts

@chklower:
	cmp #$5a+1	; > 'z'
	bcs @ret
	cmp #$41	; < 'a'
	bcc @ret
	ora #$20	; convert to lowercase
@ret:	cmp #$00
	rts

@ccodes:
	cmp #$0d
	beq @done
	cmp #$14
	beq @done
	cmp #$1d
	beq @done
	cmp #$9d
	beq @done
	cmp #$11
	beq @done
	cmp #$91
	beq @done
@nokey:	lda #$00
	rts
@done:	cmp #$00	; flag key pressed
	rts
.endproc

;******************************************************************************_
; ISHEX
; Returns .C set if the given key is 0-9 or A-F
; IN:
;  - .A: the key to check if is hex
; OUT:
;  - .C: set if the given key is 0-9 or A-F
.export __key_ishex
.proc __key_ishex
	cmp #'0'
	bcc @nothex
	cmp #'f'+1
	bcs @nothex
	cmp #'a'
	bcs @done
	cmp #'9'+1
	bcs @nothex
	sec
	rts
@nothex:
	clc
@done:	rts
.endproc

;******************************************************************************_
; ISDEC
; Returns .C set if the given key is 0-9
; IN:
;  - .A: the key to check if is hex
; OUT:
;  - .C: set if the given key is 0-9
.export __key_isdec
.proc __key_isdec
	cmp #'0'
	bcc @notdec
	cmp #'9'+1
	bcs @notdec
	sec
	rts
@notdec:
	clc
@done:	rts
.endproc


;******************************************************************************_
; SHIFT_DOWN
; OUT:
;  - .C: set if the SHIFT key is down
.proc shift_down
	pha
	lda NonAlphaFlagX
	and #$40
	bne @down
	lda NonAlphaFlagY
	and #$40
	bne @down
	clc
	skb
@down:	sec
	pla
	rts
.endproc

;******************************************************************************_
; CBM_DOWN
; OUT:
;  - .C: set if the CBM key is down
.proc cbm_down
	pha
	lda NonAlphaFlagX
	and #$04
	bne @done
	clc
	skb
@done:	sec
	pla
	rts
.endproc

;------------------------------------------------------------------------------
; keyboard routine adapted from code by TWW/Creators

;        +================================================================================
;        |                             Return in X-Register                              |
;        +=========+=========+=========+=========+=========+=========+=========+=========+
;        |  Bit 7  |  Bit 6  |  Bit 5  |  Bit 4  |  Bit 3  |  Bit 2  |  Bit 1  |  Bit 0  |
;        +---------+---------+---------+---------+---------+---------+---------+---------+
;        | CRSR UD |   F5    |   F3    |   F1    |   F7    | CRSR RL | RETURN  |INST/DEL |
;        +---------+---------+---------+---------+---------+---------+---------+---------+
;
;        +================================================================================
;        |                             Return in Y-Register                              |
;        +=========+=========+=========+=========+=========+=========+=========+=========+
;        |  Bit 7  |  Bit 6  |  Bit 5  |  Bit 4  |  Bit 3  |  Bit 2  |  Bit 1  |  Bit 0  |
;        +---------+---------+---------+---------+---------+---------+---------+---------+
;        |RUN STOP | L-SHIFT |   C=    | R-SHIFT |CLR/HOME |  CTRL   |         |         |
;        +---------+---------+---------+---------+---------+---------+---------+---------+
;
;------------------------------------------------------------------------------
ScanResult       = $50
BufferNew        = $58
KeyQuantity      = $5b
NonAlphaFlagX    = $5c
NonAlphaFlagY    = $5d
TempZP           = $5e
SimultaneousKeys = $5f

MaxKeyRollover = 3

KeyInRow:
	lsr
	bcs *+5
	jsr KeyFound
.repeat 7, I
	inx
	lsr
	bcs *+5
	jsr KeyFound
.endrepeat
rts

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Routine for handling: Key Found
KeyFound:
	stx TempZP
	dec KeyQuantity
	bmi OverFlow
	jsr shift_down
	bcc :+
	ldy SHIFTED_KEY_TABLE,x
	bcs @store
:	jsr cbm_down
	bcc :+
	ldy CBM_KEY_TABLE,x
	bcs @store
:	ldy UNSHIFTED_KEY_TABLE,x
@store: ldx KeyQuantity
	sty BufferNew,x
	ldx TempZP
	rts

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Routine for handling: Overflow
OverFlow:
	pla  ; Dirty hack to handle 2 layers of JSR
	pla
	pla
	pla
	; Don't manipulate last legal buffer as the routine will fix itself once it gets valid input again.
	lda #$03
	sec
	rts

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Exit Routine for: No Activity
NoActivityDetected:
	; Exit With A = #$01, Carry Set & Reset BufferOld.
	lda #$00
	sta SimultaneousAlphanumericKeysFlag  ; Clear the too many keys flag once a "no activity" state is detected.
	stx BufferOld
	stx BufferOld+1
	stx BufferOld+2
	sec
	lda #$01
	rts

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Configure Data Direction Registers
Keyboard:
	ldx #$ff
	stx $9113       ; Port A - Output
	ldy #$00
	sty $9112       ; Port B - Input

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Check for Port Activity
	sty $9120       ; Connect all Keyboard Rows
	cpx $9121
	beq NoActivityDetected

	lda SimultaneousAlphanumericKeysFlag
	beq ScanMatrix
	; Waiting for all keys to be released before accepting new input.
	lda #$05
	sec
	rts

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Scan Keyboard Matrix
ScanMatrix:
	lda #%01111111
	sta $9120
	ldy $9121
	sty ScanResult+7
	sec
.repeat 7, I
	ror
	sta $9120
	ldy $9121
	sty ScanResult+6-I
.endrepeat

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Initialize Buffer, Flags and Max Keys
	; Reset current read buffer
	stx BufferNew
	stx BufferNew+1
	stx BufferNew+2

	; Reset Non-AlphaNumeric Flag
	inx
	stx NonAlphaFlagY

	; Set max keys allowed before ignoring result
	lda #MaxKeyRollover
	sta KeyQuantity

	; Counter to check for simultaneous alphanumeric key-presses
	lda #$fe
	sta SimultaneousKeys

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Check and flag Non Alphanumeric Keys
; values to return in .X and .Y
;
; y register result:
;  7  6       5       4    3   2    1     0
; |x|LEFT-SHIFT|STOP|CTRL|U/D|R/L|RETURN|DEL
; x register result:
;   7     6       5   4   3  2   1  0
; |F1|RIGHT-SHIFT|F7|HOME|x|CBM|F5|F3|
;
	; TODO: adjust for Vic matrix
	lda ScanResult+0
	eor #$ff
	and #%10000000	; DEL
	asl
	rol		; move to bit 0
	sta NonAlphaFlagY

	lda ScanResult+1
	eor #$ff
	and #%10000000	; RETURN
	asl
	rol
	rol		; move to bit 1
	ora NonAlphaFlagY
	sta NonAlphaFlagY

	lda ScanResult+2
	eor #$ff
	and #%10000001	; cursor r/l, CTRL
	asl
	rol
	rol
	rol		; move to bits 2 (cur) and 4 (CTRL)
	ora NonAlphaFlagY
	sta NonAlphaFlagY

	lda ScanResult+3
	eor #$ff
	and #%10000011	; cursor down, left shift, STP
	asl
	rol
	rol
	rol
	rol		; move to bits 3 (up/dn), 5 (STP) and 6 (LSH)
	ora NonAlphaFlagY
	sta NonAlphaFlagY

	lda ScanResult+4
	eor #$ff
	and #%11000000     ; F1, right shift
	sta NonAlphaFlagX

	lda ScanResult+5
	eor #$ff
	and #%10000001     ; F3, CBM
	asl
	rol		   ; F3 (bit 0), CBM (bit 2)
	ora NonAlphaFlagX
	sta NonAlphaFlagX

	lda ScanResult+6
	eor #$ff
	and #%10000000     ; F5
	asl
	rol		   ; move F5 to bit 1
	ora NonAlphaFlagX
	sta NonAlphaFlagX

	lda ScanResult+7
	eor #$ff
	and #%11000000     ; F7, HOME
	lsr
	lsr		   ; F7 to bit 5, HOME to bit 4
	ora NonAlphaFlagX
	sta NonAlphaFlagX

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Check for pressed key(s)
	lda ScanResult
	cmp #$ff
	beq *+5
	jsr KeyInRow
.repeat 7, I
	ldx #(I+1)*8
	lda ScanResult+I+1
	beq *+5
	jsr KeyInRow
.endrepeat

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Key Scan Completed
; Put any new key (not in old scan) into buffer
	ldx #MaxKeyRollover-1
ScanLoop:
	lda BufferNew,x
	cmp #$ff
	beq Exist        ; Handle 'null' values
	cmp BufferOld
	beq Exist
	cmp BufferOld+1
	beq Exist
	cmp BufferOld+2
	beq Exist
	; New Key Detected
	inc BufferQuantity
	ldy BufferQuantity
	sta Buffer,y

	lda #REPEAT_TIME1
	sta rep_counter
	; Keep track of how many new Alphanumeric keys are detected
	inc SimultaneousKeys
	beq TooManyNewKeys
Exist:
	dex
	bpl ScanLoop

	; Anything in Buffer?
	ldy BufferQuantity
	bmi BufferEmpty
	; Yes: Then return it and tidy up the buffer
	dec BufferQuantity
	lda Buffer
	ldx Buffer+1
	stx Buffer
	ldx Buffer+2
	stx Buffer+1
	jmp Return

BufferEmpty:  ; No new Alphanumeric keys to handle.
	lda #$ff

Return:  ; A is preset
	clc
	; Copy BufferNew to BufferOld
	ldx BufferNew
	stx BufferOld
	ldx BufferNew+1
	stx BufferOld+1
	ldx BufferNew+2
	stx BufferOld+2
	; Handle Non Alphanumeric Keys
	ldx NonAlphaFlagX
	ldy NonAlphaFlagY
	rts

TooManyNewKeys:
	sec
	lda #$ff
	sta BufferQuantity
	sta SimultaneousAlphanumericKeysFlag
	lda #$04
	rts

.BSS
;******************************************************************************
BufferOld:                        .byte $00, $00, $00
Buffer:                           .byte $00, $00, $00, $00
BufferQuantity:                   .byte $00
SimultaneousAlphanumericKeysFlag: .byte $00

; global counter for when BufferOld is cleared
rep_counter: .byte 0
