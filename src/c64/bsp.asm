;*******************************************************************************
; BSP.ASM
; This file contains C64-specific helpers for things like debugging/tracing
;*******************************************************************************

.DATA
.export stop_tracing
stop_tracing: .byte 0

.export PROGRAM_STACK_START
PROGRAM_STACK_START = $1e0

.CODE

;*******************************************************************************
.export __bsp_install_tracer
.proc __bsp_install_tracer

.endproc
