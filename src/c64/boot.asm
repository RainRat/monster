.include "bsp.inc"
.include "layout.inc"
.include "reu.inc"
.include "../asm.inc"
.include "../config.inc"
.include "../copybuff.inc"
.include "../debug.inc"
.include "../debuginfo.inc"
.include "../draw.inc"
.include "../edit.inc"
.include "../irq.inc"
.include "../labels.inc"
.include "../macros.inc"
.include "../memory.inc"
.include "../monitor.inc"
.include "../runtime.inc"
.include "../settings.inc"
.include "../screen.inc"
.include "../source.inc"
.include "../vmem.inc"
.include "../zeropage.inc"

.import __BSS_LOAD__
.import __BSS_SIZE__

.segment "SETUP"
;*******************************************************************************
; BASIC header: SYS 2061
.word @head
@head: .word @next
.word .version
.byte $9e
.asciiz "2061"
@next: .word 0
start:
	sei

	; save the current machine state
	jsr run::clr

	; disable BASIC
	lda $01
	and #$fe
	sta $01

;--------------------------------------
; zero the BSS segment
	ldxy #__BSS_LOAD__
	stxy r0

	lda #$00
	tay
@zerobss:
	sta (r0),y
	iny
	bne @zerobss
	inc r0+1
	ldx r0+1
	cpx #>(__BSS_LOAD__+__BSS_SIZE__-1)
	bne @zerobss

	lda #$00
	sta r0
	sta zp::banksp

	ldy #<(__BSS_LOAD__+__BSS_SIZE__-1)
	beq @zero_bss_done
@zerobss_last_page:
	sta (r0),y
	dey
	bne @zerobss_last_page
	sta (r0),y		; last byte

@zero_bss_done:
        jsr irq::on

	lda #<start
	sta $0316		; BRK
	lda #>start
	sta $0317		; BRK

	; initialize the status row reverse
	lda #DEFAULT_RVS
	ldx #STATUS_ROW
	jsr draw::hline

	jsr reu::init
	jsr asm::reset
	jsr src::init
	jsr src::new

	; initialize bitmap
	jsr scr::init
	jsr edit::clear

	jsr dbgi::initonce
	jsr asm::reset
	jsr buff::clear		; clear copy buffer

	jsr mon::init

	lda #$80
	sta $028a	; repeat all characters
	sta $0291	; don't swap charset on C= + SHIFT

	jsr dbgi::initonce

	lda #$4c
	sta zp::jmpaddr

	lda #DEFAULT_DEVICE
	sta zp::device

	jmp edit::init
