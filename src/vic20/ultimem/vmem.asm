.include "ultimem.inc"
.include "../vaddrs.inc"
.include "../../macros.inc"
.include "../../memory.inc"

.segment "BANKCODE"

addr=zp::banktmp

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
	jsr translate
	lda (addr),y
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
	pha
	sta zp::bankval
	jsr translate
	pla
	tay
	lda (addr),y
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
	sta zp::bankval
	jsr translate
	sta (addr),y
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
	pha
	sta zp::bankoffset
	jsr translate
	pla
	tay
	sta (addr),y
	rts
.endproc

;*******************************************************************************
; TRANSLATE
; Returns the physical address associated with the given virtual address
; Also sets up the Ultimem so that the address is available for reading/writing
; IN:
;  - .XY: the virtual address
; OUT:
;  - .XY: the physical address
;  - .A:  the bank number of the physical address
.proc translate
@addr=r0
	stx addr

	; get most significant 3 bits to get bank offset
	tya
	lsr
	lsr
	lsr
	lsr
	lsr
	sta $9ff8	; bank in the virutal memory (BLK1)

	; mask lower 13 bits (offset from bank)
	tya
	and #$1f
	sta addr+1
	ldy #$00
	rts
.endproc

.CODE

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
	cmpw #$8000
	bcc @done	; [$00, $8000) -> writable
	cmpw #$c000
	bcs @done	; [$c000, $ffff) -> not writable
	cmpw #$a000
	bcs @writable
	sec		; [$8000, $a000) -> not writable
	rts
@writable:
	clc
@done:	rts
.endproc

;*******************************************************************************
; IS INTERNAL ADDRESS
; Returns with .Z set if the given address is outside of the address ranges
; [$2000,$8000] or [$a000,$ffff]
;
; IN:
;  - .XY: the address to test
; OUT:
;  - .Z: set if the address in [$00,$2000] or [$8000,$a000]
.export is_internal_address
.proc is_internal_address
	cmpw #$2000
	bcc @internal
	cmpw #$8000
	bcc @external
	cmpw #$94f0
	bcc @internal
@external:
	lda #$ff
	rts
@internal:
	lda #$00
	rts
.endproc
