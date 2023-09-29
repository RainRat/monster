.include "beep.inc"
.include "bitmap.inc"
.include "cursor.inc"
.include "debug.inc"
.include "finalex.inc"
.include "key.inc"
.include "keycodes.inc"
.include "layout.inc"
.include "macros.inc"
.include "memory.inc"
.include "text.inc"
.include "util.inc"
.include "vmem.inc"
.include "zeropage.inc"

;******************************************************************************
; CONSTANTS
BYTES_TO_DISPLAY=8

COL_START = 7
COL_STOP  = COL_START+(3*BYTES_TO_DISPLAY)-1

TOTAL_BYTES = BYTES_TO_DISPLAY*(MEMVIEW_STOP-MEMVIEW_START)

.BSS
;******************************************************************************
dirtybuff: .res TOTAL_BYTES
memaddr:   .word 0

.CODE
;******************************************************************************
; OFF
; Turns off the memory view window by restoring the screen
.export __view_off
.proc __view_off
	jmp bm::restore
.endproc

;******************************************************************************
; EDIT
; Starts the memory editor at the address given in .YX
; IN:
;  - .XY: the address to edit memory at
.export __view_edit
.proc __view_edit
@dst=zp::tmp0
@odd=zp::tmp4
@dstoffset=zp::tmp6
@src=zp::tmp7
	stxy @src
	stxy memaddr

	ldx #COL_START
	ldy #MEMVIEW_START+1
	jsr cur::setmin

	ldy #MEMVIEW_STOP
	ldx #COL_STOP
	jsr cur::setmax

	ldy #MEMVIEW_START+1
	ldx #COL_START
	jsr cur::set

	lda #$00	; REPLACE mode
	sta text::insertmode

	ldxy @src
	jsr __view_mem

	jsr cur::on

; until user exits (<- or RETURN), get input and update memory
@edit:
	jsr key::getch
	beq @edit

	cmp #$5f	; <- (done)
	beq @done
	cmp #$0d	; RETURN (done)
	beq @done

	cmp #$91	; up arrow
	bne :+
	ldy #$ff
	ldx #0
	jsr cur::move
	jsr cur::on
	jmp @edit

:	cmp #$11
	bne :+
	ldy #1
	ldx #0
	jsr cur::move
	jsr cur::on
	jmp @edit

:	cmp #$14	; delete
	beq @retreat
	cmp #$9d	; left
	bne :+
@retreat:
	jsr @prev_x
	jsr cur::on
	jmp @edit

:	cmp #$1d	; right
	bne :+
	jsr @next_x
	jsr cur::on
	jmp @edit

:	jsr key::ishex
	bcs @replace_val
	cmp #K_SET_WATCH
	bcc @edit

@setwatch:
	jsr get_addr	; get the address of the byte under the cursor
	jsr dbg::addwatch
	jsr beep::short	; beep to confirm add
	jmp @edit

@done:	jsr cur::unlimit
	jmp cur::off

@replace_val:
	jsr @set_nybble	; replace the nybble under cursor
	jsr @next_x	; advance the cursor (if we can)
	ldxy @src
	jsr __view_mem	; update the display
	jsr cur::on
	jmp @edit

;--------------------------------------
; get the address of the memory at the cursor position
@set_nybble:
	jsr util::chtohex
	pha

	; get the base address for the row that the cursor is on
	lda zp::cury
	sec
	sbc #MEMVIEW_START+1
	asl		; *8 (each row is 8 bytes)
	asl
	asl
	adc @src
	sta @dst
	lda @src+1
	adc #$00
	sta @dst+1

	; get the offset from the row's base address using the curor's x pos
	; the offset is calcuated by: (zp::curx - COL_START) / 3
	ldy #$ff
	lda zp::curx
	sec
	sbc #COL_START
:	iny
	sbc #$03	; -3 (bytes are 3 cursor positions apart)
	bpl :-
	sty @dstoffset

	; get odd/even cursor column
	lda zp::curx
	and #$01
	sta @odd
	; bytes alternate odd/even columns for hi/lo nybble
	tya
	and #$01
	eor @odd
	beq @lownybble

;--------------------------------------
@hinybble:
	ldxy @dst
	lda @dstoffset
	jsr vmem::load_off

	and #$0f
	sta @odd
	pla
	asl
	asl
	asl
	asl
	ora @odd
	jmp @store

;--------------------------------------
@lownybble:
	ldxy @dst
	lda @dstoffset
	jsr vmem::load_off

	and #$f0
	sta @odd
	pla
	ora @odd
@store:
	sta zp::bankval
	ldxy @dst
	lda @dstoffset
	jsr vmem::store_off
	rts

;--------------------------------------
; move cursor to the next x-position
@next_x:
	jsr cur::off
	ldx zp::curx
@next_x2:
	inx
	txa
	ldy #@num_x_skips-1
:	cmp @x_skips,y
	beq @next_x2
	dey
	bpl :-
	ldy zp::cury
	jmp cur::set

;--------------------------------------
; move cursor to the previous x-position
@prev_x:
	jsr cur::off
	ldx zp::curx
@prev_x2:
	dex
	txa
	ldy #@num_x_skips-1
:	cmp @x_skips,y
	beq @prev_x2
	dey
	bpl :-
	ldy zp::cury
	jmp cur::set

;--------------------------------------
; table of columns to skip in cursor movement
@x_skips:
	.byte COL_START+2
	.byte COL_START+5
	.byte COL_START+8
	.byte COL_START+11
	.byte COL_START+14
	.byte COL_START+17
	.byte COL_START+20
@num_x_skips=*-@x_skips
.endproc

;******************************************************************************
; MEM
; Displays the contents of memory in a large block beginning with the
; address in (YX).
; The address is that which was set with the most recent call to mem::edit
.export __view_mem
.proc __view_mem
@src=zp::tmpa
@col=zp::tmpc
@row=zp::tmpd
	ldxy memaddr
	stxy @src

	; draw the title for the memory display
	ldxy #@title
	lda #MEMVIEW_START
	jsr text::print
	lda #MEMVIEW_START
	jsr bm::rvsline

	; initialize line to empty (all spaces)
	lda #40
	sta zp::tmp0
	lda #' '
	ldx #<mem::spare
	ldy #>mem::spare
	jsr util::memset

	lda #MEMVIEW_START+1
	sta @row

@l0:	; draw the address of this line
	lda @src+1
	jsr util::hextostr
	sty mem::spare
	stx mem::spare+1
	lda @src
	jsr util::hextostr
	sty mem::spare+2
	stx mem::spare+3
	lda #':'
	sta mem::spare+4

	ldx #$00
@l1:	stx @col

	; get a byte to display
	ldy #$00
	ldxy @src
	jsr vmem::load
	pha			; save the byte

	incw @src		; update @src to the next byte
	jsr val2ch
	ldx @col
	sta mem::spare+31,x	; write the character representation
	pla			; get the byte we're rendering
	jsr util::hextostr	; convert to hex characters
	txa			; get LSB char
	pha			; and save temporarily
	lda @col		; get col*3 (column to draw byte)
	asl
	adc @col
	tax
	pla			; restore LSB char to render
	sta mem::spare+8,x	; store to text buffer
	tya			; get MSB
	sta mem::spare+7,x	; store to text buffer
	ldx @col
	inx
	cpx #BYTES_TO_DISPLAY	; have we drawn all columns?
	bcc @l1			; repeat until we have

	ldx #<mem::spare
	ldy #>mem::spare
	lda @row
	jsr text::puts		; draw the row of rendered bytes
	inc @row
	lda @row
	cmp #MEMVIEW_STOP	; have we drawn all rows?
	bcc @l0			; repeat til we have
	rts

@title: .byte ESCAPE_SPACING,16, "memory",0
.endproc

;******************************************************************************
; Get the character representation of the given byte value
.proc val2ch
	cmp #$20
	bcc :+
	cmp #$80
	bcs :+
	rts
:	lda #'.'	; use '.' for undisplayable chars
	rts
.endproc

;******************************************************************************
; DIRTY
; Returns .Z set if the memory in the viewer is dirty (has changed since the
; last render)
; OUT:
;  - .Z: set if the display is dirty
.export __view_dirty
.proc __view_dirty
@cnt=zp::tmp2
	ldx #TOTAL_BYTES-1
	stx @cnt

:	ldxy memaddr
	lda @cnt
	jsr vmem::load_off

	ldx @cnt
	cmp dirtybuff,x
	bne @dirty
	dec @cnt
	bpl :-
@clean: lda #$ff
	rts
@dirty: lda #$00
	rts
.endproc

;******************************************************************************
; GET_ADDR
; Gets the address of the byte under the cursor when editing memory
; IN:
;  - zp::tmp8 contains the base address of the current view
; OUT:
;  - zp::tmp0 contains the address under the cursor
.proc get_addr
@src=zp::tmp8
@dst=zp::tmp0
	lda zp::cury
	sec
	sbc #MEMVIEW_START+1
	asl		; *8 (each row is 8 bytes)
	asl
	asl
	adc @src
	sta @dst
	lda @src+1
	adc #$00
	sta @dst+1

	ldy #$ff
	lda zp::curx
	sec
	sbc #COL_START
:	iny
	sbc #$03
	bpl :-

	tya
	clc
	adc @dst
	sta @dst
	bcc :+
	inc @dst+1

:	ldxy @dst
	rts
.endproc

