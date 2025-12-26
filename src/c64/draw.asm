.include "c64.inc"
.include "layout.inc"
.include "macros.inc"
.include "settings.inc"
.include "../macros.inc"
.include "../memory.inc"
.include "../zeropage.inc"

; mirrored from draw.inc
COLOR_TEXT    = 0
COLOR_NORMAL  = 1
COLOR_RVS     = 2
COLOR_BRKON   = 3
COLOR_BRKOFF  = 4
COLOR_SUCCESS = 5
COLOR_SELECT  = 6


.CODE

;******************************************************************************
; HILINE
.export __draw_hiline
.proc __draw_hiline
	cmp #COLOR_NORMAL
	bne __draw_hline
.endproc

;******************************************************************************
; RESETLINE
.export __draw_resetline
.proc __draw_resetline
@dst=r0
	ldy c64::rowslo,x
	sty @dst
	ldy c64::rowshi,x
	sty @dst+1

	ldy #SCREEN_WIDTH-1
:	lda (@dst),y
	and #$7f
	sta (@dst),y
	dey
	bpl :-
	rts
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
	ldy c64::rowslo,x
	sty @dst
	ldy c64::rowshi,x
	sty @dst+1

	ldy #SCREEN_WIDTH-1
:	lda (@dst),y
	ora #$80
	sta (@dst),y
	dey
	bpl :-
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
