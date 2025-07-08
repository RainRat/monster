;*******************************************************************************
; BREAKPOINTS.ASM
; This file contains code/data for interacting with breakpoints.
; In their most primitive form, breakpoints are addresses that the debugger will
; use to determine where to insert BRK's into the program that is being
; debugged.
;*******************************************************************************

.include "debug.inc"
.include "debuginfo.inc"
.include "draw.inc"
.include "edit.inc"
.include "errors.inc"
.include "gui.inc"
.include "key.inc"
.include "keycodes.inc"
.include "labels.inc"
.include "layout.inc"
.include "macros.inc"
.include "memory.inc"
.include "source.inc"
.include "settings.inc"
.include "strings.inc"
.include "text.inc"
.include "ui.inc"
.include "zeropage.inc"

;*******************************************************************************
; CONSTANTS
HEIGHT             = BRKVIEW_STOP-BRKVIEW_START-1
BREAKPOINT_ENABLED = 1

.CODE

;*******************************************************************************
; EDIT
; Begins the breakpoint editor
.export __breakpoint_edit
.proc __breakpoint_edit
	; display the title
	ldxy #@menu
	lda #BRKVIEW_STOP
	jmp gui::listmenu

.PUSHSEG
.RODATA
@menu:
.byte HEIGHT				; max height
.word @getkey				; key handler
.word ui::render_breakpoint		; get line handler
.word dbg::numbreakpoints		; # of breakpoints pointer
.word strings::breakpoints_title	; title

;--------------------------------------
@getkey:
	cmp #K_RETURN
	bne @chkdel
	; toggle the breakpoint's active status
	txa
	jsr toggle_breakpoint
	RETURN_OK
@chkdel:
	cmp #K_DEL		; DEL
	bne @done
	ldy dbg::breakpointshi,x
	lda dbg::breakpointslo,x
	tax
	jsr dbg::removebreakpoint
@done:	RETURN_OK
.endproc
.POPSEG

;*******************************************************************************
; TOGGLE_BREAKPOINT
; Toggles the given breakpoint, turning it off it was on or on if it was off
; IN:
;  - .A: the breakpoint to toggle active/inactive
.proc toggle_breakpoint
	tax
	lda dbg::breakpoint_flags,x
	eor #BREAKPOINT_ENABLED
	sta dbg::breakpoint_flags,x

	; if the breakpoint is visible, toggle its color
	lda dbg::breakpoint_lineslo,x
	ldy dbg::breakpoint_lineshi,x
	tax
	jsr edit::src2screen
	tax
	bcs :+

	lda mem::rowcolors,x
	eor #(BREAKPOINT_OFF_COLOR)^(BREAKPOINT_ON_COLOR)
	sta mem::rowcolors,x

:	rts
.endproc

;*******************************************************************************
; GETBYLINE
; Returns the ID of the breakpoint at the given line (if one exists)
; IN:
;  - .XY: the line # to get the breakpoint at
;  - .A:  the file ID of the breakpoint
; OUT:
;  - .A: the flags for the breakpoint
;  - .X: the ID of the breakpoint at the given line (if one exists)
;  - .C: set if there is no breakpoint at the given line
.export __brkpt_getbyline
.proc __brkpt_getbyline
@line=r2
@file=r4
	stxy @line
	sta @file

	; find the matching line #
	ldx dbg::numbreakpoints
	beq @notfound
	dex
@l0:	lda @file
	cmp dbg::breakpoint_fileids,x
	bne @next
	lda @line
	cmp dbg::breakpoint_lineslo,x
	bne @next
	lda @line+1
	cmp dbg::breakpoint_lineshi,x
	bne @next
	lda dbg::breakpoint_flags,x
	RETURN_OK

@next:	dex
	bpl @l0
@notfound:
	sec		; not found
@done:	rts
.endproc

;*******************************************************************************
; NUM
; Returns the number of breakpoints
; OUT:
;  - .A: the number of breakpoints
.export __brkpt_num
.proc __brkpt_num
	lda dbg::numbreakpoints
	rts
.endproc
