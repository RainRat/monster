.include "codes.inc"
.include "text.inc"
.include "zeropage.inc"

ERROR_ROW = 22

line = zp::tmp0

.CODE

;--------------------------------------
; errors
ERR_UNALIGNED_LABEL=1
err_unaligned_label:
	.byte "label not in leftmost column",0
ERR_ILLEGAL_OPCODE=2
err_illegal_opcode:
	.byte "unknown opcode: A",0
ERR_ILLEGAL_ADDRMODE=3
err_illegal_addrmode:
	.byte "invalid addressing mode: A",0
ERR_ILLEGAL_DIRECTIVE=4
err_illegal_directive:
	.byte "unknown directive: A",0

errors:
	.word err_unaligned_label
	.word err_illegal_opcode
	.word err_illegal_addrmode
	.word err_illegal_directive

;--------------------------------------
NUM_OPCODES = 22
opcodes:
; cc = 00
.byt "BIT" ; 001
.byt "JMP" ; 010/011
.byt "STY" ; 100
.byt "LDY" ; 101
.byt "CPY" ; 110
.byt "CPX" ; 111
;cc = 01
.byt "ORA" ; 000
.byt "AND" ; 001
.byt "EOR" ; 010
.byt "ADC" ; 011
.byt "STA" ; 100
.byt "LDA" ; 101
.byt "CMP" ; 110
.byt "SBC" ; 111
;cc = 10
.byt "ASL" ; 000
.byt "ROL" ; 001
.byt "LSR" ; 010
.byt "ROR" ; 011
.byt "STX" ; 100
.byt "LDX" ; 101
.byt "DEC" ; 110
.byt "INC" ; 111

;--------------------------------------
; report error prints the error in .A
.export __asm_reporterr
.proc __asm_reporterr
	asl
	tax
	lda errors,x
	tax
	ldy errors+1,x
	lda #ERROR_ROW
	jsr text::puts
	rts
.endproc

;--------------------------------------
; asm_opcode assembles the opcode in (line)
.proc asm_opcode
	ldy #$00
	lda (line),y
.endproc

;--------------------------------------
; tokenize tokenizes the line in (<X/>Y) into @tokens.
.proc tokenize
; tokenization states
STATE0 = 0
STATE_GET_OPERAND = 1
STATE_GET_COMMENT = 2
@i = zp::tmp2
@state = zp::tmp3
	stx line
	sty line

	lda #$00
	sta @i
@nexttok:
	sta @state
	ldy @i
	lda (line),y
	cmp #' '
	beq @nexttok
@tok:	jsr isopcode
	bne :+
	jsr asm_opcode
	lda #STATE_GET_OPERAND
	jmp @nexttok
:	rts
.endproc

;--------------------------------------
.proc islabel
	ldy #$00
:	lda (line),y
	iny
	cpy #40
	bcs @notlabel
	cmp #':'
	bne :-

@done:	lda #ASM_LABEL
	rts
@notlabel:
	lda #-1
	rts
.endproc

;--------------------------------------
.proc isopcode
@optab = zp::tmp2
@op = zp::tmp4
	lda #$00
	sta @op

	ldx #<opcodes-1
	ldy #>opcodes-1
	stx @optab
	sty @optab+1

	ldx #3
	ldy #0
@l0:	iny
@l1:	lda (line),y
	cmp (@optab),y
	bne @next
	dex
	bne @l0

@done:	lda #$00
	rts

@next:	lda @optab
	adc #$03
	sta @optab
	bcc :+
	inc @optab+1
:	inc @op
	lda @op
	cmp #NUM_OPCODES
	bcc @l0

@err:	lda #ERR_ILLEGAL_OPCODE
	rts
.endproc

;--------------------------------------
.export __asm_compile
.proc __asm_compile
	stx line
	sty line+1

	ldy #$00
	ldx #$00
@next:  jsr islabel
	bpl @done
	jsr isopcode
	bpl @done
	lda #$00
@label:
@err:	
@done: 	rts
.endproc

;--------------------------------------
; findlabel returns the address that the label in (YX) (length in .A) 
; corresponds to.
.export __asm_findlabel
.proc __asm_findlabel
@label=zp::tmp0
@tab=zp::tmp2
@len = zp::tmp4
@id=zp::tmp5
	stx @label
	sty @label+1
	sta @len

	ldy #$00
	sty @id
	sty @id+1
@l0:	lda @len
	cmp (@tab),y
	bne @next
	
	tay
@strcmp:
	lda (@tab),y 
	cmp (@label),y
	dey
	bpl @strcmp
@found:	lda @id
	asl
	rol @id+1
	adc label_addresses
	sta @label
	lda @id+1
	adc label_addresses+1
	sta @label+1
	ldy #$00
	lda (@label),y
	tax
	iny
	lda (@label),y
	tay
	rts

@next:	lda @label
	clc
	adc @label
	sta @label
	bcc @l0
	inc @label+1
:	bcs @l0

	rts
.endproc

;--------------------------------------
; addlabel adds a label of .A len in (YX) to the label table.
.export __asm_addlabel
.proc __asm_addlabel
@label=zp::tmp0
@savey=zp::tmp2
	pha
	sty @savey

	lda #<__asm_labels
	sta @label
	lda #>__asm_labels
	sta @label+1

	ldy #$00
@l0:	lda (@label),y
	beq @found
	lda @label
	clc
	adc @label
	sta @label
	bcc @l0
	inc @label+1
:	bcs @l0

@found: pla
	ldy #$00
	sta (@label),y
	iny
	txa
	sta (@label),y
	iny
	lda @savey
	sta (@label),y

	rts
.endproc

;--------------------------------------
.export __asm_labels
labels: .res 1024 * 16
numlabels: .byt 0
label_addresses: .res 1024 * 2


