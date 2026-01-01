;*******************************************************************************
; BOOT.S
; This file is included directly in the main boot.asm file to perform FE3
; specific setup
;*******************************************************************************
	ldx #@end-@unlock
:	lda @unlock-1,x
	sta $200-1,x
	dex
	bne :-

	; run the unlock code
	jmp $200

;-----------------------
@unlock:
	ldx $a000
	stx $a000
	sta $9c02
	cmp $9c02

	; activate ROM bank 0
	lda #$40
	sta $9c02

	; copy SETUP
	ldxy #$2000
	stxy r0
	ldxy #__SETUP_RUN__
	stxy r2

	ldx #>TOTAL_SIZE+1	; # of pages to copy
	ldy #$00

@reloc: ; read from ROM bank and write to RAM bank
	lda (r0),y
	sta (r2),y
	iny
	bne @reloc
	inc r0+1
	inc r2+1
	dex			; next page
	bne @reloc

	jmp __boot_start
@end:
