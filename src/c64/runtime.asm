.include "bsp.inc"
.include "debug.inc"
.include "reu.inc"
.include "vaddrs.inc"
.include "../asmflags.inc"
.include "../debug.inc"
.include "../macros.inc"
.include "../ram.inc"
.include "../sim6502.inc"
.include "../vmem.inc"

.import __STEPHANDLER_RUN__
.import __STEPHANDLER_LOAD__
.import __STEPHANDLER_SIZE__

.import __TRAMPOLINE_RUN__
.import __TRAMPOLINE_LOAD__
.import __TRAMPOLINE_SIZE__

.import __NMI_HANDLER_RUN__
.import __NMI_HANDLER_LOAD__
.import __NMI_HANDLER_SIZE__

.import __STEP_EPILOGUE_RUN__
.import __STEP_EPILOGUE_LOAD__
.import __STEP_EPILOGUE_SIZE__

.export STEP_EXEC_BUFFER
.export STEP_HANDLER_ADDR

STEP_HANDLER_ADDR = __STEPHANDLER_RUN__

.CODE
;*******************************************************************************
nop_handler:
	rti

;*******************************************************************************
; CLR
.export __run_clr
.proc __run_clr
	ldxy #@save_done	; need to pass return address
	jmp dbg::save_user_zp
@save_done:

	; TODO: run cold start (or enough of it to get C64 in intial state)
	jsr bsp::save_prog_state

	ldxy #nop_handler
	stxy $0318
	stxy $fffa

	ldxy #@restore_dbg_done		; need to pass return address
	jmp dbg::save_debug_zp
@restore_dbg_done:
	rts
.endproc

;*******************************************************************************
; INIT
.export __run_init
.proc __run_init
	jsr install_nmi
	jsr install_step
	jsr install_trampoline
	rts
.endproc

;*******************************************************************************
; GO
.export __run_go
.proc __run_go
	TRACE_ON

	lda #$34	; make all RAM available
	sta $01

	lda prog00+1
	sta TRAMPOLINE_PROG01

	ldxy sim::pc
	stxy TRAMPOLINE_PC

	; swap in the memory above $e000
	ldxy #$e000
	stxy reu::c64addr
	stxy reu::reuaddr
	lda #^REU_VMEM_ADDR
	sta reu::reuaddr+2
	ldxy #$2000-$08
	stxy reu::txlen
	jsr reu::load_delayed

	; save the debugger's ZP and bring in the user's one
	ldxy #@save_dbg_done		; need to pass return address
	jmp dbg::save_debug_zp
@save_dbg_done:
	ldxy #@restore_done		; need to pass return address
	jmp dbg::restore_user_zp
@restore_done:

	jsr bsp::save_debug_state
	jsr bsp::restore_prog_visual

	lda #$34
	sta $01

	; install the SW/HW NMI handler
	lda #<nmi_handler
	sta $fffa
	sta $0318
	lda #>nmi_handler
	sta $fffb
	sta $0319

	; bounce to the user's program
	ldx sim::reg_sp
	txs
	ldx sim::reg_x
	ldy sim::reg_y
	lda sim::reg_p
	pha
	lda sim::reg_a
	sta TRAMPOLINE_A

	lda #$36			; expose REU registers
	sta $01

	; prepare REU registers to load from $800 up to the NMI handler addr
	lda #$00
	sta $df02
	sta $df04
	lda #$08
	sta $df02+1
	sta $df04+1
	lda #^REU_VMEM_ADDR
	sta $df04+2

	lda #<(__NMI_HANDLER_RUN__-$800)
	sta $df07
	lda #>(__NMI_HANDLER_RUN__-$800)
	sta $df07+1

	lda #$91			; command to load from REU
	sei
	jmp trampoline
.endproc

;*******************************************************************************
; GO BASIC
.export __run_go_basic
.proc __run_go_basic
	rts
.endproc

;******************************************************************************
; INSTALL TRAMPOLINE
; Installs the "trampoline" code at the top of the user and debug RAM
; This code lets us switch to the user bank and begin executing code there
.proc install_trampoline
	; copy the TRAMPOLINE handler to the user program and our RAM
	ldy #<trampoline_size-1
@l0:	lda __TRAMPOLINE_LOAD__,y
	sta __TRAMPOLINE_RUN__,y
	dey
	bpl @l0
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
	;.assert stephandler_size < $100
	ldy #<stephandler_size-1
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

;******************************************************************************
; INSTALL NMI
; Installs the NMI handler
.proc install_nmi
	ldy #<nmi_handler_size-1
@l0:	lda __NMI_HANDLER_LOAD__,y
	sta __NMI_HANDLER_RUN__,y
	dey
	bpl @l0
.endproc

.segment "NMI_HANDLER"
;******************************************************************************
; NMI HANDLER
; Handles an NMI (RESTORE key) or BRK to return to the debugger
nmi_handler:
	pha		; NMI handler
	txa
	pha
	tya
	pha

	lda #$36
	sta $01

	; save the current state of the program
	; ($0800-$ceff)
	lda #$00
	sta $df02
	sta $df04
	lda #$08
	sta $df02+1
	sta $df04+1
	lda #^REU_VMEM_ADDR
	sta $df04+2

	lda #<(__NMI_HANDLER_RUN__-$800)
	sta $df07
	lda #>(__NMI_HANDLER_RUN__-$800)
	sta $df07+1
	lda #$90|$20	; load + autoload
	sta $df01	; C64 -> REU + autoload

	; load program back
	lda #^REU_BACKUP_ADDR
	sta $df04+2
	lda #$91
	sta $df01	; REU -> C64

	lda #$34
	sta $01
	jmp dbg::reenter
nmi_handler_size=*-nmi_handler

.segment "TRAMPOLINE"
;******************************************************************************
; TRAMPOLINE
; Swaps memory and then jumps to the simulated PC
trampoline:
	sta $df01	; load program state from REU

TRAMPOLINE_PROG01=*+1
	lda #$00
	sta $01		; set bank register to user's value

	lda #<nmi_handler
	sta $0318
	lda #>nmi_handler
	sta $0319

	; restore .A
TRAMPOLINE_A=*+1
	lda #$00

	plp
TRAMPOLINE_PC=*+1
	jmp $f00d	; jump to the user's program
trampoline_size=*-trampoline

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
	lda #$34
	sta $01

	; store user byte if it's used
	lda sim::affected
	and #OP_LOAD|OP_STORE
	beq :+

STEP_MEMORY_VALUE=*+1
	lda #$00
STEP_EFFECTIVE_ADDR=*+1
	sta $f00d

:	pla			; get status flags
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
	lda #$2f
	sta $00
	pla

	jmp step_done		; done -> update simulator with new state
stephandler_size=*-stephandler
