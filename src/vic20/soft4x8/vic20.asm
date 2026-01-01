.include "../expansion.inc"

.import __text_init
.segment "SETUP"

;*******************************************************************************
; INIT
; Performs Vic-20 specific initialization
.export __vic20_init
.proc __vic20_init
	; set current bank to FASTTEXT
	lda #FINAL_BANK_FASTTEXT
	SELECT_BANK_A
	jsr __text_init

	lda #FINAL_BANK_MAIN
	SELECT_BANK_A
	rts
.endproc
