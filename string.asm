.include "macros.inc"
.include "zeropage.inc"

;--------------------------------------
; returns the address to the first occurrence of the text in .YX in the string
; in zp::str0
; returns:
;  .A - the index of the first occurrence
;  .C - set if not found
.export __str_find
.proc __str_find
@str=zp::str0
@lookfor=zp::str2
	stxy @str
@l0:
	ldy #$00
	lda (@str),y
	bne @l1
	sec		; not found
	rts
@l1:	lda (@lookfor),y
	beq @done
	cmp (@str),y
	bne :+
	iny
	bne @l1
:	incw @str
	bne @l0
@done:
	tya
	clc
	rts
.endproc

;--------------------------------------
; replace replaces all occurrences of the string in .XY in the string in zp::str0
; with the string in zp::str2
; in zp::str0
; in:
;  - .XY - the address of the string to replace in
;  - zp::srt0 - the string to replace
;  - zp::str2 - the string to replace with
; returns:
;  - .A - the index of the first occurrence
;  - .C - set if not found
; side-effects:
;  the string that the replace was done on is modified in place. It MUST be in
;  a buffer big enough to accomodate this.
.export __str_replace
.proc __str_replace
@str=zp::str0	; string to replace
@replace=zp::str2
@replacewith=zp::str4
@len1=zp::str6	; the length of 'replace'
@len2=zp::str7	; the length of 'replacewith'
@index=zp::str8	; index of string to replace in str
@len=zp::str9
	jsr __str_len
	jsr __str_find
	sta @index
	bcc :+
	rts	; nothing to replace
:	tay

	ldxy @replace
	jsr __str_len	; compare the lengths of the strings
	sta @len1
	ldxy @replacewith
	jsr __str_len
	sta @len2

	; if len2 < len1, we need to shift chars down by len2-len1 chars
	cmp @len1
	bcs :+
	lda @len1
	sec
	sbc @len2
	tax
@shiftback:
	ldy @index
:	lda (@str),y
	dey
	sta (@str),y
	bpl :-
	dex
	bpl @shiftback

	; if len2 > len1, we need to shift chars up
	lda @len2
	sec
	sbc @len1
	tax
@shiftup:
	ldy @index
:	lda (@str),y
	iny
	sta (@str),y
	cpy @len
	bne :-
	inx
	dex
	bpl @shiftup

@doreplace:
	lda @str
	clc
	adc @index
	sta @str
	lda @str+1
	adc #$00
	sta @str+1

	ldy @len2
:	lda (@replacewith),y
	sta (@str),y
	dey
	bpl :-
	rts
.endproc

;--------------------------------------
; len returns the length of the string in .YX in .A
.export __str_len
.proc __str_len
@str=zp::str0
	stx @str
	sty @str+1
	ldy #$00
@l0:	lda (@str),y
	beq @done
	cmp #$0d
	beq @done
	iny
	bne @l0
@done:	tya
	rts
.endproc

;--------------------------------------
; compare compares the strings in (str0) and (str2) up to a length of .A
; If the strings are equal, 0 is returned in .A. and the zero flag is set.
.export __str_compare
.proc __str_compare
	tay
	dey
	bmi @match
@l0:	lda (zp::str0),y
	cmp (zp::str2),y
	beq :+
	rts
:	dey
	bpl @l0
@match:	lda #$00
	rts
.endproc
