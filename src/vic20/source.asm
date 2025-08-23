.include "../debug.inc"
.include "../debuginfo.inc"
.include "../edit.inc"
.include "../errors.inc"
.include "../macros.inc"
.include "../ram.inc"
.include "../zeropage.inc"

.import __src_bank
.import __src_get_filename
.import __src_mark_dirty
.import __src_on_last_line

buffstate   = zp::srccur
cursorzp    = zp::srccur
poststartzp = zp::srccur2
line        = zp::srcline
lines       = zp::srclines
end         = zp::srcend

BUFFER_SIZE = $6000	; max size of buffer
GAPSIZE     = $100	; size of gap in gap buffer

;*******************************************************************************
; DATA
; This buffer holds the text data.  It is a large contiguous chunk of memory
.segment "SOURCE"
.assert * & $ff = 0, error, "source buffers must be page aligned"
data: .res BUFFER_SIZE

.CODE

;*******************************************************************************
; INIT BUFF
; Initializes a new source buffer by setting its pointers to the
; start/end of the gap
.export __src_init_buff
.proc __src_init_buff
	lda #<data
	sta cursorzp
	lda #>data
	sta cursorzp+1

	lda #<(data+GAPSIZE)
	sta end
	sta poststartzp
	lda #>(data+GAPSIZE)
	sta end+1
	sta poststartzp+1
	rts
.endproc


;*******************************************************************************
; INSERT
; Adds the character in .A to the buffer at the gap position (gap).
; If the character is not valid, it is not inserted, but the operation is
; still considereed a success (.C is returned clear)
; IN:
;  - .A: the character to insert
; OUT:
;  - .C: set if the character could not be inserted (buffer full)
; CLOBBERS:
;  - $120-$130: may be clobbered if newline is inserted
.export __src_insert
.proc __src_insert
@skip_insert_logic=r0
@src=r2
@dst=r4
	ldx #$00
	stx @skip_insert_logic

	cmp #$0d
	beq :+
	cmp #$0a
	beq :+
	cmp #$09
	beq :+
	cmp #$20
	bcc @done
	cmp #$80
	bcs @done	; not displayable

:	pha
	jsr __src_mark_dirty
	jsr gaplen
	cmpw #0		; is gap closed?
	bne @ins	; no, insert as usual

	; check if there is room to expand the gap
	lda poststartzp+1
	cmp #>(BUFFER_SIZE+data)-1	; -1 to save space for a $100 byte gap
	bcc @ok

@err:	; buffer overflow, cannot insert character
	pla				; clean stack
	lda #ERR_BUFFER_FULL
	rts

@ok:	; gap is closed, create a new one
	; copy data[poststart] to data[poststart + GAPSIZE]
	ldxy cursorzp
	stxy @src

	inc poststartzp+1
	inc end+1		; increase size by $100
	ldxy poststartzp
	stxy @dst

	; get number of bytes to copy
	ldxy end
	sub16 poststartzp

	lda __src_bank
	sta r7		; destination bank
	jsr ram::copy

@ins:	pla
	ldy cursorzp+1
	bmi @done	; out of range

	sta24 __src_bank, cursorzp

	cmp #$0d
	bne @insdone
	incw line
	lda @skip_insert_logic
	bne :+
	jsr on_line_inserted
:	incw lines
@insdone:
	incw cursorzp
@done:	RETURN_OK
.endproc

;*******************************************************************************
; COPY LINE
; Returns the text at the current cursor position and stores it to the given
; target location
; IN:
;  - .XY: the destination to copy to
;  - r1:  the destination to copy to
; OUT:
;  - (.XY): a line of text from the cursor position
.export __src_copy_line
.proc __src_copy_line
@src=zp::bankaddr0
@target=zp::bankaddr1
	stxy @target		; dest
	ldxy poststartzp
	stxy @src		; source

	jsr __src_on_last_line	; on last line already?
	bne :+
	ldxy end
	sub16 poststartzp	; bytes to copy
	txa
	pha
	tay			; .Y = bytes to copy
	dey
	lda __src_bank
	jsr ram::copyline	; may copy garbage

	pla			; restore end of line index
	tay
	lda #$00
	sta (@target),y		; terminate line at end
	beq @done		; branch always

:	lda __src_bank
	jsr ram::copyline

@done:	lda #$00
	sta (@target),y
	RETURN_OK
.endproc

.PUSHSEG
.segment "BANKCODE2"
;******************************************************************************
; NEXT
; Moves the cursor up one character in the gap buffer
; OUT:
;  - .A: the character at the new cursor position in .A
;  - .C: clear on success (always clear)
.export __src_next
.proc __src_next
	; do __src_end inline to save the cycles from JSR and RTS
	ldx poststartzp
	cpx end
	bne @cont
	ldx poststartzp+1
	cpx end+1
	beq @done

@cont:	; switch to the bank that contains the source buffer's data
	lda __src_bank
	sta $9c02

	; move one byte from the end of the gap to the start
	ldy #$00
	lda (poststartzp),y
	sta (cursorzp),y

	incw cursorzp
	incw poststartzp

	; switch back to main bank
	ldx #FINAL_BANK_MAIN
	stx $9c02

	cmp #$0d
	bne @done
	incw line
@done:	RETURN_OK
.endproc

;*******************************************************************************
; PREV
; Moves the cursor back one character in the gap buffer.
; OUT:
;  - .A: the character at the new cursor position (if not at the start of buff)
;  - .C: set if we're at the start of the buffer and couldn't move back
.export __src_prev
.proc __src_prev
	jsr __src_start
	bne :+
	jsr __src_atcursor
	sec
	rts

:	; move char from start of gap to the end of the gap
	decw cursorzp
	decw poststartzp

	; switch to the bank that contains the source buffer's data
	lda __src_bank
	sta $9c02

	; move one byte from the start of the gap to the end
	ldy #$00
	lda (cursorzp),y
	sta (poststartzp),y

	cmp #$0d
	bne :+
	decw line

:	; get the character at the new cursor position
	decw cursorzp
	lda (cursorzp),y
	incw cursorzp

	; switch back to main bank
	ldx #FINAL_BANK_MAIN
	stx $9c02
	RETURN_OK
.endproc

;*******************************************************************************
; INSERT ON LOAD
; Inserts a character into a buffer that is known to be "clean"
; That means the user has not added breakpoints, debug-info, etc.
; This should be used when loading a source file but not otherwise.
; The reason this procedure must be used when inserting before the file is
; loaded is that the association between filename and debug-info doesn't yet
; exist, but this association is required to do the extra logic in the
; aforementioned cases.
; IN:
;  - .A: the character to insert
; OUT:
;  - .C: set if the character could not be inserted (buffer full)
.export __src_insert_on_load
.proc __src_insert_on_load
	cmp #$0a
	bne :+
	lda #$0d
:	cmp #$0d
	bne :+
	incw lines
	bne @store		; branch always

:	cmp #$09
	beq @store
	cmp #$20
	bcc @done
	cmp #$80
	bcs @done		; not displayable, don't insert

@store:	ldy __src_bank
	sty $9c02
	ldy #$00
	sta (end),y
	incw end
	ldy #FINAL_BANK_MAIN
	sty $9c02		; switch back to main bank
@done:	RETURN_OK
.endproc
.POPSEG

;*******************************************************************************
; START
; Returns .Z set if the cursor is at the start of the buffer.
; OUT:
;  - .Z: set if the cursor is at the start of the buffer
.export __src_start
.proc __src_start
	ldx cursorzp
	bne @done	; if LSB is !0, not the start
	ldx cursorzp+1
	cpx #>data
@done:	rts
.endproc

;*******************************************************************************
; GAPLEN
; Returns the length of the gap
; OUT:
;  - .XY: the length of the gap
.proc gaplen
	ldxy poststartzp
	sub16 cursorzp
	rts
.endproc

;*******************************************************************************
; ON LINE INSERTED
; Callback to handle a line insertion. Various state needs to be shifted when
; this occurs (breakpoints, etc.)
.proc on_line_inserted
	; TODO:
	; update debug info: find all line programs in the current file with
	; start lines greater than the current line and increment those
	jsr __src_get_filename
	jsr dbgi::getfileid

	; shift breakpoints
	jsr edit::currentfile
	sta r0
	lda #$01
	jmp dbg::shift_breakpointsd
.endproc

;*******************************************************************************
; ATCURSOR
; Returns the character at the cursor position.
; OUT:
;  - .A: the character at the current cursor position
.export __src_atcursor
.proc __src_atcursor
	decw cursorzp
	lda24 __src_bank, cursorzp
	incw cursorzp
	rts
.endproc
