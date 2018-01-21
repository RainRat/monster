.include "asm.inc"
.include "bitmap.inc"
.include "codes.inc"
.include "cursor.inc"
.include "format.inc"
.include "irq.inc"
.include "key.inc"
.include "layout.inc"
.include "memory.inc"
.include "source.inc"
.include "text.inc"
.include "util.inc"
.include "view.inc"
.include "zeropage.inc"

.import test

;------------------------------------------------------------------------------
.segment "SETUP"
.word head 
head: .word @Next 
.word .version
.byte $9e 
.asciiz "4621"
@Next: .word 0 
;------------------------------------------------------------------------------
start:
        ldx #<irq_handler
        ldy #>irq_handler 
        lda #$20
        jsr irq::raster
        jmp enter

;------------------------------------------------------------------------------
.CODE
enter:
        jsr bm::init
        jsr bm::clr

	lda #$00
	sta zp::curx
	sta zp::cury

	;jsr test

;------------------------------------------------------------------------------
; lineedit is the main loop for editing a line.
lineedit:
	jsr startline
main:
        lda #$05
        cmp $9004
        bne *-3

	jsr key::getch
	cmp #$00
	bne :+
	jmp done

:	cmp #$91	; up arrow?
	bne :+
	jmp uparrow
:	pha
	jsr insert
	pla
	cmp #$0d
	beq @linedone
	jmp done

@linedone:
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr asm::tokenize
	tax
	bmi @err

	pha
	jsr asm::advancepc

	; format line
	pla
	bne :+
	lda #ASM_LABEL
	bne :++
:	lda #ASM_OPCODE
:	jsr fmt::line

	; copy line to source buffer
	pha
	jsr text::drawline
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	pla
	jsr src::puts
	jsr text::hioff

	; display memory (if view is enabled)
	ldx #<src::buffer
	ldy #>src::buffer
	jsr view::mem

@noerr: jsr text::drawline
	lda #$01
	sta text::insertmode
	jmp @newl
	
	jsr text::clrline
	lda #ERROR_ROW
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr text::puts
	ldx #$08
	lda zp::cury
	jsr text::hiline
	jmp @newl

@err:	lda #$ff
	jsr fmt::line
	lda #$00
	sta zp::curx
	lda zp::cury
	ldx #$2a
	jsr text::hiline
	lda #$00
	sta text::insertmode
	jmp @txtdone
	
@newl:	ldy zp::cury
	iny
	ldx #$00
	jsr cur::set

	lda #39
	sta zp::tmp0
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	lda #$00
	jsr util::memset

	jsr text::update
	jsr text::status
	jmp lineedit

@txtdone:
maindone:
	jsr cur::on
done:	jsr text::update
	jsr text::status
	jmp main

irq_handler:
        jmp $eabf

;------------------------------------------------------------------------------
uparrow:
	jsr cur::off
	lda zp::curx
	jsr src::lineup ; move up a line in the buffer

	lda zp::cury
	bne @noscroll
@scroll:
	jsr refresh
	jmp done
@noscroll:
	dec zp::cury
	jmp done 

;------------------------------------------------------------------------------
; refresh redraws all the visible lines.
.proc refresh
@src=zp::tmp0
@row=zp::tmp2
	lda #$00
	sta @row

	lda src::cur
	sta @src
	lda src::cur+1
	sta @src+1
	
	ldy #$00
@l0:	lda (@src),y
	cmp #$0d
	beq @next
	cpy #40
	bcs :+	; if past col 40, we can't draw the rest of the line
	sta mem::linebuffer,y
:	jmp @l0

@next:	lda @row
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr text::puts

	jsr src::getline
	cmp #$ff
	beq @done
	lda @row
	inc @row
	cmp #23
	bcc @l0

@done:	rts
.endproc

;------------------------------------------------------------------------------
.proc startline
@cur=zp::tmp0
	ldx src::cur
	ldy src::cur+1
	stx @cur
	sty @cur+1

	; copy the contents of the line to the linebuffer
	ldy #$00
@l1:	lda (@cur),y
	beq @done
	sta mem::linebuffer,y
	iny
	cmp #$0d
	bne @l1
@done:	lda #$00
	sta mem::linebuffer,y
	rts
.endproc

;------------------------------------------------------------------------------
; linelen returns the length of mem::linebuffer in .X
.proc linelen
	ldx #$ff
@l0:	inx
	lda mem::linebuffer,x
	beq @done
	cpx #40
	bcs @done
	bne @l0
@done:	rts
.endproc

;------------------------------------------------------------------------------
; insert adds a character at the cursor position.
.proc insert
	cmp #$80
	bcs :+
	cmp #' '
	bcs printable
:	
controlcodes:
	cmp #$14
	beq del
	jmp put
del:	lda zp::curx
	beq done
	lda text::insertmode
	beq @deldone
	jsr linelen
	stx zp::tmp0
	ldx zp::curx
	dex
@l0:	lda mem::linebuffer+1,x
	sta mem::linebuffer,x
	inx
	cpx zp::tmp0
	bcc @l0
	jsr text::drawline
@deldone:
	dec zp::curx
	jmp done

printable:
	ldx text::insertmode
	beq put ; 0 = replace, skip bumping the buffer
	pha
	jsr linelen
@l0:	lda mem::linebuffer,x
	sta mem::linebuffer+1,x
	cpx zp::curx
	beq ins
	dex
	bpl @l0

ins:	pla
put:	jsr text::putch
done:	rts
.endproc

;------------------------------------------------------------------------------
; printline prints the line at the cursor position.
.proc printline

.endproc
