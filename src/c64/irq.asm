.include "../macros.inc"

.segment "IRQ"

;*******************************************************************************
; IRQ OFF
.export __irq_off
.proc __irq_off
	sei
	rts
.endproc

;*******************************************************************************
; IRQ ON
; Syncs to the configured scanline and sets up an IRQ that will trigger whenever
; that location is reached.
.export __irq_on
.proc __irq_on
	sei

	lda #$34		; make all RAM available
	sta $01

	ldxy #sys_update
	stxy $0314		; software vector
	ldxy #hw_irq_handler
	stxy $fffe		; hardware vector

	lda #$34
	sta $01

	cli
	rts
.endproc

;*******************************************************************************
.proc hw_irq_handler
	pha
	txa
	pha
	tya
	pha
	tsx
	lda $104,x
	and #$10		; BRK?
	beq sys_update		; if not -> continue

@brk:	jmp *
.endproc

;*******************************************************************************
; SYS_UPDATE
; This is the main IRQ for this program. It handles updating the beeper.
; It is relocated to a place where it may be called from any bank
.proc sys_update
	lda $01
	pha

	lda #$36	; make KERNAL ($e000-$ffff) available
	sta $01

	jsr $ea87	; scan the keyboard
	lda $dc0d	; ack interrupts

	pla
	sta $01

	pla
	tay
	pla
	tax
	pla
	rti
.endproc
