.ifndef RAM_INC
.include "zeropage.inc"

.ifdef vic20
.import __final_call
.import __final_store_byte
.import __final_load_byte
.import __final_load_byte_off
.import __final_memcpy
.import __final_copy
.import __final_copy_line
.import __final_bank_store_rel
.endif

.scope ram
	call     = __final_call
	fcopy    = __final_copy
	copy     = __final_memcpy
	copyline = __final_copy_line
	store    = __final_store_byte
	store_off= __final_bank_store_rel
	load     = __final_load_byte
	load_off = __final_load_byte_off
.endscope

;******************************************************************************
; LDA24
; Loads the given 24 bit address into .A
.macro lda24 bank, addr, offset
.ifdef vic20
.ifnblank offset
	lda offset
	sta zp::bankval
.endif
	ldxy addr
	lda bank
.ifblank offset
	jsr __final_load_byte
.else
	lda bank
	jsr __final_load_byte_off
.endif
.endif
.endmacro

;******************************************************************************
; STA24
; Stores the value in .A to the given 24 bit address
.macro sta24 bank, addr
.ifdef vic20
	sta zp::bankval
	ldxy addr
	lda bank
	jsr __final_store_byte
.endif
.endmacro

;******************************************************************************
; MOV
; Moves the value from the given 24-bit source to the given 24-bit destination
.macro mov dst24, src24
	.if (.match (.left (1, {src24}), #))
		; immediate mode, just load .A with the immediate value
		lda src24
	.else
		lda24 src
	.endif
	sta24 dst24
.endmacro
.endif
