.include "bitmap.inc"
.include "macros.inc"
.include "zeropage.inc"
.include "text.inc"
.CODE

;******************************************************************************
L_INSERT_MASK=$80
R_INSERT_MASK=$08
L_REPLACE_MASK=$f0
R_REPLACE_MASK=$0f

;******************************************************************************
; MASK
; Returns the mask used to draw the cursor based on the current mode and
; cursor position.
; OUT:
;  - .A: the mask that will be EOR'd to draw the cursor
.proc mask
	lda text::insertmode
	beq @replace
@insert:
	lda zp::curx
	and #$01
	beq :+
	lda #R_INSERT_MASK
	rts
:	lda #L_INSERT_MASK
	rts
@replace:
	lda zp::curx
	and #$01
	beq :+
	lda #R_REPLACE_MASK
	rts
:	lda #L_REPLACE_MASK
	rts
.endproc

;******************************************************************************
; OFF
; Turns off the cursor if it is on. Has no effect if the cursor is already off.
.export __cur_off
__cur_off:
	lda curstatus
	bne __cur_toggle
	rts
;******************************************************************************
; ON
; Turns on the cursor if it is off. Has no effect if the cursor is already on.
.export __cur_on
__cur_on:
	lda curstatus
	beq __cur_toggle
	rts
;******************************************************************************
; TOGGLE
; Toggles the cursor (turns it off if its on or vise-versa)
.export __cur_toggle
__cur_toggle:
@dst=zp::tmp0
	ldx zp::curx
	ldy zp::cury
	lda curstatus
	beq :+		; cursor is being turned on
	ldx prev_x
	ldy prev_y
	cpx #$ff	; old cursor is undefined, don't clear
	beq @done

:	txa
	and #$fe
	tax
	tya
	asl
	asl
	asl
	adc bm::columns,x
	sta @dst
	lda #$00
	adc bm::columns+1,x
	sta @dst+1

	jsr mask
	sta @mask
	ldy #7
@mask=*+1
@l0:	lda #$ff
	eor (@dst),y
	sta (@dst),y
	dey
	bpl @l0

	lda #1
	eor curstatus
	sta curstatus

@done:  lda zp::curx
	sta prev_x
	lda zp::cury
	sta prev_y
	rts

;******************************************************************************
; UP
; Moves the cursor up a row.
; If moving up would move the cursor outside its defined limits, has no effect
.export __cur_up
.proc __cur_up
	lda zp::cury
	cmp miny
	bcs :+
	ldy miny
	ldx #$00
	jmp __cur_set
:	ldy #$ff
	ldx #$00
	jmp __cur_move
.endproc

;******************************************************************************
; UP
; Moves the cursor down a row.
; If moving down would move the cursor outside its defined limits, has no effect
.export __cur_down
.proc __cur_down
	lda zp::cury
	cmp maxy
	bcs @done
	ldy #1
	ldx #$00
	jmp __cur_move
@done:	rts
.endproc

;******************************************************************************
; RIGHT
; Moves the cursor right a column
; If moving right would move the cursor outside its limits, has no effect
.export __cur_right
.proc __cur_right
	lda zp::curx
	cmp #39
	bcs @done
	ldy #0
	ldx #1
	jmp __cur_move
@done:	rts
.endproc

;******************************************************************************
; LEFT
; Moves the cursor left a column
; If moving left would move the cursor outside its defined limits, has no effect
.export __cur_left
.proc __cur_left
	lda zp::curx
	beq @done
	ldy #0
	ldx #$ff
	jmp __cur_move
@done:	rts
.endproc

;******************************************************************************
; MOVE
; Updates the cursor's (x,y) position by the offsets given
; IN:
;  - .X: the signed number of columns to move
;  - .Y: the signed number of rows to move
.export __cur_move
.proc __cur_move
	stx zp::tmp2
	sty zp::tmp3
	jsr __cur_off

	lda zp::tmp2
	clc
	adc zp::curx
	bmi @movey
	cmp maxx
	bcs @movey
	cmp minx
	bcc @movey
	sta zp::curx

@movey: lda zp::tmp3
	clc
	adc zp::cury
	bmi @done
	cmp maxy
	bcs @done
	cmp miny
	bcc @done
	sta zp::cury
@done:	rts
.endproc

;******************************************************************************
; SET
; Sets the cursor position (x,y) to the values given
; IN:
;  .X: the column to set the cursor to
;  .Y: the row to set the cursor to
.export __cur_set
.proc __cur_set
	cpx maxx
	bcc :+
	ldx maxx
	dex
:	cpx minx
	bcs :+
	ldx minx
:	stx zp::tmp2

	cpy maxy
	bcc :+
	ldy maxy
	dey
:	cpy miny
	bcs :+
	ldy miny
:	sty zp::tmp3

	jsr __cur_off

	ldx zp::tmp2
	ldy zp::tmp3
	stx zp::curx
	sty zp::cury
	rts
.endproc

;******************************************************************************
; FORCESET
; Sets the cursor X and Y without respecting limts
; IN:
;  - .X: the column to set the cursor to
;  - .Y: the row to set the cursor to
.export __cur_forceset
.proc __cur_forceset
	stx zp::curx
	sty zp::cury
	rts
.endproc

;******************************************************************************
; SETMAX
; Sets the maximum values for the cursor's X and Y values
; IN:
;  - .X: the column limit to set for the cursor
;  - .Y: the row limit to set for the cursor
.export __cur_setmax
.proc __cur_setmax
	stx maxx
	sty maxy
	rts
.endproc

;******************************************************************************
; SETMIN
; Sets the minimum values for the cursor's X and Y values
; IN:
;  - .X: the column limit to set for the cursor
;  - .Y: the row limit to set for the cursor
.export __cur_setmin
.proc __cur_setmin
	stx minx
	sty miny
	rts
.endproc

;******************************************************************************
; UNLIMIT
.export __cur_unlimit
.proc __cur_unlimit
	ldxy #$00
	jsr __cur_setmin
	ldx #40
	ldy #23
	jmp __cur_setmax
.endproc

.BSS
;******************************************************************************
curstatus: .byte 0

.export __cur_minx
__cur_minx:
minx: .byte 0

.export __cur_maxx
__cur_maxx:
maxx: .byte 0

.export __cur_miny
__cur_miny:
miny: .byte 0

.export __cur_maxy
__cur_maxy:
maxy: .byte 0

prev_x: .byte 0
prev_y: .byte 0