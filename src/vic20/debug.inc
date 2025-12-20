.import install_trace_nmi

.scope bsp
	install_tracer = install_trace_nmi
.endscope

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

;*******************************************************************************
; SAVE IO
; This macro saves Vic-20 specific I/O (VIAs etc.) upon returning to the
; debugger from a "GO" command
.macro SAVE_IO
	lda $912e
	sta sim::via2+$e
.endmacro
