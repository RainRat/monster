.include "cursor.inc"
.include "errors.inc"
.include "irq.inc"
.include "zeropage.inc"
.include "macros.inc"
.include "memory.inc"
.include "finalex.inc"
.include "util.inc"

.ifdef USE_FINAL
	.import __BANKCODE_LOAD__
	.import __BANKCODE_SIZE__
	MAX_SOURCES=8
.else
	MAX_SOURCES=1
.endif

GAPSIZE = 20		; size of gap in gap buffer
POS_STACK_SIZE = 32 	; size of source position stack

.segment "SOURCE"
;******************************************************************************
data_start:
sp: 	   .byte 0
stack:     .res POS_STACK_SIZE

.export src_debug
src_debug:
pre:   .word 0			; # of bytes before the gap
pres:  .res MAX_SOURCES*2       ; buffers for each source

post:  .word 0			; # of bytes after the gap
posts: .res MAX_SOURCES*2       ; buffers for each source

.export __src_line
__src_line:
line:     .word 0       	; the current line # for the cursor
linenums: .res MAX_SOURCES*2 	; line #'s for each source

.export __src_lines
__src_lines:
lines:    .word 0		; number of lines in the source
linecnts: .res MAX_SOURCES*2	; number of lines in each source


len:  	   .word 0		; size of the buffer (pre+post+gap)
lens:	   .res MAX_SOURCES*2	; buffers for each source
data_end:

.BSS
;******************************************************************************
numsrcs:   .byte 0		; number of buffers
activesrc: .byte 0		; index of active buffer (also bank offset)
.ifdef USE_FINAL
bank:	    .byte 0
buffs_curx: .res MAX_SOURCES	; cursor X positions for each inactive buffer
buffs_cury: .res MAX_SOURCES	; cursor Y positions for each inactive buffer
.endif

;******************************************************************************

;******************************************************************************
; DATA
.export __src_buffer
__src_buffer:
.ifndef USE_FINAL
data:
.res 1024*4
.else
data = __BANKCODE_LOAD__ + __BANKCODE_SIZE__
.endif

.CODE
;******************************************************************************
; SETRSC
; Sets the active source to the source in the given ID.
; IN:
;  - .A: the id of the source to set
;  - .X: the current cursor X position (needed for restoring this buffer later)
;  - .Y: the current cursor Y position (needed for restoring this buffer later)
.export __src_set
.proc __src_set
	pha

	; save the cursor position in the current buffer
	txa
	ldx activesrc
	sta buffs_curx,x
	tya
	sta buffs_cury,x

	; save the data for the source we're switching from
	lda activesrc
	asl
	tax

	lda pre
	sta pres,x
	lda pre+1
	sta pres+1,x

	lda post
	sta posts,x
	lda post+1
	sta posts+1,x

	lda len
	sta lens,x
	lda len+1
	sta lens+1,x

	lda lines
	sta linecnts,x
	lda lines+1
	sta linecnts+1,x

	lda line
	sta linenums,x
	lda line+1
	sta linenums+1,x

	; set the pointers to those of the source we're switching to
	pla
	sta activesrc
	asl
	tax

	lda pres,x
	sta pre
	lda pres+1,x
	sta pre+1

	lda posts,x
	sta post
	lda posts+1,x
	sta posts+1

	lda lens,x
	sta len
	lda lens+1,x
	sta len

	lda linecnts,x
	sta lines
	lda linecnts+1,x
	sta lines

	lda linenums,x
	sta line
	lda linenums+1,x
	sta line

	; restore cursor position in the new source
	ldx activesrc
	ldy buffs_cury,x
	lda buffs_curx,x
	tax
	jmp cur::set
.endproc

;******************************************************************************
; NEW
; Initializes a new source buffer and sets it as the current buffer
; OUT:
;  - .C: set if the source could not be initialized (e.g. too many open
;        sources)
.export __src_new
.proc __src_new
	ldx numsrcs
	beq @init
	inx
	cpx #MAX_SOURCES
	bcc @saveold
	rts		; err, too many sources

@saveold:
	jsr __src_set	; save current source data
	ldx activesrc
	inx
@init:	stx activesrc
.ifdef USE_FINAL
	txa
	clc
	adc #FINAL_BANK_SOURCE0
	sta bank
.endif
	ldx #data_end-data_start-1
	lda #$00
:	sta data_start-1,x
	dex
	bne :-
	lda #GAPSIZE
	sta len
	inc line

	inc numsrcs
	rts
.endproc

;******************************************************************************
; PUSHP
; Pushes the current source position to an internal stack.
.export __src_pushp
.proc __src_pushp
	lda sp
	cmp #POS_STACK_SIZE-1
	bcc :+
	RETURN_ERR ERR_STACK_OVERFLOW

:	asl
	tax
	inc sp

	lda pre
	sta stack,x
	lda pre+1
	sta stack+1,x
	RETURN_OK
.endproc

;******************************************************************************
; POPP
; Returns the the most recent source position pushed in .YX
; OUT:
;  - .XY: the most recently pushed source position
.export __src_popp
.proc __src_popp
	lda sp
	bne :+
	RETURN_ERR ERR_STACK_UNDERFLOW

:	dec sp
	lda sp
	asl
	tax
	lda stack+1,x
	tay
	lda stack,x
	tax
	RETURN_OK
.endproc

;******************************************************************************
; END
; Returns .Z set if the cursor is at the end of the buffer.
; OUT:
;  - .Z: set if the cursor is at the end of the buffer
.export __src_end
.proc __src_end
	ldxy post
	cmpw #$0000
	rts
.endproc

;******************************************************************************
; START
; Returns .Z set if the cursor is at the start of the buffer.
; OUT:
;  - .Z: set if the cursor is at the start of the buffer
.export __src_start
.proc __src_start
	ldxy pre
	cmpw #$0000
	rts
.endproc

;******************************************************************************
; BACKSPACE
; Deletes the character immediately before the current cursor position.
.export __src_backspace
.proc __src_backspace
	jsr __src_start
	beq @skip
	jsr atcursor
	cmp #$0d
	bne :+
	decw line
	decw lines
:	decw pre
@skip:	rts
.endproc

;******************************************************************************
; DELETE
; Deletes the character at the current cursor position.
.export __src_delete
.proc __src_delete
	jsr __src_end
	beq @skip
	decw post
@skip:	rts
.endproc

;******************************************************************************
; NEXT
; Moves the cursor up one character in the gap buffer.
; OUT:
;  - .A: the character at the new cursor position in .A
.export __src_next
.proc __src_next
@src=zp::tmp0
@dst=zp::tmp2
	jsr __src_end
	beq @skip

	; move char from start of gap to the end of the gap
	jsr cursor
	stx @dst
	sty @dst+1
	jsr poststart
	stx @src
	sty @src+1

.IFDEF USE_FINAL
	bank_read_byte bank, @src
	bank_store_byte bank, @dst
	lda zp::bankval
.ELSE
	ldy #$00
	lda (@src),y
	sta (@dst),y
.ENDIF

	cmp #$0d
	bne :+
	incw line

:	incw pre
	decw post
 @skip:	jmp atcursor
.endproc

;******************************************************************************
; RIGHT
; Moves to the next character unless it is a newline
; OUT:
;  - .C: set if the cursor was moved, clear if not
.export __src_right
.proc __src_right
	jsr __src_end
	bne :+
	clc
	rts

:	jsr __src_next
	cmp #$0d
	bne :+
	jsr __src_prev
	clc
	rts

:	sec
	rts
.endproc

;******************************************************************************
; PREV
; Moves the cursor back one character in the gap buffer.
; OUT:
;  - .A: the character at the new position
.export __src_prev
.proc __src_prev
@src=zp::tmp0
@dst=zp::tmp2
	ldxy pre
	cmpw #0
	beq @skip

	; move char from start of gap to the end of the gap
	jsr cursor
	stxy @src
	jsr poststart
	stxy @dst

	decw @src
	decw @dst
.IFDEF USE_FINAL
	bank_read_byte bank, @src
	bank_store_byte bank, @dst
	lda zp::bankval
.ELSE
	ldy #$00
	lda (@src),y
	sta (@dst),y
.ENDIF
	cmp #$0d
	bne :+
	decw line

:	decw pre
	incw post
 @skip:	jmp atcursor
.endproc

;******************************************************************************
; UP
; Moves the cursor back one line or to the start of the buffer if it is
; already on the first line
; this will leave the cursor on the first newline character encountered while
; going backwards through the source.
; OUT:
;  - .A: the character at the cursor position
;  - .C: set if cursor is at the start of the buffer
.export __src_up
.proc __src_up
	jsr __src_start
	bne @l0
	sec
	rts

@l0:	jsr __src_prev
	cmp #$0d
	beq :+
	jsr __src_start
	bne @l0
	sec
	rts
:	clc
	rts
.endproc

;******************************************************************************
; DOWN
; Moves the cursor beyond the next RETURN character (or to the end of
; the buffer if there is no such character
; OUT:
;  - .C: set if the end of the buffer was reached (cannot move "down")
.export __src_down
.proc __src_down
	jsr __src_end
	bne @l0
	sec
	rts

@l0:	jsr __src_next
	cmp #$0d
	beq :+
	jsr __src_end
	bne @l0
	sec	; end of the buffer
	rts
:	clc
	rts
.endproc

;******************************************************************************
; INSERT
; Adds the character in .A to the buffer at the gap position (gap).
; IN:
;  - .A: the character to insert
.export __src_insert
.proc __src_insert
@len=zp::tmp0
@src=zp::tmp2
@dst=zp::tmp4
	pha
	jsr gaplen
	cmpw #0		; is gap closed?
	bne @ins	; no, insert as usual

	; gap is closed, create a new one
	; copy data[poststart] to data[poststart + len]
	jsr poststart
	stxy @src
	add16 len
	stxy @dst

.IFDEF USE_FINAL
	ldxy len
	lda bank
	jsr fe3::copy
.ELSE
	copy @dst, @src, len
.ENDIF

	; double size of buffer (new gap size is the size of the old buffer)
	asl len
	rol len+1

@ins:	jsr cursor
	stxy @dst
	pla
.IFDEF USE_FINAL
	bank_store_byte bank, @dst
	lda zp::bankval
.ELSE
	ldy #$00
	sta (@dst),y
.ENDIF
	cmp #$0d
	bne :+
	incw line
	incw lines
:	incw pre
	rts
.endproc

;******************************************************************************
; REPLACE
; Adds the character in .A to the buffer at the cursor position,
; replacing the character that currently resides there
; IN:
;  - .A: the character to replace the existing one with
.export __src_replace
.proc __src_replace
	pha
	jsr __src_delete
	pla
	jmp __src_insert
.endproc

;******************************************************************************
; GAPLEN
; Returns the length of the gap
; OUT:
;  - .XY: the length of the gap (len-post-pre)
.proc gaplen
	ldxy len
	sub16 post
	sub16 pre
	rts
.endproc

;******************************************************************************
; CURSOR
; Returns the address of the current cursor position within (data).
; OUT:
;  - .XY: the address of the cursor position
.proc cursor
	ldxy #data
	add16 pre
	rts
.endproc

;******************************************************************************
; ATCURSOR
; Returns the character at the cursor position.
; OUT:
;  - .A: the character at the current cursor position
.export __src_atcursor
__src_atcursor:
.proc atcursor
	jsr cursor
	sub16 #1
	stxy zp::tmp0
.IFDEF USE_FINAL
	bank_read_byte bank, zp::tmp0
.ELSE
	ldy #$00
	lda (zp::tmp0),y
.ENDIF
	rts
.endproc

;******************************************************************************
; POSTSTART
; Returns the address of the post-start section of the gap buffer
; OUT:
;  - .XY: the address of the post-start section
.proc poststart
	ldxy #data
	add16 len
	sub16 post
	rts
.endproc

;******************************************************************************
; REWIND
; Moves the cursor back to the start of the buffer
.export __src_rewind
.proc __src_rewind
@l0:	jsr __src_prev
	jsr __src_start
	bne @l0
	rts
.endproc

;******************************************************************************
; READB
; Reads one byte at the cursor positon and advances the cursor
; OUT:
;  - .A: the byte that was read
.export __src_readb
.proc __src_readb
	jsr atcursor
	pha
	jsr __src_next
	pla
	rts
.endproc

;******************************************************************************
; READLINE
; Reads one line at the cursor positon and advances the cursor
; OUT:
;  - mem::linebuffer: the line that was read will be 0-terminated
;  - .C: set if the end of the source was reached
.export __src_readline
.proc __src_readline
@cnt=zp::tmp4
	lda #$00
	sta mem::linebuffer
	sta @cnt

	jsr __src_end
	beq @eofdone

@l0:	jsr __src_readb
	ldx @cnt
	cmp #$0d
	bne :+
	lda #$00
:	sta mem::linebuffer,x
	beq @done
	inc @cnt
	jsr __src_end
	bne @l0
@eof:	; read last byte and null terminate if end of source
	jsr atcursor
	ldx @cnt
	cmp #$0d
	bne :+
	lda #$00
:	sta mem::linebuffer,x
	lda #$00
	sta mem::linebuffer+1,x
@eofdone:
	sec
	rts
@done:	clc
	rts
.endproc


;******************************************************************************
; GOTO
; Goes to the source position given
; IN:
;  - .XY: the line to go to
.export __src_goto
.proc __src_goto
@dest=zp::tmp4
	stxy @dest
	cmpw pre
	beq @done
	bcc @backwards
@forwards:
	jsr __src_next
	ldxy pre
	cmpw @dest
	bne @forwards
	rts
@backwards:
	jsr __src_prev
	ldxy pre
	cmpw @dest
	bne @backwards
@done:  rts
.endproc

;******************************************************************************
; GET
; Returns the text at the current cursor position in mem::linebuffer
; OUT:
;  - mem::linebuffer: a line of text from the cursor position
;  - .C: set if the end of the buffer was reached as we were reading
.export __src_get
.proc __src_get
@cnt=zp::tmp1
@src=zp::tmp3
	jsr gaplen
	add16 pre
	add16 #data
	stxy @src

	jsr __src_end
	bne :+
	lda #$00
	sta mem::linebuffer	; init buffer
	sec
	rts

:	stxy @cnt
	incw @cnt

	ldy #$00
@l0:
.IFDEF USE_FINAL
	sty zp::bankval
	ldxy @src
	lda bank
	jsr fe3::load_off
	ldy zp::bankval
	cmp #$00
.ELSE
	lda (@src),y
.ENDIF
	beq @done
	cmp #$0d
	beq @done
	sta mem::linebuffer,y
	decw @cnt
	lda @cnt+1
	bne :+
	lda @cnt
	beq @done
:	iny
	cpy #39
	bcc @l0
@eof:
	sec
	skb
@done:	clc
	lda #$00
	sta mem::linebuffer,y
	rts
.endproc

;******************************************************************************
; DOWNN
; Advances the source by the number of lines in .YX
;  - .YX: the number of lines that were not read
;  - .C: set if the end was reached before the total lines requested could be reached
.export __src_downn
.proc __src_downn
@cnt=zp::tmp4
	stxy @cnt
@loop:	ldxy @cnt
	decw @cnt
	cmpw #$0000
	beq @done
	jsr __src_down
	bcc @loop
@done:	ldxy @cnt
	rts
.endproc

;******************************************************************************
; UPN
; Advances the source by the number of lines in .YX
; IN:
;  - .XY: the number of lines to move "up"
; OUT:
;  - .YX: contains the number of lines that were not read
;  - .C: set if the beginning was reached before the total lines requested could be reached
.export __src_upn
.proc __src_upn
@cnt=zp::tmp4
	stxy @cnt
@loop:	ldxy @cnt
	decw @cnt
	cmpw #$0000
	beq @done
	jsr __src_up
	bcc @loop
@done:	ldxy @cnt
	rts
.endproc
