.include "reu.inc"
.include "../config.inc"
.include "../inline.inc"
.include "../macros.inc"
.include "../zeropage.inc"

;*******************************************************************************
.CODE

;*******************************************************************************
; GET BYTE
; Returns the value of the byte at the given address
; IN:
;   - .XY: the address to get the value of
; OUT:
;   - .A: the value for the given address in the MAIN bank
; CLOBBERS:
;   - .A, .Y, r0-r1
.export __ram_get_byte
.proc __ram_get_byte
@addr=zp::banktmp
	stxy @addr
	ldy #$00
	lda (@addr),y
	rts
.endproc

;*******************************************************************************
; CALL
; Performs a JSR to the target address.
; For the C64, the "bank" represents where the data for the target procedure
; lives (not the code itself).
; IN:
;  - zp::bank:        the bank of the procedure to call
;  - zp::bankjmpaddr: the procedure address
;  - zp::banktmp:     the destination bank address
.export	__ram_call
.proc __ram_call
@a=zp::banktmp+1
@x=zp::banktmp+2
@bank=zp::banktmp
	stx @x
	sta @a

	jsr inline::setup

	lda #$4c
	sta zp::bankjmpaddr	; write the JMP instruction

	; "push" the current bank
	lda reu::reuaddr+2
	ldx zp::banksp
	inc zp::banksp
	sta zp::bankstack,x

	jsr inline::getarg_b	; get bank byte
	sta reu::reuaddr+2	; set REU MSB to the target bank
	jsr inline::getarg_w	; get procedure address
	stx zp::bankjmpvec
	sta zp::bankjmpvec+1

	jsr inline::setup_done

	lda @a			; restore .A
	ldx @x			; restore .X
	jsr zp::bankjmpaddr	; call the target routine
	sta @a			; save .A
	stx @x			; save .X

	dec zp::banksp
	ldx zp::banksp
	lda zp::bankstack,x	; get the caller's bank
	sta reu::reuaddr+2	; restore bank

	lda @a			; restore .A
	ldx @x			; restore .X
	rts
.endproc

;*******************************************************************************
.export	__ram_copy
.proc __ram_copy
	; TODO:
	rts
.endproc

;*******************************************************************************
; COPY LINE
; Copies up to LINESIZE bytes from zp::bankaddr0 to zp::bankaddr1 stopping at
; the first $0d or $00
; IN:
;  - .A:            the bank to perform the copy within
;  - zp::bankaddr0: the source address to copy from
;  - zp::bankaddr1: the destination address to copy to
; OUT:
;  - .Y: the number of bytes copied
;  - .A: the last byte copied
.export	__ram_copy_line
.proc __ram_copy_line
	ldy #$00
	sta reu::reuaddr+2
:	jsr reu::loadb_off
	.byte zp::bankaddr0
	jsr reu::storeb_off
	.byte zp::bankaddr1
	beq @done
	cmp #$0d
	beq @done
	iny
	cpy #LINESIZE
	bcc :-
@done:	rts
.endproc

;*******************************************************************************
; STORE_BYTE
; stores the byte given in zp::bankval to address .YX in bank .A
; Because the return address is adjusted, should only be called (JSR)
; e.g.
;	jsr ram::store_byte
;	.word addr
; IN:
;  - .A:          the bank to store to
;  - *+3:         the address to store to
;  - zp::bankval: the byte to write
; CLOBBERS:
;  - .A
.export	__ram_store_byte
.proc __ram_store_byte
@dst=zp::banktmp
	sta @val
	pla
	clc
	adc #$02	; update return address past argument(s)
	sta @ret
	pla
	adc #$00
	sta @ret+1

	ldy #$00
@val=*+1
	lda #$00
	sta (@dst),y
	ldy @dst+1

@ret=*+1
	jmp $f00d	; return
.endproc

;*******************************************************************************
; STORE_BYTE_REL
; stores the byte given in zp::bankval to the address in .XA in bank .A
; IN:
;  - .XY:            the base address
;  - .A:             the bank to store to
;  - zp::bankoffset: the offset from the base address
;  - zp::bankval:    the byte to write
.export	__ram_bank_store_rel
.proc __ram_bank_store_rel
	; TODO:
	rts
.endproc

;*******************************************************************************
; LOAD BYTE OFF
; Returns the byte in bank .A at address .YX plus a given offset
; IN:
;  - .XY: the address to read from
;  - .A: the bank to read from
;  - zp::bankval: the offset to read from
; OUT:
;  - .A: the byte that was read
;  - .Y: contains the offset (same that was given as zp::bankval)
.export	__ram_load_byte_off
.proc __ram_load_byte_off
	; TODO:
	; add the offset
	jsr reu::load1
	rts
.endproc

;*******************************************************************************
; COPY BANKED
; Entrypoint to store from the C64 to the destination bank
; IN:
;  - .XY: the number of bytes to copy
;  - r2:  the source address
;  - r4:  the destination address
;  - r7:  the destination bank
.export __ram_copy_banked
__ram_copy_banked:
	stxy reu::txlen
	lda r7
	sta reu::reuaddr+2
	ldxy r4
	stxy reu::reuaddr
	ldxy r2
	stxy reu::c64addr
	jmp reu::store

;*******************************************************************************
; MEMCPY
; Writes the memory from (tmp0) to (tmp2)
; The number of bytes is given in .YX and the block # to write to is given in .A
; This routine assumes that IF the memory overlaps, that it will do so from
; the TOP. (dst > src)
; IN:
;  - .A:  the source/destination bank
;  - .XY: the number of bytes to copy
;  - r2:  the source address
;  - r4:  the destination address
.export __ram_memcpy
.proc __ram_memcpy
@size=r0
@src=r2
@dst=r4
@bank=r6
@bankdst=r7
	sta reu::move_src+2
	sta reu::move_dst+2
	stxy reu::txlen
	ldxy @src
	stxy reu::move_src
	ldxy @dst
	stxy reu::move_dst
	jmp reu::move
.endproc
