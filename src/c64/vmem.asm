.include "reu.inc"
.include "../errors.inc"
.include "../macros.inc"
.include "../memory.inc"

.BSS

;*******************************************************************************
savexy: .word 0

.CODE

;*******************************************************************************
; LOAD
; Reads a byte from the physical address associated with the given virtual
; address
; IN:
;  - .XY: the virtual address
; OUT:
;  - .A: the byte at the physical address
.export __vmem_load
.proc __vmem_load
	stxy savexy
	stxy reu::reuaddr
	lda #^REU_VMEM_ADDR
	sta reu::reuaddr+2
	jsr reu::load1
	ldxy savexy
	rts
.endproc

;*******************************************************************************
; LOAD OFF
; Reads a byte from the physical address associated with the given virtual
; address
; IN:
;  - .XY: the virtual address
;  - .A: the offset of the virtual address to load
; OUT:
;  - .A: the byte at the physical address
.export __vmem_load_off
.proc __vmem_load_off
@tmp=zp::banktmp
	stxy savexy
	sta @tmp
	txa
	clc
	adc @tmp
	tax
	bcc :+
	iny
:	jsr __vmem_load
	ldxy savexy
	rts
.endproc

;*******************************************************************************
; STORE
; Stores a byte at the physical address associated with the given virtual
; address
; IN:
;  - .XY: the virtual address
;  - .A:  the byte to store
.export __vmem_store
.proc __vmem_store
@tmp=zp::banktmp
	stxy savexy
	stxy reu::reuaddr
	ldx #^REU_VMEM_ADDR
	stx reu::reuaddr+2
	jsr reu::store1
	ldxy savexy		; restore .XY
	rts
.endproc

;*******************************************************************************
; STORE OFF
; Stores a byte at the physical address associated with the given virtual
; address offset by the given offset.
; IN:
;  - .XY:         the virtual address
;  - .A:          the offset from the base address
;  - zp::bankval: the value to store
.export __vmem_store_off
.proc __vmem_store_off
@tmp=zp::banktmp
	stxy savexy
	sta @tmp
	txa
	clc
	adc @tmp
	tax
	bcc :+
	iny
:	lda zp::bankval
	jsr __vmem_store
	ldxy savexy
	rts
.endproc

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
	lda #^REU_VMEM_ADDR
	rts
.endproc

;*******************************************************************************
; WRITABLE
; Checks if the given address is within the valid writable range.
; This includes the addresses [$00, $8000) and [$a000, $c000)
; IN:
;   - .XY: the address to check for writability
; OUT:
;   - .C: set if the address is NOT writable
.export __vmem_writable
.proc __vmem_writable
	; all RAM is writable
	; TODO: check the bank register?
	RETURN_OK
.endproc

;*******************************************************************************
; IS INTERNAL ADDRESS
; Always returns .Z set to indicate that address is "internal"
; On the C64 all user RAM is "internal" (must be swapped for debugging)
; IN:
;  - .XY: the address to test
; OUT:
;  - .Z: set
.export is_internal_address
.proc is_internal_address
	lda #$00
	rts
.endproc
