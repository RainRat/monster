.include "c64.inc"
.include "layout.inc"
.include "macros.inc"
.include "settings.inc"
.include "../macros.inc"
.include "../memory.inc"
.include "../zeropage.inc"

.CODE

;******************************************************************************
; HILINE
.export __draw_hiline
.proc __draw_hiline
	lda #$55
	jmp __draw_hline
.endproc

;******************************************************************************
; RESETLINE
.export __draw_resetline
.proc __draw_resetline
	lda #$11

	; fall through
.endproc

;******************************************************************************
; HLINE
; Draws a horizontal line at the row given in .A
; IN:
;  - .A: the color to highlight with
;  - .X: the row to highlight
.export __draw_hline
.proc __draw_hline
@dst=r0
	IO_BEGIN
	ldy c64::crowslo,x
	sty @dst
	ldy c64::crowshi,x
	sty @dst+1

	ldy #SCREEN_WIDTH-1
:	sta (@dst),y
	dey
	bpl :-
	IO_DONE
	rts
.endproc

;******************************************************************************
; RVS UNDERLINE
; Reverses a horizontal line at the row given in .A (EOR)
; IN:
;  - .A: the row to draw a horizontal line at
;  - .W: the pattern to draw
.export __draw_rvs_underline
.proc __draw_rvs_underline
@dst=r0
	; TODO:
	rts
.endproc

;******************************************************************************
; SCROLLCOLORSU
; Scrolls all colors from the given start row to the given stop row up by the
; given amount
; IN:
;  - .X: the first row to scroll
;  - .Y: the last row to scroll
;  - .A: the amount to scroll
.export __draw_scrollcolorsu
.proc __draw_scrollcolorsu
	; TODO:
	rts
.endproc

;******************************************************************************
; SCROLLCOLORSD1
; Scrolls all colors in the given range down by 1. See __draw_scrollcolorsd1
; IN:
;  - .X: the first row to scroll
;  - .Y: the last row to scroll
.export __draw_scrollcolorsd1
.proc __draw_scrollcolorsd1
	; TODO:
	rts
.endproc

;******************************************************************************
; SCROLLCOLORSD
; Scrolls all colors from the given start row to the given stop row down by the
; given amount
; IN:
;  - .X: the first row to scroll
;  - .Y: the last row to scroll
;  - .A: the amount to scroll
.export __draw_scrollcolorsd
.proc __draw_scrollcolorsd
	; TODO:
	rts
.endproc

;******************************************************************************
; COLOROFF
; Disables color in the interrupt and sets the background to its default color
.export __draw_coloroff
.proc __draw_coloroff
	; TODO:
	rts
.endproc

;******************************************************************************
; REFRESH COLORS
.export __draw_refresh_colors
.proc __draw_refresh_colors
	; TODO
	rts
.endproc
