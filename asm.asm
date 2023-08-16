.include "ctx.inc"
.include "codes.inc"
.include "errors.inc"
.include "expr.inc"
.include "file.inc"
.include "layout.inc"
.include "labels.inc"
.include "macro.inc"
.include "macros.inc"
.include "math.inc"
.include "memory.inc"
.include "string.inc"
.include "text.inc"
.include "util.inc"
.include "source.inc"
.include "state.inc"
.include "zeropage.inc"
.CODE

.BSS
;--------------------------------------
indirect=zp::asm ; 1=indirect, 0=absolute
indexed=zp::asm+1   ; 1=x-indexed, 2=y-indexed, 0=not indexed
immediate=zp::asm+2 ; 1=immediate, 0=not immediate
operandsz=zp::asm+3 ; size of the operand (in bytes) $ff indicates 1 or 2 byttes
cc=zp::asm+4
resulttype=zp::asm+5
label_value = zp::asm+6 ; param to addlabel
lsb = zp::asm+$a
msb = zp::asm+$b


.DATA
;--------------------------------------
NUM_OPCODES = 58
CC_00=0
CC_01=8
CC_10=16
CC_IMP=24
AAA_JMP=$02
AAA_JMP_IND=$03
opcodes:
; cc = 00
.byt $ff,$ff,$ff ; unused
.byt "bit" ; 001
.byt "jmp" ; 010
.byt "jmp" ; 011
.byt "sty" ; 100
.byt "ldy" ; 101
.byt "cpy" ; 110
.byt "cpx" ; 111
;cc = 01
.byt "ora" ; 000
.byt "and" ; 001
.byt "eor" ; 010
.byt "adc" ; 011
.byt "sta" ; 100
.byt "lda" ; 101
.byt "cmp" ; 110
.byt "sbc" ; 111
;cc = 10
.byt "asl" ; 000
.byt "rol" ; 001
.byt "lsr" ; 010
.byt "ror" ; 011
.byt "stx" ; 100
.byt "ldx" ; 101
.byt "dec" ; 110
.byt "inc" ; 111
opcode_branches:
; branch $10, $30, $50...
.byt "bpl"
.byt "bmi"
.byt "bvc"
.byt "bvs"
.byt "bcc"
.byt "bcs"
.byt "bne"
.byt "beq"
;implied + jsr
.byt "brk"
.byt "jsr"
.byt "rti"
.byt "rts"
.byt "php"
.byt "plp"
.byt "pha"
.byt "pla"
.byt "dey"
.byt "tay"
.byt "iny"
.byt "inx"
.byt "clc"
.byt "sec"
.byt "cli"
.byt "sei"
.byt "tya"
.byt "clv"
.byt "cld"
.byt "sed"
.byt "txa"
.byt "txs"
.byt "tax"
.byt "tsx"
.byt "dex"
.byt "nop"

opcodetab:
; cc=00
.byt $10, $30, $50, $70, $90, $B0, $D0, $F0 ;branches
.byt $00, $20, $40, $60
.byt $08, $28, $48, $68, $88, $A8, $C8, $E8
.byt $18, $38, $58, $78, $98, $B8, $D8, $F8
.byt $8A, $9A, $AA, $BA, $CA, $EA

; directives
directives:
.byte "db",0
.byte "eq",0
.byte "dw",0
.byte "inc",0
.byte "org",0
.byte "rep",0
.byte "mac",0
directives_len=*-directives

directive_vectors:
.word definebyte
.word defineconst
.word defineword
.word includefile
.word defineorg
.word repeat
.word macro
.CODE
;--------------------------------------
; validate verifies that the string at (YX) is a valid instrcution
; The size of the assembled operation is returned in .A (negative indicates an error occurred).
; If the instruction contains a label, this proc will check that it is a valid label, but
; it does not require that the label is defined.
.export __asm_validate
__asm_validate:
	jmp tokenize

;--------------------------------------
; tokenize assembles the string at (YX) into an instruction in (asm::result)
; if (YX) contains an instruction.  Any labels or comments encountered are
; saved at the address in (pc).
; in:
;  - .XY: the string to assemble
;  - zp::asmresult: pointer to the location to assemble the instruction
; out:
;  - .A: the type of the result e.g. ASM_OPCODE or the error code
;  - .C: set if an error occurred
.export __asm_tokenize
__asm_tokenize:
.proc tokenize
;flags
	stx zp::line
	sty zp::line+1

	jsr handle_ctx
	bcc @noctx
	RETURN_OK

@noctx:
	jsr process_ws

	ldy #$00
	sty indirect
	sty indexed
	sty operandsz
	sty immediate
	sty lsb
	sty msb

@full_line_comment:
	lda (zp::line),y
	cmp #';'
	bne @opcode
	; rest of the line is a comment, we're done
	lda #ASM_COMMENT
	sta resulttype
	RETURN_OK

@opcode:
	jsr getopcode
	bcs @macro
	lda #ASM_OPCODE
	sta resulttype
	txa
	ldy #$00
	sta (zp::asmresult),y
	jmp @getopws

@macro:
	ldxy zp::line
	jsr mac::get
	bcs @label
	pha
	jsr process_word	; read past macro name
	pla
	jsr assemble_macro
	bcs :+			; error
	inc $900f
	lda #ASM_MACRO
	sta resulttype
	clc
:	rts

@label:
	jsr lbl::isvalid
	bcs @directive
	sta resulttype
	ldx zp::line
	ldy zp::line+1
	lda zp::asmresult
	sta zp::label_value
	lda zp::asmresult+1
	sta zp::label_value+1
	jmp lbl::add

@directive:
	jsr getdirective
	bcc :+
	jmp @err
:	lda #ASM_DIRECTIVE
	sta resulttype
	jmp @getws2

; from here onwards we are either reading a comment or an operand
@getopws:
	jsr process_ws
	bne @pound
	jmp @done

@pound:
	ldy #$00
	lda (zp::line),y
	cmp #'#'
	bne @lparen
	inc immediate
	incw zp::line
	lda (zp::line),y
	jmp @hi_or_low_byte	; if immediate, skip parentheses (treat as part of expression)
@lparen:
	cmp #'('
	bne @hi_or_low_byte
	inc indirect
	incw zp::line
	lda (zp::line),y

@hi_or_low_byte:
	cmp #'<'
	bne :+
	inc lsb
	incw zp::line
:	cmp #'>'
	bne @abslabelorvalue
	inc msb
	incw zp::line

@abslabelorvalue:
	jsr expr::eval
	bcc @store_value
	rts

@store_value:
	sta operandsz
	lda lsb
	beq :+
	lda #$01
	sta operandsz
	bne @store_lsb
:	lda msb
	beq @store_msb
	lda #$01
	sta operandsz
	tya
	tax
	jmp @store_lsb
@store_msb:
	tya
	ldy #$02
	sta (zp::asmresult),y
@store_lsb:
	txa
	ldy #$01
	sta (zp::asmresult),y

@cont:
	ldy #$00
	lda indirect
	beq @index
@rparen:
; look for closing paren or ",X"
	lda (zp::line),y
	incw zp::line
	cmp #','
	bne @rparen_noprex
	lda (zp::line),y
	incw zp::line
	cmp #'x'
	beq :+
	jmp @err
:	lda (zp::line),y
	incw zp::line
	cmp #')'
	beq :+
	jmp @err
:	inc indexed
	jmp @getws2

@rparen_noprex:
	cmp #')'
	beq @index
	jmp @err

@index:
	ldy #$00
	lda (zp::line),y
	cmp #','
	bne @getws2
	incw zp::line
@getindexx:
	lda (zp::line),y
	cmp #'x'
	bne @getindexy
	inc indexed
	incw zp::line
@getindexy:
	cmp #'y'
	bne @getws2
	inc indexed
	inc indexed
	incw zp::line

@getws2:
	jsr process_ws

@comment:
	lda (zp::line),y
	beq @done
	cmp #';'
	; error- trailing garbage
	beq :+
	jmp @err

	; get length of comment
:	iny
	lda (zp::line),y
	bne :-

	ldx zp::line
	ldy zp::line+1
	; TODO: jsr addcomment

; done, create the assembled result based upon the opcode, operand, and addr mode
@done:
	lda resulttype
	cmp #ASM_OPCODE
	beq :+
	RETURN_OK	; if not an instruction, we're done

:	jsr getaddrmode
	bcc @checkjmp
	rts

@checkjmp:
	tax
	; JMP (xxxx) has a different opcode than JMP
	ldy #$00
	lda (zp::asmresult),y
	cmp #$40
	bne @getbbb
	lda cc
	bne @getbbb
	lda indirect
	beq @jmpabs

@jmpind:
	cpx #ABS_IND	; only abs-indirect is supported for JMP (XXXX)
	bne @err
	lda #$6c
	sta (zp::asmresult),y
	jmp @noerr
@jmpabs:
	cpx #ABS
	bne @err 	; only ABS supported for JMP XXXX
	lda #$4c
	sta (zp::asmresult),y
	jmp @noerr

@getbbb:
; get bbb bits based upon the address mode and @cc
	lda cc
	cmp #$03
	bne @validate_cc

	; check if opcode was a JSR
	lda (zp::asmresult),y
	cmp #$20
	bne :+
	cpx #ABS
	bne @err	; only ABS supported for JSR
	jmp @noerr

:	; check if opcode was a branch
	and #$1f
	cmp #$10
	bne @verifyimm

	cpx #ABS	; only ABS/ZP supported for branches
	bne @err
	; convert operand to relative address
	ldy #$01
	lda (zp::asmresult),y
	sec
	sbc zp::asmresult
	iny
	tax
	lda (zp::asmresult),y
	sbc zp::asmresult+1
	beq :+
	cmp #$ff
	beq :+
	bne @err		; address out of range

	; replace 2 byte operand with 1 byte relative address
:	txa
	sec
	sbc #$02	; offset is -2 from current instruction's address
	dey
	sta (zp::asmresult),y
	lda #$01
	sta operandsz
	jmp @noerr

@verifyimm:
	; remaining opcodes are single byte- implied/accumulator only
	cpx #IMPLIED
	beq @noerr
@err:	RETURN_ERR ERR_ILLEGAL_ADDRMODE

@noerr:
	; update asm::result pointer by (1 + operand size)
	lda state::verify
	bne :+
	lda operandsz
	sec
	adc zp::asmresult
	sta zp::asmresult
	bcc :+
	inc zp::asmresult+1
:	lda #ASM_OPCODE
	RETURN_OK

@validate_cc:
	ldy cc
	bne :+
	lda bbb00,x
:	cpy #$01
	bne :+
	lda bbb01,x
:	cpy #$02
	bne :+
	lda bbb10,x

:	cmp #$ff
	beq @err

	asl
	asl
	ora cc
	ldy #$00
	ora (zp::asmresult),y

@final_validate:
	; check for invalid instructions ("gaps" in the ISA)
	ldx #@num_illegals-1
:	cmp @illegal_opcodes,x
	beq @err
	dex
	bpl :-

	sta (zp::asmresult),y
	jmp @noerr

@illegal_opcodes:
.byte %10001001 ; STA #imm

.byte %00000010 ; ASL #imm
.byte %00100010 ; ROL #imm
.byte %01000010 ; LSR #imm
.byte %01100010 ; ROR #imm
.byte %10000010 ; STX #imm
.byte %11000010 ; DEC #imm
.byte %11100010 ; INC #imm
.byte %10001010 ; STX A
.byte %10101010 ; LDX A
.byte %11001010 ; DEC A
.byte %11101010 ; INC A
.byte %10011110 ; STX ABS,X

.byte %00100000 ; BIT #imm
.byte %00110100 ; BIT zp,x
.byte %00111100 ; BIT abs,x
.byte %10000000 ; STY #imm
.byte %10011100	; STY abs,x
.byte %11010100 ; CPY zp,x
.byte %11011100 ; CPY abs,x
.byte %11110100 ; CPX zp,x
.byte %11111100 ; CPX abs,x
@num_illegals = *-@illegal_opcodes

.endproc

;---------------------------------------
; getaddrmode returns the address mode according to the provided flags
.export getaddrmode
.proc getaddrmode
	; get addressing mode index for bbb tables
	lda operandsz
	cmp #$ff
	bne :+
	; if we don't know the size yet, check both zp and abs
	jsr @zp
	bcc @ok
	jmp @abs


:	cmp #$00
	beq @impl
	cmp #2
	beq @abs
	cmp #1
	beq @zp
@err:   RETURN_ERR ERR_OVERSIZED_OPERAND

;------------------
@zp:	lda immediate
	bne @imm
	ldx indexed
	lda indirect
	beq :+
	dex
	bpl :+
	; error- indirect zeropage not a valid addressing mode
@illegalmode:
	RETURN_ERR ERR_ILLEGAL_ADDRMODE
:	txa
	clc
	adc indirect
	adc indirect
	adc #ZEROPAGE
@ok:
	RETURN_OK

;------------------
@abs:   lda immediate
	bne @oversized	; error- immediate abs illegal (operand too large)
	lda indirect
	beq :+
	lda indexed
	bne @err 	; error- indirect absolute doesn't support indexing
	lda #ABS_IND
	RETURN_OK
:	lda indexed
	clc
	adc #ABS
	RETURN_OK

@imm:	lda indirect
	bne @illegalmode ; error- immediate doesn't support indirection
	lda indexed
	bne @illegalmode ; error- immediate doesn't support indexing
	lda #IMMEDIATE
	RETURN_OK

@impl:	lda #IMPLIED
@done:	RETURN_OK
@oversized:
	RETURN_ERR ERR_OVERSIZED_OPERAND
.endproc

;--------------------------------------
IMPLIED=0
IMMEDIATE=1
ABS=6
ABS_IND=9
ZEROPAGE=2

bbb01:
	.byte $ff ; implied/accumulator
	.byte $02 ; immediate
	.byte $01 ; zp
	.byte $05 ; zp,x
	.byte $00 ; (zp,x)
	.byte $04 ; (zp),y
	.byte $03 ; abs
	.byte $07 ; abs,x
	.byte $06 ; abs,y
	.byte $ff ; (abs)

bbb10:
	.byte $02 ; implied/accumulator
	.byte $00 ; immediate
	.byte $01 ; zp
	.byte $05 ; zp,x
	.byte $ff ; (zp,x)
	.byte $ff ; (zp),y
	.byte $03 ; abs
	.byte $07 ; abs,x
	.byte $ff ; abs,y
	.byte $ff ; (abs)

bbb00:
	.byte $ff ; implied/accumulator
	.byte $00 ; immediate
	.byte $01 ; zp
	.byte $05 ; zp,x
	.byte $ff ; (zp,x)
	.byte $ff ; (zp),y
	.byte $03 ; abs
	.byte $07 ; abs,x
	.byte $ff ; abs,y
	.byte $ff ; (abs)

MODE_IMMEDIATE=$01
MODE_ZP=$02
MODE_ABS=$04
MODE_INDIRECT=$08
MODE_X_INDEXED=$10
MODE_Y_INDEXED=$20
MODE_IMPLIED=$40

bbb_modes:
bbb00_modes:
	.byte MODE_IMMEDIATE | MODE_ZP	; 000
	.byte MODE_ZP		; 001
	.byte $ff		; 010
	.byte MODE_ABS		; 011
	.byte $ff		; 100
	.byte MODE_ZP | MODE_X_INDEXED ; 101
	.byte $ff		; 110
	.byte MODE_ABS | MODE_X_INDEXED	; 111
bbb01_modes:
	.byte MODE_ZP | MODE_X_INDEXED | MODE_INDIRECT
	.byte MODE_ZP
	.byte MODE_IMMEDIATE | MODE_ZP
	.byte MODE_ABS
	.byte MODE_ZP | MODE_INDIRECT | MODE_Y_INDEXED
	.byte MODE_ZP | MODE_X_INDEXED
	.byte MODE_ABS | MODE_Y_INDEXED
	.byte MODE_ABS | MODE_X_INDEXED

bbb10_modes:
	.byte MODE_IMMEDIATE 	; 000
	.byte MODE_ZP		; 001
	.byte MODE_IMPLIED	; 010
	.byte MODE_ABS		; 011
	.byte $ff		; 100
	.byte MODE_ZP | MODE_X_INDEXED ; 101
	.byte $ff		; 110
	.byte ABS | MODE_X_INDEXED	; 111

;--------------------------------------
; gettext parses an enquoted text string and returns it in mem::spare
; returns the length in .A ($ff if no string was found)
.proc gettext
	ldy #$00
	lda (zp::line),y
	cmp #'"'
	bne @err

	ldx #$00
@l0:
	incw zp::line
	lda (zp::line),y
	beq @err	; no closing quote
	cmp #'"'
	beq @done
	sta mem::spare,x
	inx
	bne @l0
@done:
	incw zp::line
	txa
	RETURN_OK
@err:	RETURN_ERR ERR_SYNTAX_ERROR
.endproc


;--------------------------------------
; getopcode returns ASM_OPCODE if (line) contains an opcode.
; Returns:
;  - .A: ASM_OPCODE (on success) else error
;  - .X: the opcode's ID
;  - .C: set if (line) is not an opcode
;  - tmp9: updated with the .CC part of the opcode
.proc getopcode
@optab = zp::tmp6
@op = zp::tmp8
	lda #$00
	sta @op
	sta cc

	ldx #<opcodes
	ldy #>opcodes
	stx @optab
	sty @optab+1

@l0:	ldy #$02
@l1:	lda (zp::line),y
	cmp (@optab),y
	bne @next
	dey
	bpl @l1

	; make sure there are no trailing characters
	ldy #$03
	lda (zp::line),y
	beq @done
	jsr util::is_whitespace
	beq @done
	jmp @err

@done:	lda @op
	tax
	cmp #CC_01
	bcc @setcc
	inc cc
	cmp #CC_10
	bcc @setcc
	inc cc
	cmp #CC_IMP
	bcc @setcc
	inc cc

	; look up the opcode from a table
	sbc #CC_IMP
	tax
	lda opcodetab,x
	tax
	jmp @return

@setcc:	asl
	asl
	asl
	asl
	asl
	tax

@return:
	; update line ptr and return
	lda zp::line
	clc
	adc #$03
	sta zp::line
	bcc :+
	inc zp::line+1
:	RETURN_OK

@next:	lda @optab
	clc
	adc #$03
	sta @optab
	bcc :+
	inc @optab+1
:	inc @op
	lda @op
	cmp #NUM_OPCODES
	bcc @l0

@err:	RETURN_ERR ERR_ILLEGAL_OPCODE
.endproc

;--------------------------------------
; GETDIRECTIVE
; checks if (zp::line) contains a directive and handles it if it does.
; out:
;  - .C: if set, the contents of zp::line is not a directive
.proc getdirective
@cnt=zp::tmp2
	ldy #$00
	lda (zp::line),y
	cmp #'.'
	beq :+
	RETURN_ERR ERR_INVALID_DIRECTIVE

:	ldx #$00
	stx @cnt
	dex
@l0:	ldy #$00
	inx
@l1:	lda directives,x
	beq @found
	inx
	iny
	cmp (zp::line),y
	beq @l1

	cpx #directives_len
	bcc :+
	lda #$ff	; no match
	RETURN_ERR ERR_INVALID_DIRECTIVE

:	inc @cnt
	dex
@l2:
	inx
	lda directives,x ; move to next directive
	beq @l0
	cpx #directives_len
	bcc @l2
	RETURN_ERR ERR_INVALID_DIRECTIVE

@found:
	tya
	sec		; +1
	adc zp::line
	sta zp::line
	bcc :+
	inc zp::line+1
:	jsr processws

	lda @cnt
	asl
	tax
	lda directive_vectors,x
	sta @vec
	lda directive_vectors+1,x
	sta @vec+1
@vec=*+1
	jmp $fadd
.endproc

;--------------------------------------
; HANDLE_REPEAT
; context handler for .rep/.endrep blocks
.proc handle_repeat
	ldxy #mem::linebuffer
	jsr ctx::write		; copy the linebuffer to the context
	ldxy #mem::linebuffer
	streq @endrep, 7	; are we at .endrep?
	beq @do_rep		; yes, assemble the REP block
	RETURN_OK

@do_rep:
	; disable the context for assembling
	lda #$00
	sta ctx::type

@l0:	; define a label with the value of the iteration
	jsr ctx::rewind
	ldxy zp::ctx+repctx::iter
	stxy zp::label_value
	ldxy zp::ctx+repctx::params
	jsr lbl::add

@l1:	; assemble the lines until .endrep
	jsr ctx::getline
	bcc :+
	rts			; propagate error, exit
:	streq @endrep, 7	; are we at .endrep?
	beq @next		; yep, do next iteration
	ldxy #mem::ctxbuffer

	; save the context
	lda zp::ctx
	pha
	lda zp::ctx+1
	pha

	jsr __asm_tokenize ; nope, assemble and repeat
	bcc :+
	rts	; return err

:	; restore the context
	pla
	sta zp::ctx+1
	pla
	sta zp::ctx

	jmp @l1

@next:	; increment iterator and repeat if there are more iterations left
	incw zp::ctx+repctx::iter
	ldxy zp::ctx+repctx::iter
	cmpw zp::ctx+repctx::iter_end
	bne @l0

@done:
	ldxy zp::ctx+repctx::params
	jsr lbl::del	; delete the iterator label
	jsr ctx::pop	; pop the context
	RETURN_OK

@endrep: .byte ".endrep"
.endproc

;--------------------------------------
; HANDLE_CTX
; out:
;  - .C: set if the line was handled by this handler
.proc handle_ctx
	; if verifying, don't handle context at all
	lda state::verify
	bne @done

	lda ctx::type
	beq @done
	lda ctx::type
	and #CTX_REPEAT
	beq :+
	jsr handle_repeat
	sec		; flag context handled
	rts
:	lda ctx::type
	and #CTX_MACRO
	beq @done
	jsr handle_macro
	sec		; flag context handled
	rts
@done:	clc
	rts
.endproc

;--------------------------------------
.proc processws
	ldy #$00
	lda (zp::line),y
	cmp #' '
	bne @done
@l0:
	incw zp::line
	lda (zp::line),y
	cmp #' '
	beq @l0
@done:
	rts
.endproc

;--------------------------------------
; processstring reads all characters until the next whitespace
.proc processstring
	ldy #$00
	lda (zp::line),y
	jsr util::is_whitespace
	beq @done
@l0:
	incw zp::line
	lda (zp::line),y
	jsr util::is_whitespace
	bne @l0
@done:
	rts
.endproc


;--------------------------------------
; defines 0 or more bytes and stores them in (asmresult)
; Returns the number of bytes written in .A
.proc definebyte
	ldxy zp::line
	jsr expr::getval
	bcs @text
	cmp #$01
	bne @err	; over/undersized value
	; store the extracted value
	ldy #$00
	txa
	sta (zp::asmresult),y
	incw zp::asmresult
	jmp @commaorws

@text:	jsr gettext
	bcs @err
	; store the extracted text
	tay
	tax
	beq @done
	dex
	dey
:	lda mem::spare,y
	sta (zp::asmresult),y
	dey
	bpl :-
	txa
	sec
	adc zp::asmresult
	sta zp::asmresult
	bcc :+
	inc zp::asmresult+1
:	txa
	rts

@commaorws:
	ldy #$00
	lda (zp::line),y
	beq @done
	incw zp::line
	cmp #','
	beq definebyte
	cmp #' '
	beq @commaorws
	; unexpected character
@err:	lda #$ff
@done:	rts
.endproc

;--------------------------------------
.proc defineword
	ldxy zp::line
	jsr expr::getval
	bcs @err
	; store the extracted value
	tya
	ldy #$01
	sta (zp::asmresult),y
	txa
	dey
	sta (zp::asmresult),y
	incw zp::asmresult
	incw zp::asmresult
@commaorws:
	ldy #$00
	lda (zp::line),y
	beq @done
	incw zp::line
	cmp #','
	beq defineword
	cmp #' '
	beq @commaorws
	; unexpected character
@err:	lda #$ff
@done:	rts
.endproc

;--------------------------------------
; include file assembles the contents of the given file
.proc includefile
@filename=$100
	jsr processws
	ldy #$00
@quote1:
	lda (zp::line),y
	cmp #'"'
	bne @err
	ldx #$00
	incw zp::line
@getfilename:
	lda (zp::line),y
	jsr util::is_whitespace
	beq @err
	cmp #'"'
	beq @readfile
	sta @filename,x
	incw zp::line
	inx
	bne @getfilename

@readfile:
	lda #$00
	sta @filename,x
	ldxy #@filename
	jsr file::open
	sta zp::file

@doline:
	ldxy #mem::spare
	lda zp::file
	jsr file::getline
	bcs @err
	cmp #$00
	beq @done
	ldxy #mem::spare
	jsr __asm_tokenize
	jmp @doline

@done:
@err:	lda zp::file
	jmp file::close
.endproc

;--------------------------------------
.proc defineorg
	jsr processws
	ldxy zp::line
	jsr expr::getval
	bcs :+
	stxy zp::asmresult
:	rts
.endproc

;--------------------------------------
.proc defineconst
	jsr lbl::isvalid
	bcs @err
	lda zp::line	; save label name's address
	pha
	lda zp::line+1
	pha
	jsr processstring	; move past label name
	jsr processws		; eat whitespace
	jsr expr::getval	; get constant value
	bcc :+
	pla
	pla
@err:
	rts
:	stx zp::label_value
	sty zp::label_value+1
	pla
	tay
	pla
	tax
	jmp lbl::add
.endproc

;--------------------------------------
; repeat generates assembly for the parameterized code between this directive
; and the lines that follow until '.endrep'
; .rep 10,I
;   asl
; .endrep
; will produce 10 'asl's
.proc repeat
	jsr ctx::push	; push a new context

	jsr expr::eval ; get the number of times to repeat the code
	bcc @ok
	rts	 ; error

@ok:
	stxy zp::ctx+repctx::iter_end
	jsr process_ws
	ldy #$00
	lda (zp::line),y
	cmp #','
	beq :+
	RETURN_ERR ERR_SYNTAX_ERROR ; comma must follow the # of times to repeat

:	; get the name of the parameter
	incw zp::line
	ldy #$00
@saveparam:
	ldxy zp::line
	jsr ctx::addparam
	bcc @cont
	rts		; err

@cont:
	stxy zp::line
	lda #$00
	sta zp::ctx+repctx::iter
	sta zp::ctx+repctx::iter+1
	lda #CTX_REPEAT
	sta ctx::type
	RETURN_OK
.endproc

;--------------------------------------
; macro begins the definition of a macro, which will
; continue until '.endmac' is found
; and the lines that follow until '.endrep'
; .mac add8 A, B
;   lda #A
;   clc
;   adc #B
; .endmac
; will define a macro that can be used like:
;   add8 10, 20
.proc macro
	jsr ctx::push	; push a new context

@getparams:
	jsr process_ws
	ldy #$00
	lda (zp::line),y
	beq @done
	ldxy zp::line
	jsr ctx::addparam
	stxy zp::line
	bcc @getparams
	rts		; err

@done:
	lda #CTX_MACRO
	sta ctx::type
	RETURN_OK
.endproc

;--------------------------------------
; HANDLE_MACRO
; when the macro context is active, reads the the current line into the
; context buffer until .ENDMAC is encountered.
; Upon encountering .ENDMAC, the macro is saved into
; (macros)
.proc handle_macro
	ldxy #mem::linebuffer
	jsr ctx::write		; copy the linebuffer to the context
	ldxy #mem::linebuffer
	streq @endmac, 7	; are we at .endmac?
	beq @createmac
	rts			; nope, we're done

@createmac:
	; done with this context, disable it
	lda #$00
	sta ctx::type

	ldxy #$100
	jsr ctx::getparams
	ldxy #$100
	stxy zp::tmp0
	pha
	jsr ctx::getdata
	pla
	jmp mac::add

@endmac: .byte ".endmac"
.endproc

;--------------------------------------
; process_ws reads (line) and updates it to point past ' ' chars.
; .A contains the last character processed on return
; .Z is set if we're at the end of the line ($00)
.proc process_ws
	ldy #$00
	lda (zp::line),y
	beq @done
	cmp #' '
	bne @done
	incw zp::line
	jmp process_ws
@done:	rts
.endproc

;--------------------------------------
; process_word reads (line) and updates it to point past non whitespace chars.
; .A contains the last character processed on return
; .Z is set if we're at the end of the line ($00)
.proc process_word
	ldy #$00
	lda (zp::line),y
	beq @done
	cmp #' '
	beq @done
	incw zp::line
	jmp process_word
@done:	rts
.endproc


;--------------------------------------
; process_end_of_Line reads (line) and updates it to point to the terminating 0
; .C is set if any invalid characters were encountered
.proc process_end_of_line
@l0:
	ldy #$00
	lda (zp::line),y
	beq @done
	cmp #' '
	beq @next
	cmp #';'
	bne @err
@cmnt:
	; read comment
	lda (zp::line),y
	beq @done
	incw zp::line
	jmp @cmnt
@next:
	incw zp::line
	jmp @l0

@err:	RETURN_ERR ERR_SYNTAX_ERROR
@done:	RETURN_OK
.endproc

;--------------------------------------
; reset resets the internal assembly context (labels and pointer to target)
.export __asm_reset
.proc __asm_reset
	ldxy #mem::program
	stxy zp::asmresult
	jsr ctx::init
	jsr mac::init
	jmp lbl::clr
.endproc

;--------------------------------------
; disassemble disassembles the instruction given at .YX
; the target buffer to write to is given in zp::tmp0
.export __asm_disassemble
.proc __asm_disassemble
@dst=zp::tmp0
@cc=zp::tmp2
@op=zp::tmp3
@operand=zp::tmp4

@optab=zp::tmp7
@cc8=zp::tmp7
@xxy=zp::tmp7
@cc8_plus_aaa=zp::tmp7
@modes=zp::tmp7

@bbb=zp::tmp8
@aaa=zp::tmp9
@opaddr=zp::tmpa
	stxy @opaddr
	ldy #$00
	lda (@opaddr),y
	sta @op
	iny
	lda (@opaddr),y
	sta @operand
	iny
	lda (@opaddr),y
	sta @operand+1

; check for branches/exceptions
	lda @op
	and #$0f
	bne @not_branch
@branch:
	; get bits 5, 6 and 7 to determine branch type
	lda @op
	asl
	rol
	rol
	rol
	and #$07
	clc
	adc #$01
	sta @xxy
	asl
	adc @xxy
	tax
	ldy #$02
:	dex
	lda opcode_branches,x
	sta (@dst),y
	dey
	bpl :-

	lda @dst
	clc
	adc #$03
	sta @dst
	bcc @get_branch_target
	inc @dst+1

@get_branch_target:
	; calculate target address PC+2+operand
	; sign extend the operand
	lda @operand
	and #$80
	beq :+
	lda #$ff
	skw
:	lda #$00
	sta @operand+1

	; operand + opaddr + 2
	lda @operand
	clc
	adc @opaddr
	sta @operand
	lda @operand+1
	adc @opaddr+1
	sta @operand+1
	lda #$02
	clc
	adc @operand
	sta @operand
	lda @operand+1
	adc #$00
	sta @operand+1
	lda #MODE_ABS
	sta @modes
	jmp @cont ; @operand now contains absolute address, display it

@not_branch:
	lda @op
	and #$03	; get cc
	sta @cc
	; get opcodes table offset (each block is 8 opcodes)
	asl
	asl
	asl
	sta @cc8

	; get aaa - opcode offset (each mneumonic is 3 bytes)
	lda @op
	asl
	rol
	rol
	rol
	and #$07
	clc
	adc @cc8
	sta @cc8_plus_aaa
	asl
	adc @cc8_plus_aaa
	adc #<opcodes
	sta @optab
	lda #>opcodes
	adc #$00
	sta @optab+1

	; write the opcode (optab),aaa to the destination
	ldy #$02
:	lda (@optab),y
	sta (@dst),y
	dey
	bpl :-

	lda @dst
	clc
	adc #$03
	sta @dst
	bcc @get_addrmode
	inc @dst+1

@get_addrmode:
	; get bbb and find the addressing mode for the instruction
	lda @op
	lsr
	lsr
	and #$07
	sta @bbb

	; get the cc offset into the bbb_modes table
	lda @cc
	asl
	asl
	asl
	adc @bbb	; add bbb to get the table position of our instruction
	tax

	; if implied, we're done
	lda bbb_modes,x
	sta @modes
	and #IMPLIED
	beq @cont
@implied:
	RETURN_OK

@cont:
	; add a space before operand
	ldy #$00
	lda #' '
	sta (@dst),y
	incw @dst

	; draw the opcode
	ldy #$00
@drawop:
	lda @modes
	and #MODE_INDIRECT
	beq :+
@indirect:
	lda #'('
	sta (@dst),y
	incw @dst

:	lda @modes
	and #MODE_IMMEDIATE
	beq :+
@immediate:
	lda #'#'
	sta (@dst),y
	incw @dst

:	lda @modes
	and #MODE_ZP
	beq :+
@zeropage:
	ldy #$00
	lda #'$'
	sta (@dst),y
	incw @dst
	lda @operand
	jsr util::hextostr
	tya
	ldy #$00
	sta (@dst),y
	txa
	iny
	sta (@dst),y
	incw @dst
	incw @dst

:	lda @modes
	and #MODE_ABS
	beq :+
@absolute:
	ldy #$00
	lda #'$'
	sta (@dst),y
	incw @dst
	lda @operand+1
	jsr util::hextostr
	tya
	ldy #$00
	sta (@dst),y
	txa
	iny
	sta (@dst),y
	incw @dst
	incw @dst
	lda @operand
	jsr util::hextostr
	tya
	ldy #$00
	sta (@dst),y
	txa
	iny
	sta (@dst),y
	incw @dst
	incw @dst

:	lda @modes
	and #MODE_X_INDEXED
	beq :+
@xindexed:
	lda #','
	sta (@dst),y
	incw @dst
	lda #'x'
	sta (@dst),y
	incw @dst

:	lda @modes
	and #MODE_INDIRECT
	beq :+
@indirect2:
	lda #')'
	sta (@dst),y
	incw @dst

:	lda @modes
	and #MODE_Y_INDEXED
	beq @done
@yindexed:
	lda #','
	sta (@dst),y
	incw @dst
	lda #'y'
	sta (@dst),y
@done:
	RETURN_OK
.endproc

;--------------------------------------
; ASSEMBLE_MACRO
; takes the contents of (line) and expands it to the corresponding
; macro.
; in:
;  - .A the id of the macro to assemble
.proc assemble_macro
@cnt=zp::macros+$0e
@params=zp::macros
	pha

	ldx #$fe
@l0:	ldy #$00
	inx
	inx
@l1:	lda (zp::line),y
	beq @done
	iny
	cmp #' '
	bne @l1

	stx @cnt
	jsr process_ws
	jsr expr::eval
	bcc :+
	pla	; clean stack
	RETURN_ERR ERR_INVALID_EXPRESSION

:	txa
	ldx @cnt
	sta @params,x
	tya
	sta @params+1,x

	ldy #$00
@nextparam:
	lda (zp::line),y ; read unitl comma or endline
	beq @done
	cmp #';'
	beq @done
	incw zp::line
	cmp #','
	beq :+
	cmp #' '
	beq @nextparam
	RETURN_ERR ERR_INVALID_MACRO_ARGS

:	jmp @l0

@done:	pla

	lda state::verify
	beq :+
	RETURN_OK
:	jmp mac::asm
.endproc
