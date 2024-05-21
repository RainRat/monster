;******************************************************************************
; UDGEDIT.ASM
;
; This file contains the source for the UDG Editor module, which allows a user
; to define "user defined graphics", or UDG's, for insertion into their code.
; The UDG Editor displays an 8x8 grid that can be navigated using the normal
; vi-like navigation keys. Plotting pixels is done with the '1' key.
; Pressing ENTER confirms the creation of a graphic, while the QUIT key
; exits the editor without creating the graphic.
;
; It is up to the caller (the editor) to update the source with the data for
; the created graphic
;******************************************************************************

.include "../keycodes.inc"
.include "../macros.inc"
.include "../zeropage.inc"

;******************************************************************************
BITMAP_ADDR = $1100
PIXEL_SIZE = 4		; size of each pixel in the editor

CANVAS_Y      = 40		; start row (in pixels)
CANVAS_X      = 24		; start column (in pixels)
CANVAS_HEIGHT = 8*PIXEL_SIZE
CANVAS_WIDTH  = 8*PIXEL_SIZE

BORDER_SIZE = 4		; border around editor (in pixels)

color   = zp::editortmp
cur_on  = zp::editortmp+1	; cursor on flag
cur_tmr = zp::editortmp+2	; cursor blink timer
udg     = r8

linebuffer = $0400

.CODE
.word @header
@header:

;******************************************************************************
; ENTER
; Activates the UDG editor
; OUT:
;  - r8-rf: the character that the user created
;  - .C:    set if the user quit the editor without creating a character
;           clear if the user did create a new UDG
.export __udgedit_enter
.proc __udgedit_enter
	cli
	jsr clrcanvas

	; parse linebuffer, populate udg (r8) if line contains a .db directive
	jsr parse_bytes

	; draw any pixels that are set
	lda #7
	sta zp::cury
@l0:	lda #7
	sta zp::curx
@l1:	ldx zp::curx
	lda udg,x
	and $8270,x
	beq :+
	jsr plot
:	dec zp::curx
	bpl @l1
	dec zp::cury
	bpl @l0

	; move cursor back to (0,0)
	inc zp::curx
	inc zp::cury

@main:	dec cur_tmr
	bne :+
	jsr curtoggle

:	jsr $f1f9		; get key
	cmp #$00
	beq @main
	cmp #K_RETURN
	beq @ok
	cmp #K_QUIT
	beq @ret
	jsr handlekey
	jmp @main

@ok:	clc
	rts

@ret:	sec			; no graphic created
	rts
.endproc

;******************************************************************************
; HANDLEKEY
.proc handlekey
	ldx #@numkeys-1
:	cmp @keys,x
	beq @handle
	dex
	bpl :-
	rts	; nothing to do for key

@handle:
	lda @handlerslo,x
	sta zp::jmpvec
	lda @handlershi,x
	sta zp::jmpvec+1
	jmp zp::jmpaddr

@keys:
	.byte $4b, $4a, $48, $4c, '1'	; k, j, h, l
@numkeys=*-@keys

.define handlers up, down, left, right, plot
@handlerslo: .lobytes handlers
@handlershi: .hibytes handlers
.endproc

;******************************************************************************
; CLRCANVAS
; Clears the 8x8 UDG canvas and the underlying character data
.proc clrcanvas
@dst=r0
	; clear the character buffer
	lda #$00
	sta cur_on	; clear cursor status

	ldx #$07
:	sta udg,x
	dex
	bpl :-

	; clear the bitmap area of the canvas
	ldxy #BITMAP_ADDR+($c0*(CANVAS_X/8))+CANVAS_Y-1-$c0
	stxy @dst
	ldx #CANVAS_WIDTH/8+1	; +1 for border

; draw left border
	lda #$01
	ldy #CANVAS_HEIGHT+1
:	sta (@dst),y
	dey
	bpl :-
	bmi @nextcol

@l0:	lda #$00
	ldy #CANVAS_HEIGHT+1
	lda #$ff
	sta (@dst),y	; bottom border
	dey
:	lda #$00
	sta (@dst),y
	dey
	bne :-

	lda #$ff
	sta (@dst),y	; top border

@nextcol:
	lda @dst
	clc
	adc #$c0	; next col
	sta @dst
	bcc :+
	inc @dst+1
:	dex
	bne @l0

@rborder:
	; draw rightborder
	lda #$80
	ldy #CANVAS_HEIGHT+1
:	sta (@dst),y
	dey
	bpl :-

@done:	rts
.endproc

;******************************************************************************
; CUROFF
; Turns off the cursor
.proc curoff
	lda cur_on
	beq @done	; already off
	jmp curtoggle
@done:	rts
.endproc

;******************************************************************************
; CURON
; Turns on the cursor
.proc curon
	lda cur_on
	bne @done	; already on
	jmp curtoggle
@done:	rts
.endproc

;******************************************************************************
; CURTOGGLE
; Toggles the cursor
.proc curtoggle
@dst=r0
	lda cur_on
	eor #$01
	sta cur_on

	lda zp::curx
	lsr
	tax

	lda colslo+(CANVAS_X/8),x
	clc
	adc #CANVAS_Y
	sta @dst
	lda colshi+(CANVAS_X/8),x
	sta @dst+1

	lda zp::cury
	asl
	asl
	tay
	lda zp::curx
	and #$01
	bne @oddcol

@evencol:
	lda #$f0
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$90
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$90
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$f0
	eor (@dst),y
	sta (@dst),y
	rts

@oddcol:
	lda #$0f
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$09
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$09
	eor (@dst),y
	sta (@dst),y
	iny
	lda #$0f
	eor (@dst),y
	sta (@dst),y
	rts
.endproc

;******************************************************************************
; PLOT
; Plots the given (x,y) coordinate on the canvas
.proc plot
@dst=r0
@mask=r2
	jsr curoff
	lda zp::curx
	lsr
	tax

	lda colslo+(CANVAS_X/8),x
	clc
	adc #CANVAS_Y
	sta @dst
	lda colshi+(CANVAS_X/8),x
	sta @dst+1

	lda zp::cury
	asl
	asl
	tay

	lda zp::curx
	and #$01
	bne :+
	lda #$f0	; even mask
	skw
:	lda #$0f	; odd mask
	sta @mask

; draw the pixel
	ldx #4
:	lda @mask
	ora (@dst),y
	sta (@dst),y
	iny
	dex
	bne :-

	; fall through to setpixel in memory
.endproc

;******************************************************************************
; SETPIXEL
; Sets the pixel at the cursor to the active color
.proc setpixel
	; update the UDG pixel data
	lda #$07
	sec
	sbc zp::curx
	tax
	ldy zp::cury
	lda udg,y
	ora $8270,x	; charrom '/' (mask associated with pixel)
	sta udg,y
	rts
.endproc

;******************************************************************************
; RIGHT
; Handle the "move right" behavior
.proc right
	jsr curoff
	lda zp::curx
	cmp #7
	bcs :+
	inc zp::curx
:	rts
.endproc

;******************************************************************************
; LEFT
; Handle the "move left" behavior
.proc left
	jsr curoff
	dec zp::curx
	bpl :+
	inc zp::curx
:	rts
.endproc

;******************************************************************************
; DOWN
; Handle the "move down" behavior
.proc down
	jsr curoff
	lda zp::cury
	cmp #7
	bcs :+
	inc zp::cury
:	rts
.endproc

;******************************************************************************
; UP
; Handle the "move up" behavior
.proc up
	jsr curoff
	dec zp::cury
	bpl :+
	inc zp::cury
:	rts
.endproc

;******************************************************************************
; IN:
;  - .X: the LSB of the 2 character string hex value
;  - .Y: the MSB of the 2 character string hex value
; OUT:
;  - .A: the binary value
.proc parsehex
@byte=r4
	tya
	jsr @tohex
	asl
	asl
	asl
	asl
	sta @byte
	txa
	jsr @tohex
	ora @byte
@done:	rts
@tohex:
	cmp #'f'+1
	bcs @done
	cmp #'a'
	bcc :+
	sbc #'a'-$a
	rts

:	cmp #'F'+1
	bcs @done
	cmp #'A'
	bcc @numeric
	sbc #'A'-$a
	rts

@numeric:
	cmp #'9'+1
	bcs @done
	cmp #'0'
	bcc @done
	sbc #'0'
	rts
.endproc

;******************************************************************************
; PARSE_BYTES
; Parses the line for graphic data
; Graphic data lines are .DB directives. If more than 8 bytes are defined
; in the line, the first 8 are used for the character.
; If less than 8 are defined, the remaining characters are padded with zeroes.
; NOTE: only hex values are supported
.proc parse_bytes
@buff=r0
@udg=r2
	ldxy #linebuffer
	stxy @buff
	ldxy #udg
	stxy @udg

	ldy #$00
@finddb:
	lda (@buff),y
	beq @done
	cmp #$0d
	beq @done
	cmp #';'
	beq @done
	cmp #$09		; TAB
	beq @nextch
	cmp #' '
	beq @nextch
	cmp #'.'
	bne @done		; not a .DB
	iny
	lda (@buff),y
	cmp #'D'
	beq :+
	cmp #'d'
	bne @done		; not .DB
:	iny
	lda (@buff),y
	cmp #'B'
	beq @getbytes
	cmp #'b'
	beq @getbytes
@done:	rts			; no .DB
@nextch:
	iny
	bne @finddb

; .DB was found, parse the data
@getbytes:
	tya
	adc @buff	; +1 (.C is set)
	sta @buff

@parsebyte:
	ldy #$00
	lda (@buff),y
	beq @done
	cmp #$0d
	beq @done
	cmp #';'
	beq @done

	cmp #' '
	beq @next
	cmp #$09
	beq @next

	cmp #'$'
	bne @done	; unexpected char
@hex:	incw @buff
	ldy #$01
	lda (@buff),y	; least significant hex digit
	tax
	dey
	lda (@buff),y	; most significant hex digit
	tay
	jsr parsehex
	ldy #$00
	sta (@udg),y	; save the result
	incw @udg

	incw @buff
	incw @buff

	ldy #$00
@findcomma:
	lda (@buff),y
	beq @done
	cmp #$0d
	beq @done
	cmp #' '
	beq :+
	cmp #$09	; TAB
	beq :+
	cmp #','
	beq @next
	bne @done	; unexpected char
:	incw @buff
	jmp @findcomma

@next:	incw @buff
	jmp @parsebyte
.endproc


;******************************************************************************
.linecont +
.define cols $1100, $11c0, $1280, $1340, $1400, $14c0, $1580, $1640, $1700, \
  $17c0, $1880, $1940, $1a00, $1ac0, $1b80, $1c40, $1d00, $1dc0, $1e80, $1f40
.linecont -
colslo: .lobytes cols
colshi: .hibytes cols
