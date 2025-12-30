.include "expansion.inc"
.include "../inline.inc"
.include "../macros.inc"
.include "../zeropage.inc"

.segment "BANKCODE"

;*******************************************************************************
; CALL
; Performs a JSR to the target address at the given bank. When the routine is
; done, returns to the caller's bank.
; IN:
;  - zp::bank:        the bank of the procedure to call
;  - zp::bankjmpaddr: the procedure address
;  - zp::banktmp:     the destination bank address
.export __ram_call
.proc __ram_call
@a=zp::banktmp+1
@x=zp::banktmp+2
	stx @x
	sta @a

	jsr inline::setup

	lda #$4c
	sta zp::bankjmpaddr	; write the JMP instruction

	jsr exp::push_bank	; save current bank
	jsr inline::getarg_b	; get bank byte
	sta @bank_sel

	jsr inline::getarg_w	; get procedure address
	stx zp::bankjmpvec
	sta zp::bankjmpvec+1

	jsr inline::setup_done

@bank_sel=*+1
	lda #$00		; get the bank to activate
	SELECT_BANK_A		; and activate it

	lda @a			; restore .A
	ldx @x			; restore .X
	jsr zp::bankjmpaddr	; call the target routine
	sta @a			; save .A
	stx @x			; save .X

	jsr exp::pop_bank

	lda @a			; restore .A
	ldx @x			; restore .X
	rts
.endproc
