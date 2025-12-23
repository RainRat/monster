.import install_trace_nmi
.import __fastcopy_restore_debug_state
.import __fastcopy_restore_prog_visual
.import __fastcopy_restore_prog_state
.import __fastcopy_save_debug_state
.import __fastcopy_save_prog_state

.scope bsp
	install_tracer      = install_trace_nmi
	restore_debug_state = __fastcopy_restore_debug_state
	restore_prog_state  = __fastcopy_restore_prog_state
	restore_prog_visual = __fastcopy_restore_prog_visual
	save_debug_state    = __fastcopy_save_debug_state
	save_prog_state     = __fastcopy_save_prog_state

	; aliases
	save_debug_visual    = __fastcopy_save_debug_state
	restore_debug_visual = __fastcopy_restore_debug_state
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
