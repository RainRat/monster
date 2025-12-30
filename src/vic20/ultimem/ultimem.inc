.import __ultimem_push_bank
.import __ultimem_pop_bank

.import __ultimem_select_bank

.scope exp
	push_bank   = __ultimem_push_bank
	pop_bank    = __ultimem_pop_bank
	select_bank = __ultimem_select_bank
.endscope

;*******************************************************************************
; SELECT BANK
; Activates the bank in .A
.macro SELECT_BANK
	jsr __ultimem_select_bank
.endproc
