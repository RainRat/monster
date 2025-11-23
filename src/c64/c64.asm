.include "ram.inc"
.include "reu.inc"
.include "zeropage.inc"
.include "../macros.inc"

SCREEN=$400
SCREEN_W=40

;*******************************************************************************
; DBG
; Copies the contents of REU to $0500
.export __c64_dbg
.proc __c64_dbg
	ldxy #$200
	stxy reu::txlen
	stx reu::reuaddr
	stx reu::reuaddr+1

.import __src_bank
.import labels
	lda __src_bank
	lda #FINAL_BANK_SYMBOLS
	;lda #FINAL_BANK_SOURCE0
	sta reu::reuaddr+2
	;ldxy #(labels)
	ldxy #$0000
	stxy reu::reuaddr

	ldxy #$500
	stxy reu::c64addr
	jmp reu::load
.endproc
