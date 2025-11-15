.include "asm.inc"
.include "errors.inc"
.include "labels.inc"
.include "macros.inc"
.include "string.inc"
.include "zeropage.inc"

.include "ram.inc"

;*******************************************************************************
; CONSTANTS
MAX_MACROS = 128

.export macro_addresses
.export macros

;*******************************************************************************
; VARS
.segment "MACRO_VARS"

;*******************************************************************************
nummacros:       .byte 0
macro_addresses: .res MAX_MACROS * 2

;*******************************************************************************
; BSS
.segment "MACROBSS"

macros:          .res $1400

;*******************************************************************************
; MACRO FORMAT:
;
;    | size (bytes)  |  description              |
;    |-------------------------------------------|
;    |      0-16     | macro name                |
;    |       1       | number of parameters      |
;    |      0-16     | parameter 0 name          |
;    |      ...      | parameter n name          |
;    |     0-255     | macro definition          |
;    |       1       | terminating 0             |

.segment "MACROCODE"

;*******************************************************************************
; MAC_INIT
; Initializes the macro state by removing all existing macros
.export __mac_init
.proc __mac_init
	lda #$00
	sta nummacros

	; init address for first macro that will be created
	ldxy #macros
	stxy macro_addresses
	rts
.endproc

;*******************************************************************************
; MAC_ADD
; Adds the macro to the internal macro state.
; IN:
;  - .XY: pointer to the macro definition
;     This will not contain the .MAC but does end with .ENDMAC)
;  - .A: number of parameters
;  - r0: pointer to parameters as a sequence of 0-terminated strings
.export __mac_add
.proc __mac_add
@src=zp::macros
@dst=zp::macros+2
@addr=zp::macros+4
@params=r0
@numparams=r2
	sta @numparams
	stxy @src
	lda nummacros
	asl
	adc #<macro_addresses
	sta @addr
	lda #>macro_addresses
	adc #$00
	sta @addr+1

	; get the address to write the macro to
	ldy #$00
	lda (@addr),y
	sta @dst
	iny
	lda (@addr),y
	sta @dst+1

; copy the name of the macro (parameter 0)
	dey
@copyname:
	lda (@params),y
	STOREB_Y @dst
	php
	incw @dst
	incw @params
	plp
	bne @copyname

	; store the number of parameters
	dec @numparams	; decrement to get the # without the macro name
	lda @numparams
	sta (@dst),y
	incw @dst

	; store the parameters if there are any
	lda @numparams
	beq @paramsdone
@copyparams:
	lda (@params),y
	STOREB_Y @dst
	php
	incw @dst
	incw @params
	plp
	bne @copyparams
	dec @numparams
	bne @copyparams

; copy the macro definition byte-by-byte til we get to .endmac
@paramsdone:
@l0:	ldy #$00
	lda (@src),y
	cmp #'.'
	bne @next
	ldxy @src
	stxy zp::str0
	ldxy #endmac
	stxy zp::str2
	lda #7			; strlen(endmac)+1
	jsr strcmp
	beq @done

@next:	STOREB_Y @dst
	incw @src
	incw @dst
	bne @l0

@done:  ; 0-terminate the macro definition
	lda #$00
	tay
	STOREB_Y @dst
	incw @dst
	STOREB_Y @dst

	; done copying use the end address as the start address for the next macro
	inc nummacros
	lda nummacros
	asl
	adc #<macro_addresses
	sta @addr
	lda #>macro_addresses
	adc #$00
	sta @addr+1
	ldy #$00
	lda @dst
	sta (@addr),y
	iny
	lda @dst+1
	sta (@addr),y
	RETURN_OK
.endproc

;*******************************************************************************
; ASM
; Expands the given macro using the provided parameters and assembles it.
; IN:
;  - .A:                id of the macro
;  - zp::mac0-zp::mac4: the macro parameters
.export __mac_asm
.proc __mac_asm
@params=zp::macros
@err=zp::macros+$0b
@errcode=zp::macros+$0c
@cnt=zp::macros+$0d
@macro=zp::macros+$0e
@numparams=zp::macros+$10
@tmplabel=$140
	asl
	tax
	lda macro_addresses,x
	sta @macro
	lda macro_addresses+1,x
	sta @macro+1

	; read past the macro name
	ldy #$00
	sty @err	; init err to none
:	incw @macro
	lda (@macro),y
	bne :-

	; define the macro params
	incw @macro
	lda (@macro),y
	sta @numparams
	incw @macro

	lda #$00
	sta @cnt
@setparams:
	lda @cnt
	cmp @numparams
	beq @paramsdone
	asl
	tax

	; get the value to set the parameter to
	lda @params,x
	sta zp::label_value
	lda @params+1,x
	sta zp::label_value+1

	; get the name of the parameter to set the value for
	ldx @macro
	ldy @macro+1

	; save the label name for later removal
	txa
	pha
	tya
	pha
	inc @cnt

	; set the parameter to its value
	; (copy the param name to a temp buffer so that it can be
	; seen in the label bank first)
	ldy #$ff		; -1
:	iny
	LOADB_Y @macro
	sta @tmplabel,y
	beq :+
	cmp #$0d
	bne :-

:	tya
	sec		; +1
	adc @macro
	sta @macro
	bcc :+
	inc @macro+1

:	ldxy #@tmplabel
	CALLMAIN lbl::set
	bcs @cleanup
	bcc @setparams		; repeat for all params

@paramsdone:
	; assemble the macro line by line
@asm:	ldxy @macro
	; save state that may be clobbered if we assemble another macro
	txa
	pha
	tya
	pha
	lda @cnt
	pha

	; assemble this line of the macro
	lda #FINAL_BANK_MACROS
	CALLMAIN asm::tokenize

	rol @err		; set error if .C was set
	sta @errcode		; store the error code

	; restore state
	pla
	sta @cnt
	pla
	sta @macro+1
	pla
	sta @macro

@chkerr:
	lda @err		; did an error occur?
	bne @cleanuploop	; if yes, cleanup and exit

@ok:	; move to the next line
	ldy #$00
:	incw @macro
	LOADB_Y @macro
	bne :-

	incw @macro
	LOADB_Y @macro		; at the end of the macro? (two 0's)
	bne @asm		; no, continue

@cleanup:
	lda @cnt
	beq @done

@cleanuploop:
	; restore the label name for the parameter
	pla
	tay
	pla
	tax
	CALLMAIN lbl::del

	dec @cnt
	bne @cleanuploop	; repeat until all params deleted

@done:	lsr @err		; set .C if error occurred
	lda @errcode
	rts
.endproc

;*******************************************************************************
; GET
; Returns the id of the macro corresponding to the given text
; IN:
;  - .XY: pointer to the text
; OUT:
;  - .A: the id of the macro (if any)
;  - .C: set if there is no macro for the given text, clear if there is
.export __mac_get
.proc __mac_get
@tofind=r0
@addr=r2
@name=r4
@cnt=r6
@tmp=r7
	stxy @tofind
	lda #<macro_addresses
	sta @addr
	lda #>macro_addresses
	sta @addr+1
	lda #$00
	sta @cnt
	cmp nummacros
	beq @notfound

@find:	; get the address of the macro (its name)
	ldy #$00
	lda (@addr),y
	sta @name
	iny
	lda (@addr),y
	sta @name+1
	dey

@compare:
	LOADB_Y @name
	sta @tmp

	lda (@tofind),y
	beq :+		; end of the string we're trying to find
	cmp #' '
	beq :+
	cmp #$09
	beq :+
	cmp @tmp
	bne @next
	iny
	bne @compare

:	LOADB_Y @name	; make sure the name length matches
	beq @found

@next:	incw @addr
	incw @addr
	inc @cnt
	ldx @cnt
	cpx nummacros
	bne @find
@notfound:
	sec		; not found
	rts

@found: ldy #$00
	lda @cnt
	RETURN_OK
.endproc

;*******************************************************************************
; STRCMP
; Compares the strings in (str0) and (str2) up to a length of .A
; IN:
;  zp::str0: one of the strings to compare
;  zp::str2: the other string to compare
;  .A:       the max length to compare
; OUT:
;  .Z: set if the strings are equal
.proc strcmp
.ifdef vic20
	tay		; is length 0?
	dey
	bmi @match	; if 0-length comparison, it's a match by default

@l0:	lda (zp::str0),y
	cmp (zp::str2),y
	bne @ret
	dey
	bpl @l0
@match:	lda #$00
@ret:	rts
.else
strcmp = str::compare
.endif
.endproc

endmac:	.byte ".endmac",0
