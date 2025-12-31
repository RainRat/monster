.include "ultimem.inc"
.include "../ram.inc"
.include "../vaddrs.inc"
.include "../../macros.inc"
.include "../../memory.inc"

.CODE

;*******************************************************************************
; TRANSLATE
; Returns the physical address associated with the given virtual address
; IN:
;  - .XY: the virtual address
; OUT:
;  - .XY: the physical address
;  - .A:  the bank number of the physical address
.export __vmem_translate
.proc __vmem_translate
	cpy #>$0400
	bcs :+

@00:	; $00-$400 is stored in the prog00 buffer
	add16 #(prog00-$00)
	lda #FINAL_BANK_MAIN
	rts

:	; TODO: this needs to be virtualized ($400-$1000)
	cpy #>$1000
	bcc @done

	cpy #>$2000
	bcs :+

@1000:	; $1000-$2000 is stored in the prog1000 buffer
	add16 #(prog1000-$1000)
	lda #FINAL_BANK_FASTCOPY
	rts

:	cpy #>$9000
	bne :+
	cpx #<$9010
	bcs @done		; $9010-$9100 is not buffered anywhere

@9000:	; $9000-$9010 is stored in the prog9000 buffer
	add16 #(prog9000-$9000)
	lda #FINAL_BANK_FASTCOPY
	rts

:	cpy #>$9400
	bne @done

@9400:	; $9400-$94f0 is stored in the prog9400 buffer
	cpx #$f0
	bcs @done			; if addr > $94ef, not virtual
	add16 #(prog9400-$9400)
	lda #FINAL_BANK_FASTCOPY
	rts

@done:	; everything else is stored at its unaltered address in the
	; USER bank
	lda #FINAL_BANK_USER
	rts
.endproc
