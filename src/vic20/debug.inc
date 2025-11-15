;*******************************************************************************
; TRACE ON
; This macro enables the NMI (or other method) required to interrupt a "trace"
.macro TRACE_ON
	; enable NMIs
	; this lets us catch the user's signal that they wish to interrupt
	; a "trace"
	lda #$82
	sta $911e
.endmacro

;*******************************************************************************
; TRACE OFF
; This macro disables the NMI (or other method) responsible for performing a
; "trace".
.macro TRACE_OFF
	; disable NMIs
	; this prevents an interrupt from occurring while we are running
	; a simualted "step" in the debugger
	lda #$7f
	sta $911e
.endmacro
