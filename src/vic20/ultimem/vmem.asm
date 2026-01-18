.include "ultimem.inc"
.include "../vaddrs.inc"
.include "../../macros.inc"
.include "../../memory.inc"

.segment "BANKCODE"

addr=zp::banktmp
savey=zp::banktmp+2

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
	jmp vmem_done
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
	sta zp::bankoffset
	jsr translate
	ldy zp::bankoffset
	lda (addr),y
	jmp vmem_done
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
	pha
	jsr translate
	pla
	sta (addr),y
	jmp vmem_done
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
	sta zp::bankoffset
	jsr translate
	ldy zp::bankoffset
	lda zp::bankval
	sta (addr),y

	; fall through to vmem_done
.endproc

;*******************************************************************************
; VMEM DONE
; Restores BLK1 to the MAIN bank, restores .Y, and returns
.proc vmem_done
	; restore BLK1
	pha
	lda #$01
	sta $9ff8
	lda #$55
	sta $9ff2
	pla

	ldy savey
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
	cpy #$c0		; in ROM?
	bcc @ram

@rom:	; ROM doesn't need to be translated and will be read
	; directly
	stxy addr
	ldy #$00
	lda #SIMRAM_00_BANK	; any bank (doesn't really matter)
	rts

@ram:	sty savey
	stx addr		; store address LSB as is

	; get most significant 3 bits to get the bank to use
	tya
	lsr
	lsr
	lsr
	lsr
	lsr
	clc
	adc #SIMRAM_00_BANK
	sta $9ff8		; bank in the virutal memory (BLK1)

	tya
	and #$1f		; get lower 5 bits of MSB (offset from bank)
	;clc
	adc #$20		; add BLK1 base ($2000)
	sta addr+1
	lda #$57
	sta $9ff2		; make BLK1 RAM (r/w)
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
