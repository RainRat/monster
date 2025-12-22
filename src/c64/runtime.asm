.include "bsp.inc"
.include "../debug.inc"
.include "../macros.inc"
.include "../ram.inc"
.include "../vmem.inc"

.import __STEPHANDLER_RUN__
.import __STEPHANDLER_LOAD__
.import __STEPHANDLER_SIZE__

.import __STEP_EPILOGUE_RUN__
.import __STEP_EPILOGUE_LOAD__
.import __STEP_EPILOGUE_SIZE__

.export STEP_EXEC_BUFFER
.export STEP_HANDLER_ADDR

STEP_HANDLER_ADDR = __STEPHANDLER_RUN__

;*******************************************************************************
; CLR
.export __run_clr
.proc __run_clr
	; TODO: run cold start (or enough of it to get C64 in intial state)
	jsr bsp::save_prog_state

	ldxy #@restore_dbg_done		; need to pass return address
	jmp dbg::save_debug_zp
@restore_dbg_done:

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
	; copy the STEP handler to the user program and our RAM
;.assert __STEPHANDLER_SIZE__ < $100
	ldy #<__STEPHANDLER_SIZE__-1
@l0:	lda __STEPHANDLER_LOAD__,y
	sta __STEPHANDLER_RUN__,y
	dey
	bpl @l0

	; copy the STEP handler to the user program and our RAM
;.assert __STEPHANDLER_SIZE__ < $100
	ldy #<__STEP_EPILOGUE_SIZE__-1
@l1:	lda __STEP_EPILOGUE_LOAD__,y
	sta __STEP_EPILOGUE_RUN__,y
	dey
	bpl @l1
	rts
.endproc

.segment "STEPHANDLER"

.export STEP_MEMORY_VALUE
.export STEP_EFFECTIVE_ADDR

;******************************************************************************
; STEPHANDLER
; The step handler runs a single instruction and returns to the
; debugger.
; IN:
;   - STEP_EFFECTIVE_ADDR: memory location that will be used (if any)
;   - STEP_MEMORY_VALUE:   value that should be stored at the effective addr
;   - stack:               .A, .P (top to bottom)
;   - .A, .X, .Y:          register values for step to execute
.import step_done
stephandler:
	pla
	sta STEP_RESTORE_A

	; make I/O visible
	lda #$36
	sta $01

	; store user byte
STEP_MEMORY_VALUE=*+1
	lda #$00
STEP_EFFECTIVE_ADDR=*+1
	sta $f00d

	pla			; get status flags

	ora #$04		; set I flag (disable IRQs)
	pha			; push altered status

STEP_RESTORE_A=*+1
	lda #$00
	plp			; restore altered status flags (no IRQs)

STEP_EXEC_BUFFER:
	; run the instruction
	nop
	nop
	nop
	php

	pha
	lda #$34
	sta $01
	lda #$2f
	sta $00
	pla

	jmp step_done		; done -> update simulator with new state
stephandler_size=*-stephandler
