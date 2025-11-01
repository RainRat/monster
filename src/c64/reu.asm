;*******************************************************************************
; REU.ASM
; This file contains C64-specific REU routines
;*******************************************************************************

.export __reu_c64_addr
.export __reu_reu_addr
.export __reu_txlen

__reu_c64_addr = $df02
__reu_reu_addr = $df04
__reu_txlen    = $df07

.include "../errors.inc"
.include "../inline.inc"
.include "../macros.inc"
.include "../memory.inc"
.include "../zeropage.inc"

.exportzp __reu_move_src
.exportzp __reu_move_dst
.exportzp __reu_move_size

REU_TMP_ADDR            = $ff0000
REU_VMEM_ADDR           = $fe0000
REU_SYMTABLE_ADDRS_ADDR = $fd0000	; label addresses
REU_SYMTABLE_NAMES_ADDR = $fc0000	; label names
REU_SYMTABLE_ANONS_ADDR = $fb0000	; anonymous label addresses

savex = zp::inline
savey = zp::inline+1

;*******************************************************************************
savea = zp::bankaddr0
savep = zp::bankaddr0+1
tmp   = zp::bankaddr0+2

.BSS
;*******************************************************************************
; TABLE STATE
; These parameters contain the properties of the table usedb by the
; tab* procedures
tab_addr:         .res 3
tab_element_size: .byte 0
tab_num_elements: .word 0

.CODE

;*******************************************************************************
; INIT
.export __reu_init
.proc __reu_init
	lda #$00
	sta $df0a	; count UP
	rts
.endproc

;*******************************************************************************
; STORE1
; Stores one byte to the given source 24-bit address
; IN:
;   - .A:            the value to store
;   - reu::reu_addr: the address to store to (24 bit)
.export __reu_store1
.proc __reu_store1
@tmp=tmp
	sta @tmp

	lda #@tmp
	sta __reu_c64_addr

	lda #$01
	sta __reu_txlen

	lda #$00
	sta __reu_c64_addr
	sta __reu_txlen+1
	sta $df0a

	lda #$90	; transfer from c64 -> REU with immediate execution
	sta $df01	; execute
	lda @tmp	; restore .A
	rts
.endproc
;*******************************************************************************
; STORE
; Moves the data from the given source 24-bit address to the given
; destination one.
; IN:
;   - reu::c64_addr: the source address (24 bit)
;   - reu::reu_addr: the destination address (24 bit)
;   - reu::len:      the number of bytes to copy (16-bit)
.export __reu_store
.proc __reu_store
	lda #$00
	sta $df0a
	lda #$90	; transfer from c64 -> REU with immediate execution
	sta $df01	; execute
	rts
.endproc

;*******************************************************************************
; LOAD1
; Loads one byte from the given source 24-bit address
; IN:
;   - reu::reu_addr: the address to load from (24 bit)
; OUT:
;   - .A: the byte that was read
.export __reu_load1
.proc __reu_load1
@tmp=tmp
	lda #@tmp
	sta __reu_c64_addr

	lda #$01
	sta __reu_txlen

	lda #$00
	sta __reu_c64_addr
	sta __reu_txlen+1
	sta $df0a

	lda #$91	; transfer from REU -> c64 with immediate execution
	sta $df01	; execute
	lda @tmp	; read the byte we loaded
	rts
.endproc

;*******************************************************************************
; LOAD
; Loads the C64 with data from the given source 24-bit address to the given
; C64 address
; IN:
;   - reu::c64_addr: the source address (24 bit)
;   - reu::reu_addr: the destination address (24 bit)
;   - reu::len:      the number of bytes to copy (16-bit)
.export __reu_load
.proc __reu_load
	lda #$00
	sta $df0a
	lda #$91	; transfer from REU -> c64 with immediate execution
	sta $df01	; execute
	rts
.endproc

;*******************************************************************************
; COMPARE
; Compares the data at reuaddr and c64addr for up to reu::txlen bytes.
; OUT:
;   .Z: set if there are no differences
.export __reu_compare
.proc __reu_compare
	lda $df00	; read status to clear fault bit
	lda #$93|$20	; compare C64 <-> REU
	sta $df01	; execute
	lda $df00
	and #$20	; check fault bit (set if differences found)
	rts
.endproc

;*******************************************************************************
; SWAP
; Swaps the data from the REU at the address in reu::reuaddr with the data
; in the C64 at reu::c64addr.
.export __reu_swap
.proc __reu_swap
	lda #$92	; swap c64 <-> REU with immediate execution
	sta $df01	; execute
	rts
.endproc

;*******************************************************************************
; ZERO
; Zeroes out the number of bytes in txlen at reu::move_dst
.export __reu_zero
.proc __reu_zero
	ldxy #@zero
	stxy __reu_c64_addr
	lda #$80
	sta $df0a		; fix c64 address

	lda #$90
	sta $df01		; transfer c64 -> REU

@zero=*+1			; zero byte
	lda #$00
	sta $df0a		; unfix c64 address
.endproc

;*******************************************************************************
; MOVE
; Moves the given addresses from one part of the REU to another
; This routine first copies the data to the C64 and then stores
; it back to the REU at the destination address
; IN:
;   - reu::move_src: the address of the data to move
;   - reu::move_dst: the destination address in the REU
;   - reu::move_size: # of byte to relocate
__reu_move_src=zp::bank
__reu_move_dst=zp::bank+3
__reu_move_size=zp::bank+6
.export __reu_move
.proc __reu_move
@src=__reu_move_src
@dst=__reu_move_dst
@size=__reu_move_size
@move:	lda @size+2
	beq :+
	jmp *		; oversized move

:	lda @size
	sta __reu_txlen
	lda @size+1
	sta __reu_txlen+1

	; backup the C64 memory we will clobber
	ldxy #@end
	stxy __reu_c64_addr
	stxy __reu_reu_addr
	lda #^REU_TMP_ADDR
	sta __reu_reu_addr+2
	jsr __reu_swap

	lda @size
	sta __reu_txlen
	lda @size+1
	sta __reu_txlen+1
	ldxy #@end
	stxy __reu_c64_addr
	stxy __reu_reu_addr

	; bring in the source data to relocate
	lda @src
	sta __reu_reu_addr
	lda @src+1
	sta __reu_reu_addr+1
	lda @src+2
	sta __reu_reu_addr+2
	jsr __reu_load

	lda @size
	sta __reu_txlen
	lda @size+1
	sta __reu_txlen+1
	ldxy #@end
	stxy __reu_c64_addr

	; and store it to its relocation address
	lda @dst
	sta __reu_reu_addr
	lda @dst+1
	sta __reu_reu_addr+1
	lda @dst+2
	sta __reu_reu_addr+2
	jsr __reu_store

	lda @size
	sta __reu_txlen
	lda @size+1
	sta __reu_txlen+1


	; finally, restore the C64's memory that we used as an intermediate
	; buffer
	ldxy #@end
	stxy __reu_c64_addr
	stxy __reu_reu_addr
	lda #^REU_TMP_ADDR
	sta __reu_reu_addr+2
	jmp __reu_swap
@end=*
.endproc

;*******************************************************************************
; FIND
; Seeks, page by page, for the given string beginning at the given
; address. If no match is found at the 64k page of the given address,
; returns with the .C flag set.
; IN:
;  - .XY:           the string to look for
;  - .A:            the length of the string
;  - reu::reu_addr: the address to start seeking at
; OUT:
;  - .C: set if the string is not found
;  - .A:  the 64k block of the return address (same as one given)
;  - .XY: the address of the string (if found)
.export __reu_find
.proc __reu_find
@str=zp::bankoffset
@len=zp::bankoffset+2
@tmp=zp::bankoffset+3
@pagebuff=@end
	stxy @str
	sta @len

	ldxy #$100
	stxy __reu_txlen
	ldxy #@pagebuff
	stxy __reu_c64_addr
	stxy __reu_c64_addr

	; read one page for compare
	jsr __reu_load

	; search the page for the string
	ldy #$00
	ldx #$00
@l0:	lda (@str),y
	cmp @pagebuff,y
	beq @next

	; .Y -= .X (backtrack the # of chars we matched)
	stx @tmp
	tya
	sec
	sbc @tmp
	tay
	ldx #$ff		; reset char match count

@next:	inx
	cpx @len
	beq @found
	iny
	bne @l0
	inc __reu_reu_addr+1	; next page
	bne @l0			; repeat until end of 64k block
	sec			; flag not found
	rts

@found:	tya
	clc
	adc __reu_reu_addr
	tax
	lda __reu_reu_addr+1
	adc #$00
	tay
	lda __reu_reu_addr+2
	RETURN_OK
@end:
.endproc

;*******************************************************************************
; STORE BYTE
; stores the byte given in zp::bankval to address .YX in bank .A
; Because the return address is adjusted, should only be called (JSR)
; e.g.
;	jsr reu::storeb
;	.word addr
; IN:
;  - .A:          the bank to store to
;  - *+3:         the address to store to
;  - zp::bankval: the byte to write
; CLOBBERS:
;  - .A
.export	__reu_storeb
.proc __reu_storeb
@dst=zp::banktmp
	pha

	jsr inline::setup
	jsr inline::getarg_w
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	pla
	jsr __reu_store1

	ldx savex
	ldy savey
	rts
.endproc

;*******************************************************************************
; STOREB OFF
; IN:
;   - *+3: 1 byte - the zeropage address to write to
;   - .A:  the value to write
; OUT:
;   - .P: unaffected
; CLOBBERS:
;   - NONE
.export	__reu_storeb_off
.proc __reu_storeb_off
	sta savea

	; save flags register
	php
	pla
	sta savep

	jsr inline::setup

	; read the address to load from
	jsr inline::getarg_zp_ind_off
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	lda savea
	jsr __reu_store1

	ldx savex
	ldy savey

	; restore flags register
	lda savep
	pha
	lda savea
	plp

	rts
.endproc

;*******************************************************************************
; STOREW
; IN:
;  - *+3: address to write to
;  - .XY: the value to write
; CLOBBERS:
;  - .A, .X, .Y, .P
.export	__reu_storew
.proc __reu_storew
@dst=tmp
	stxy @dst

	jsr inline::setup

	; read the address to store to
	jsr inline::getarg_w
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	; 2 bytes
	ldxy #$02
	stxy __reu_txlen

	ldxy #@dst
	stxy __reu_c64_addr

	jsr __reu_store

	ldx savex
	ldy savey
	rts
.endproc

;*******************************************************************************
; LOADB
; IN:
;  - *+3: address to read
; OUT:
;  - .A: the byte that was read
;  - .N: set if loaded byte is negative
;  - .Z: set if loaded byte is 0
.export	__reu_loadb
.proc __reu_loadb
	; save .C flag
	php
	pla
	and #$01		; mask .C bit
	sta savep
	jsr inline::setup

	; read the address to load from
	jsr inline::getarg_zp_ind
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	jsr __reu_load1
	sta savea

	ldx savex
	ldy savey

	; set flags
	cmp #$00
	php
	pla
	and #$fe
	ora savep	; restore .C bit
	pha

	lda savea

	; restore flags register
	plp
	rts
.endproc

;*******************************************************************************
; LOADB OFF
; IN:
;  - *+3: 1 byte - base address to read
;  - .Y:  offset from base address
; OUT:
;  - .A: the byte that was read
;  - .N: set if loaded byte is negative
;  - .Z: set if loaded byte is 0
.export	__reu_loadb_off
.proc	__reu_loadb_off
	; save .C flag
	php
	pla
	and #$01		; mask .C bit
	sta savep

	jsr inline::setup
	jsr inline::getarg_zp_ind_off
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	jsr __reu_load1
	sta savea

	ldx savex
	ldy savey

	; set flags
	cmp #$00	; set .N and .Z
	php
	pla
	and #$fe	; mask .C bit
	ora savep	; restore .C bit
	pha		; save .N, .Z, and .C
	lda savea
	plp
	rts
.endproc

;*******************************************************************************
; LOADW
; IN:
;  - *+3: address to read
; OUT:
;  - .XY: the value that was read
; CLOBBERS:
;  - .A, .X, .Y, .P
.export	__reu_loadw
.proc	__reu_loadw
@dst=tmp
	jsr inline::setup
	jsr inline::getarg_w
	stx __reu_reu_addr
	sta __reu_reu_addr+1
	jsr inline::setup_done

	; 2 bytes
	ldxy #$02
	stxy __reu_txlen

	ldxy #@dst
	stxy __reu_c64_addr

	; load the word
	jsr __reu_load
	ldxy @dst
	rts
.endproc

;*******************************************************************************
; COPY Y
; Copies .Y bytes from the source to destination
; IN:
;  - *+3: source address
;  - *+5: destination address
;  - .Y:  the offset in bytes
; CLOBBERS:
;  - .A, .P
.export __reu_copy_y
.proc __reu_copy_y
	jsr inline::setup

	sty __reu_move_size
	lda #$00
	sta __reu_move_size+1

	; get source and destination addresses
	jsr inline::getarg_w
	stx __reu_move_src
	sta __reu_move_src+1
	jsr inline::getarg_w
	stx __reu_move_dst
	sta __reu_move_dst+1
	jsr inline::setup_done

	jsr __reu_move		; move from source -> dest

	ldx savex
	ldy savey
	rts
.endproc
