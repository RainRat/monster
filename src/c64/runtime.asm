.include "../macros.inc"
.include "../ram.inc"
.include "../vmem.inc"

.export STEP_EXEC_BUFFER
.export STEP_HANDLER_ADDR

STEP_HANDLER_ADDR = $c000-stephandler_size

;*******************************************************************************
; CLR
.export __run_clr
.proc __run_clr
	rts
.endproc

;*******************************************************************************
; INIT
.export __run_init
.proc __run_init
	jsr install_step	; install the STEP handler
	rts
.endproc

;*******************************************************************************
; GO
.export __run_go
.proc __run_go
	rts
.endproc

;*******************************************************************************
; GO BASIC
.export __run_go_basic
.proc __run_go_basic
	rts
.endproc

;******************************************************************************
; INSTALL STEP
; Installs the STEP code at the top of the user and debug RAM
; This code includes a buffer that switches to the user RAM, executes an
; instruction there, switches back to the debugger RAM, and jumps back to the
; debugger's "return from step" function to capture any changes that took place.
.proc install_step
@cnt=r0
@dst=r2
	ldxy #STEP_HANDLER_ADDR
	stxy @dst
	lda #stephandler_size-1
	sta @cnt
; copy the STEP handler to the user program and our RAM
@l0:	ldy @cnt
	lda stephandler,y
	sta STEP_HANDLER_ADDR,y
	sta zp::bankval
	sty zp::bankoffset
	ldxy @dst
	lda #FINAL_BANK_USER
	jsr ram::store_off
	dec @cnt
	bpl @l0

	rts
.endproc

.segment "STEPHANDLER"

;******************************************************************************
; STEPHANDLER
; The step handler runs a single instruction and returns to the
; debugger.
; IN:
;   - stack:      .A, .P (top to bottom)
;   - .A, .X, .Y: register values for step to execute
.import step_done
stephandler:
	; switch to USER bank
	pla			; restore .A
	sta STEP_RESTORE_A

	pla			; get status flags
	ora #$04		; set I flag
	pha			; push altered status

STEP_RESTORE_A = STEP_EXEC_BUFFER-2
	lda #$00		; SMC - restore A
	plp			; restore altered status flags

	; run the instruction
STEP_EXEC_BUFFER = STEP_HANDLER_ADDR + (*-stephandler)
step_buffer:
	nop
	nop
	nop

	php
	pha
	sei			; disable IRQs

	pla
	jmp step_done		; done -> update simulator with new state
stephandler_size=*-stephandler
