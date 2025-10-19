.ifndef C64_RAM_INC
C64_RAM_INC = 1

.import __ram_copyline

FINAL_BANK_ROM0	   = $00
FINAL_BANK_MAIN    = $00
FINAL_BANK_USER    = $00
FINAL_BANK_DEBUG   = $00
FINAL_BANK_SOURCE0 = $00
FINAL_BANK_SOURCE1 = $00
FINAL_BANK_SOURCE2 = $00
FINAL_BANK_SOURCE3 = $00
FINAL_BANK_SOURCE4 = $00
FINAL_BANK_SOURCE5 = $00
FINAL_BANK_SOURCE6 = $00
FINAL_BANK_SOURCE7 = $00
FINAL_BANK_MACROS  = $00
FINAL_BANK_UDGEDIT = $00
FINAL_BANK_LINKER  = $00
FINAL_BANK_CONSOLE = $00
FINAL_BANK_BUFF    = $00
FINAL_BANK_SYMBOLS = $00
FINAL_BANK_SYMVIEW = $00

.macro CALL bank, proc
	jsr proc
.endmacro

.macro JUMP bank, proc
	jmp proc
.endmacro

;******************************************************************************
; LDA24
; Loads the value from the given 24 bit address and returns it in .A
.macro lda24 bank, addr
	; set REU (load) address
	lda bank
	sta $df06	; MSB of REU address
	lda addr+1
	sta $df05	; middle byte of REU address
	lda addr
	sta $df04	; LSB of REU address

	ldx #$00
	stx $df0a

	; set c64 (target) address (load into banktmp)
	lda #zp::banktmp
	sta $df02
	stx $df03

	; set transfer size to 1 byte
	stx $df08
	inx
	stx $df07

	; execute the REU command
	lda #$91	; load 1 byte from REU -> C64
	sta $df01

	; read the loaded data
	lda zp::banktmp
.endmacro

;******************************************************************************
; STA24
; Stores the value in .A to the given 24 bit address
; CLOBBERS:
;  zp::banktmp
.macro sta24 bank, addr
	sta zp::banktmp

	ldx #$00

	; set REU (load) address
	lda addr
	sta $df04	; LSB of REU address
	lda addr+1
	sta $df05	; middle byte of REU address
	lda bank
	sta $df06	; MSB of REU address

	; set c64 (target) address
	lda #zp::banktmp
	sta $df02
	stx $df03

	; set transfer size to 1 byte
	stx $df08
	inx
	stx $df07

	; execute the REU command
	lda #$90	; store 1 byte from C64 -> REU
	sta $df01
	lda zp::banktmp	; restore byte that we stored
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

;*******************************************************************************
; LOADB Y
; Load a byte from memory with Y offset
; IN:
;  - addr: the address to load from
;  - .Y:   offset to apply to load address
; OUT:
;  - .A: the value that was read
.macro LOADB_Y addr
	lda (addr),y
.endmacro

;*******************************************************************************
; LOADB
; Load a byte from the given address
; IN:
;  - addr: the address to load from
; OUT:
;  - .A: the value that was read
.macro LOADB addr
	ldy #$00
	LOADB_Y addr
.endmacro

;*******************************************************************************
; LOADW Y
; Read a word from the given address + .Y (offset)
; IN:
;   - addr: source address
;   - .Y:    offset
; OUT:
;   - .XY: the value that was read
.macro LOADW_Y addr
	lda (addr),y
	tax
	iny
	lda (addr),y
	tay
.endmacro

;*******************************************************************************
; LOADW
; Read a word from the given address
; IN:
;   - addr: source address
; OUT:
;   - .XY: the value that was read
.macro LOADW addr
	ldy #$00
	LOADW_Y addr
.endmacro

;*******************************************************************************
; STOREB Y
; Store a byte to memory with Y offset
; IN:
;   - .A: byte to write
;   - .Y: offset
;   - addr: address to write to
.macro STOREB_Y addr
	sta (addr),y
.endmacro

;*******************************************************************************
; STOREB
; Stores the value in .A to the target address
; IN:
;   - .A:   value to store
;   - addr: target address
.macro STOREB addr
	ldy #$00
	STOREB_Y addr
.endmacro

;*******************************************************************************
; STOREW_Y
; Write a word to memory at the target address offset by the value in .Y
; IN:
;   - val:  value to write
;   - addr: address to store to
; OUT:
;   - .Y: the input value of .Y + 2
.macro STOREW_Y val, addr
	lda val
	STOREB_Y addr
	iny
	STOREB_Y addr
	iny
.endmacro

;*******************************************************************************
; STOREW
; Write a word to memory
; IN:
;   - .XY:  value to write
;   - addr: address to store to
.macro STOREW addr
	txa
	sta (addr),y
	iny
	tya
	sta (addr),y
	dey
.endmacro

;*******************************************************************************
; SWAPB_Y
; Swaps 2 bytes at the given addresses offset by the value of .Y
; IN:
;   - addr1: one address to swap
;   - addr2: the other address to swap
.macro SWAPB_Y addr1, addr2
	lda (addr1),y
	tax
	lda (addr2),y
	sta (addr1),y
	txa
	sta (addr2),y
.endmacro

;*******************************************************************************
; SWAPW_Y
; Swaps 2 words at the given addresses offset by the value of .Y
; IN:
;   - addr1: one address to swap
;   - addr2: the other address to swap
.macro SWAPW_Y addr1, addr2
	SWAPB_Y
	iny
	SWAPB_Y
.endmacro

;*******************************************************************************
; COPY_Y
; Copy the number of bytes in .Y from src to dst
; IN:
;   - src:  source address
;   - dst:  destination address
;   - .Y:   the number of bytes to copy
.macro COPY_Y src, dst
.local @loop
@loop:	lda (src),y
	sta (dst),y
	dey
	bpl @loop
.endmacro

;*******************************************************************************
; COPYxx
; Copy a chunk of memory (count in Y register, decrementing)
; IN:
;   - src:  source address
;   - dst:  destination address
;   - size: size (0-255)
.macro COPYxx src, dst, size
	ldy #size
	COPY_Y
.endmacro

;*******************************************************************************
; FILL_Y
; Fill memory with a single byte value
; IN:
;   - addr: start address to fill
;   - .A:   byte value
;   - .Y:   number of bytes to fill
.macro FILL_Y addr
.local @loop
@loop:	sta (addr),y
	dey
	bpl @loop
.endmacro
.endif
