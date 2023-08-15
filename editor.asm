.include "asm.inc"
.include "bitmap.inc"
.include "codes.inc"
.include "config.inc"
.include "cursor.inc"
.include "errors.inc"
.include "file.inc"
.include "format.inc"
.include "key.inc"
.include "layout.inc"
.include "labels.inc"
.include "memory.inc"
.include "source.inc"
.include "state.inc"
.include "string.inc"
.include "text.inc"
.include "util.inc"
.include "view.inc"
.include "zeropage.inc"

.include "macros.inc"
.import help

.CODE
;--------------------------------------
.proc draw_titlebar
	ldxy #titlebar
	lda #$00
	jsr text::puts
	lda #$00
	jmp bm::rvsline
.endproc

;--------------------------------------
.export __edit_init
.proc __edit_init
        jsr bm::init
        jsr bm::clr

	jsr edit

	jsr draw_titlebar
	jsr text::clrline

	; don't assemble code, just verify it
	lda #$01
	sta state::verify

	ldx #$00
	ldy #$01
	jmp cur::set
.endproc

;--------------------------------------
.export __edit_run
.proc __edit_run
; run is the main loop for the editor
main:

        lda #$70
        cmp $9004
        bne *-3

	sei
	jsr key::getch
	cmp #$00
	beq @done
	jsr onkey

@done:
	jsr text::update
	jsr text::status
	jmp main
.endproc

;--------------------------------------
.proc save_state
	jmp bm::save
.endproc

;--------------------------------------
.proc restore_state
	jmp bm::restore
.endproc

;--------------------------------------
.proc command_go
	jsr lbl::addr
	bcs @not_found
	stxy @target
@target=*+1
	jsr $f00d
	jmp restore_state
@not_found:
	rts
.endproc

;--------------------------------------
; reset clears all state relating to the assembly of the active file.
.proc reset
	jsr asm::reset
	jmp lbl::clr
.endproc

;--------------------------------------
; command_asm assembles the entire source into mem::program
.export command_asm
.proc command_asm
	jsr src::pushp
	jsr src::rewind
	jsr src::next
	jsr reset

	; disable verify - actually assemble the code
	lda #$00
	sta state::verify
@doline:
	jsr src::readline
	ldxy #mem::linebuffer
	jsr asm::tokenize
	bcc :+
	jmp reporterr

:	inc @ll
	jsr src::end
	bne @doline
@ll=*+1
	lda #$00

	jsr src::popp
	jsr src::goto

@printresult:
	lda #$00
	sta state::verify	; re-enable verify

	ldxy zp::asmresult
	sub16 #mem::program
	txa
	pha
	tya
	pha

	ldxy #success_msg
	lda #STATUS_ROW-1
	jsr text::print
	jmp text::clrline

success_msg: .byte "done $", $fe, " bytes", 0
.endproc

;--------------------------------------
; readinput reads command input and returns it (0-terminated) in mem::linebuffer
; a prompt may be given in the address XY. If XY is 0, a ':' will be
; used
; .C is set if no input was read (the user pressed <-)
.proc readinput
@prompt=zp::tmp0
@result_offset=zp::tmp8
	txa
	pha
	tya
	pha
	jsr text::savebuff
	jsr text::clrline
	pla
	tay
	pla
	tax

	cmpw #0
	beq @terminate_prompt
	stxy @prompt
	ldy #$00
:	lda (@prompt),y
	beq @terminate_prompt
	sta mem::linebuffer,y
	iny
	bne :-
@terminate_prompt:
	lda #':'
	sta mem::linebuffer,y

	lda zp::curx
	pha
	lda zp::cury
	pha

	iny
	sty @result_offset

	; set cursor limit for the prompt
	ldx @result_offset
	ldy #STATUS_ROW-1
	jsr cur::setmin
	ldx #40
	ldy #STATUS_ROW+1
	jsr cur::setmax

	; set the cursor
	ldx @result_offset
	ldy #STATUS_ROW
	jsr cur::set

	ldxy #mem::linebuffer
	lda #STATUS_ROW
	jsr text::drawline
@getkey:
        lda #$70
        cmp $9004
        bne *-3
	jsr text::update

	jsr key::getch
	cmp #$0d
	beq @done
	cmp #$5f	; <- (done)
	beq @exit
	cmp #$00
	beq @getkey
	jsr text::putch
	jmp @getkey

@done:
	clc	; clear carry for success
@exit:		; carry is implicitly set by CMP for ==
	php
	jsr edit
	plp
	pla
	tay
	pla
	tax
	php	; save success state
	; restore curosr/editor
	jsr cur::set
	; move the read text into $100
	ldx @result_offset
@saveres:
	lda mem::linebuffer,x
	sta $100,x
	beq :+
	inx
	bne @saveres

:	jsr text::restorebuff
	ldx @result_offset
	ldy #$01
	plp	; get success state
	rts
.endproc

;--------------------------------------
.proc docommand
; .A contains the command
@prompt=$100
@cmd=@prompt
	sta @prompt

	; construct the prompt
	lda #$00
	sta $101
	ldxy #@prompt
	jsr readinput
	bcc :+
	rts

:	ldx #@num_commands-1
	lda @cmd
:	cmp @command_codes,x
	beq @found
	dex
	bpl :-
	rts

@found:
	txa
	asl
	tax
	lda @command_table,x
	sta @cmd_vec
	lda @command_table+1,x
	sta @cmd_vec+1

	ldx #<$102
	ldy #>$102
@cmd_vec=*+1
	jmp $0000

; commands
@command_codes:
.byte 'g'
.byte 'o'
.byte 's'
.byte 'x'
@num_commands=*-@command_codes
@command_table:
.word command_go
.word load
.word save
.word scratch
.endproc

;--------------------------------------
; onkey is called upon the user pressing a key.
.proc onkey
	ldx #@num_special_keys-1

@l0:	cmp @specialkeys,x
	beq @special
	dex
	bpl @l0

	; handle the "docommand" functions
	cmp #$a5	; C=<G> (Go)
	bne :+
	lda #'g'
	jmp docommand
:	cmp #$b9	; C=<O> (Open)
	bne :+
	lda #'o'
	jmp docommand
:	cmp #$ae	; C=<S> (Save)
	bne :+
	lda #'s'
	jmp docommand
:	cmp #$bd	; C=<X> (Scratch)
	bne @insert
	lda #'x'
	jmp docommand

@insert:
	jsr insert
	jsr cur::off
	jmp cur::on

@special:
	txa
	asl
	tax
	lda @specialkeys_vectors,x
	sta @vec
	lda @specialkeys_vectors+1,x
	sta @vec+1
@vec=*+1
	jmp $f00d

@specialkeys:
	.byte $13	; HOME
	.byte $85	; F1 (save)
	.byte $89	; F2 (save as)
	.byte $86	; F3 (assemble)
	.byte $87	; F5 (nop)
	.byte $bc	; C=<C> (refresh)
	.byte $b4	; C=<H> (HELP)
	.byte $b2	; C=<R> (rename)
	.byte $be	; C=<V> (view)
	.byte $b6	; C=<L> (dir)
	.byte $a7	; C=<M> (gotoline)
@num_special_keys=*-@specialkeys
@specialkeys_vectors:
	.word home
	.word save
	.word saveas
	.word command_asm
	.word command_nop
	.word refresh
	.word help
	.word rename
	.word memview
	.word dir
	.word command_gotoline
.endproc

;--------------------------------------
.proc home
	ldx zp::curx
	beq :+
	jsr src::up
	ldx #$00
	ldy zp::cury
	jsr cur::set
:	rts
.endproc

;--------------------------------------
.proc command_nop
	rts
.endproc

;--------------------------------------
; refresh redraws the screen
.proc refresh
	jsr cur::off
	jsr __edit_init
	jsr src::rewind
	jsr src::next	; first character index is 1
@l0:
	jsr src::readline
	jsr drawline
	jsr src::end
	bne @l0
	rts
.endproc

;--------------------------------------
; dir lists the directory
.proc dir
	jsr bm::save
	jsr text::clrline
	jsr text::dir

	; get a selection
:	jsr key::getch
	cmp #$0d
	bne :-
	jmp bm::restore
.endproc

;--------------------------------------
; rename gets user input to rename the buffer and applies the new name.
.proc rename
	jsr text::savebuff
	jsr text::clrline
	getinput mem::statusline+23,0,23,(40-16)
	ldxy #mem::linebuffer
	; TODO: jsr file::rename
	jsr text::restorebuff
	lda zp::cury
	jmp text::drawline
.endproc

;--------------------------------------
; saveas allows the user to name the current buffer- then writes it to a file
; of the same name.
.proc saveas
	jmp save
.endproc

;--------------------------------------
; edit configures the cursor/screen/etc. for editing
.proc edit
	lda #$01
	sta text::insertmode
	ldx #$00
	ldy #$01
	jsr cur::setmin
	ldx #40
	ldy #STATUS_ROW
	jmp cur::setmax
.endproc

;--------------------------------------
; save writes the source buffer to a file.
.proc save
@file=zp::tmp9
	stx @file
	sty @file+1

	; get the file length
	jsr str::len
	pha

	ldxy #@savingmsg
	lda #STATUS_ROW
	jsr text::print

	ldx @file
	ldy @file+1
	pla
	jsr file::save
	sei
	cmp #$00
	bne @err
	rts	; no error
@err:
	rts
	pha
	lda #$00
	pha
	ldxy #@errmsg
	lda #STATUS_ROW
	jsr text::print
	rts
@savingmsg:
	.byte "saving...",0
@errmsg:
.byte "failed to save file; error ", $fe, 0
.endproc

;--------------------------------------
.proc scratch
@file=zp::tmp9
	stx @file
	sty @file+1

	; get the file length
	jsr str::len
	pha

	ldxy #@savingmsg
	lda #STATUS_ROW
	jsr text::print

	ldx @file
	ldy @file+1
	pla
	jsr file::scratch
	cmp #$00
	bne @err
	rts	; no error
@err:
	pha
	lda #$00
	pha
	ldxy #@errmsg
	lda #STATUS_ROW
	jmp text::print
@savingmsg:
	.byte "deleting...",0
@errmsg:
	.byte "failed to delete file; error ", $fe, 0
.endproc

;--------------------------------------
; load loads the file from disk into the source buffer
.proc load
@file=zp::tmp9
@dst=zp::tmpb
	stx @file
	sty @file+1

	; reinitialize the editor (clear screen, etc.)
	jsr __edit_init

	; get the file length
	ldxy @file
	jsr str::len

@found:
	tya
	pha

	ldxy #@loadingmsg
	lda #STATUS_ROW
	jsr text::print

	; set the address to load file into
	ldxy #src::buffer
	stxy @dst

	ldxy @file
	pla
	jsr file::load
	sei	; re-set I flag
	cmp #$00
	bne @err
	jsr reset

	jmp refresh
@err:
	pha
	lda #$00
	pha
	ldxy #@errmsg
	lda #STATUS_ROW
	jsr text::print
	rts
@loadingmsg:
	.byte "loading...",0
@errmsg:
.byte "failed to load file; error $", $fe, 0
.endproc

;--------------------------------------
; linedone attempts to compile the line entered in (mem::linebuffer)
.proc linedone
	; insert \n into source buffer and terminate text buffer
	lda #$0d
	jsr src::insert
	lda #$00
	jsr text::putch

	lda zp::curx
	beq @format	; @ column 0, skip to insert (format will be ignored)

	; check if the current line is valid
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr asm::tokenize
	tax
	bmi @err
@format:
	; format the line
	cmp #ASM_LABEL
	beq @fmt
	cmp #ASM_MACRO
	beq @fmt
	cmp #ASM_OPCODE
	bne @nextline	; no formatting
@fmt:	jsr fmt::line

@nextline:
	jsr drawline

	; redraw the cleared status line
	jsr text::update

	; redraw everything from <cursor> to EOL on next line
	jsr src::get
	ldxy #mem::linebuffer
	lda zp::cury
	jsr text::print
	rts

@err:	lda #$ff
	; highlight the error line
	ldx #ERROR_COLOR
	lda zp::cury
	jsr text::hiline
	jmp @nextline
.endproc

;--------------------------------------
; drawline draws the line in mem::linebuffer at the current cursor position.
; The cursor is then updated and the screen scrolled.
.proc drawline
	lda zp::cury
	jsr text::drawline
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr text::hioff
@nextline:
	; scroll lines below cursor position
	ldy zp::cury
	iny
	cpy #STATUS_ROW-1
	bcc :+
	; if we're at the bottom, scroll whole screen up
	ldx #1
	lda #STATUS_ROW-1
	jsr text::scrollup

	ldy zp::cury
	ldx #$00
	jmp cur::set

:	tya
	ldx #STATUS_ROW-1
	jsr text::scrolldown

@done:
	jsr clrerror
	; move the cursor to the next line
	ldy zp::cury
	iny
	ldx #$00
	jmp cur::set
.endproc

;--------------------------------------
; memview displays the memory view (if enabled)
.proc memview
	ldx #<src::buffer
	ldy #>src::buffer
	jsr view::edit
	jmp edit
.endproc

;-------------------------------------
.proc clrerror
	; clear any error message
	jsr text::clrline
	ldxy #mem::linebuffer
	lda #ERROR_ROW
	jsr text::putz
	jmp text::hioff
.endproc

;--------------------------------------
; insert adds a character at the cursor position.
.proc insert
	cmp #$80
	bcs @controlcodes
	cmp #' '
	bcs @printable

@controlcodes:
	ldx #numccodes-1
:	cmp controlcodes,x
	beq @cc
	dex
	bpl :-
	jmp @put

@cc:	txa
	asl
	tax
	lda ccvectors,x
	sta @j
	lda ccvectors+1,x
	sta @j+1
@j=*+1
	jmp $0000

@printable:
	ldx text::insertmode
	bne @put
@replace:
	jsr src::replace
	jmp text::putch
@put:	jsr src::insert
	jmp text::putch
.endproc

;--------------------------------------
.proc ccup
	ldxy src::line
	cmpw #1
	bne :+		; at line 1, don't scroll
	jsr src::up
	ldx #$00
	ldy zp::cury
	jmp cur::set

:	jsr src::up
	lda zp::cury
	pha
	jsr cur::up
	pla
	cmp zp::cury
	beq @scroll

@noscroll:
@cnt=zp::tmp6
	lda zp::curx	; leftmost column
	beq @redraw

	jsr src::up
	jsr src::get	; for rendering get source from start of line

	; go til lesser of curx or newline ($0d)
	lda #$ff
	sta @cnt
:	inc @cnt
	lda @cnt
	cmp zp::curx
	bcs @redraw2
	jsr src::next
	cmp #$0d
	bne :-
	jsr src::prev
	ldx @cnt
	ldy zp::cury
	jsr cur::set
	jmp @redraw2

@scroll:
	lda #$01
	ldx #STATUS_ROW-1
	jsr text::scrolldown	; cursor wasn't moved, scroll

@redraw:
	jsr src::get
@redraw2:
	lda zp::cury
	ldxy #mem::linebuffer
	jmp text::drawline
.endproc

;--------------------------------------
.proc ccleft
	lda zp::curx
	beq :+
	pha
	jsr cur::left
	pla
	cmp zp::curx
	beq :+
	jmp src::prev
:	rts
.endproc

;--------------------------------------
.proc ccright
	jsr src::right
	bcc :+
	jmp cur::right
:	rts
.endproc

;--------------------------------------
.proc ccdown
@cnt=zp::tmp6
@newy=zp::tmp7
@xend=zp::tmp8
	jsr src::end
	bne :+
	rts

:	lda #$00
	sta @cnt
	lda zp::cury
	sta @newy

	jsr src::down
	bcc :+
	jsr src::up
	jsr src::get
	lda #$ff
	sta @xend
	jmp @movex

:	inc @newy
	lda zp::curx
	sta @xend
	jsr src::get

	; if the cursor is on a newline, we're done
	jsr src::end
	beq @movecur
	jsr src::next
	jsr src::atcursor
	cmp #$0d
	php
	jsr src::prev
	plp
	beq @movecur

@movex:
	jsr src::next
	cmp #$0d
	bne :+
	jsr src::prev	; don't pass the newline
	jmp @movecur
:	inc @cnt
	lda @cnt
	cmp @xend
	bcs @movecur
	jsr src::end
	bne @movex

@movecur:
	ldx @cnt
	lda @newy
	tay
	pha
	jsr cur::set
	pla
	cmp zp::cury
	beq @redraw

	ldx #1
	lda #STATUS_ROW-1
	jsr text::scrollup	; cursor wasn't moved, scroll

@redraw:
	ldxy #mem::linebuffer
	lda zp::cury
	jmp text::drawline
.endproc

;--------------------------------------
.proc ccdel
@cnt=zp::tmp6
	jsr src::start
	bne :+
	rts

:	jsr src::backspace
	lda #$14
	jsr text::putch
	bcs @prevline
@deldone:
	rts

@prevline:
	; move the cursor
	ldy #$ff
	ldx #0
	jsr cur::move

	; scroll everything up from below the line we deleted
	ldx zp::cury
	lda #STATUS_ROW-1
	jsr text::scrollup
	jsr draw_titlebar

	jsr text::clrline
	; get the length of the line we're moving up
	jsr src::get

	; if the current char is a newline, we're done
	jsr src::atcursor
	cmp #$0d
	beq @redraw

	ldxy #mem::linebuffer
	jsr str::len
	sta @line2len

	; get the new cursor position
	; new_line_len - (old_line2_len)
	jsr src::up
	;jsr src::start
	;beq @redraw
	jsr src::get
	ldxy #mem::linebuffer
	jsr str::len
	sec
@line2len=*+1
	sbc #$00
	sta @cnt
	dec @cnt
	bmi @redraw
@endofline:
	inc zp::curx
	jsr src::next
	dec @cnt
	bpl @endofline

@redraw:
	lda zp::cury
	ldx #<mem::linebuffer
	ldy #>mem::linebuffer
	jsr text::drawline
	jmp src::end
.endproc

;--------------------------------------
.proc command_gotoline
	ldxy #$0000
	jsr readinput
	jsr atoi	; convert (YX) to line #
	bcs @done
	cmpw #$0000
	bne :+
	ldxy #$0001
:	jmp gotoline
@done:
	rts
.endproc

;--------------------------------------
; gotoline sets the editor to the line in .YX and refreshes the screen.
.proc gotoline
@target=zp::tmp6
@row=zp::tmp8
@seekforward=zp::tmp9	; 0=backwards 1=forwards
@diff=zp::tmpa		; lines to move up or down
@startline=zp::tmpc
@endline=zp::tmpe
	cmpw src::lines
	bcc :+
	ldxy src::lines
:	stxy @target
	lda zp::curx
	beq :+
	jsr src::up	; if we're not already, move to the start of the line

:	ldy zp::cury
	ldx #$00
	stx @seekforward
	jsr cur::set

	ldxy @target
	cmpw src::line	; is the target forward or backward?
	bne :+
	rts		; already on the target line
:	bcc :+
	inc @seekforward

	; get the number of lines to move forwards
	lda @target
	sec
	sbc src::line
	sta @diff
	lda @target+1
	sbc src::line+1
	sta @diff+1

	bne @long
	lda zp::cury
	clc
	adc @diff
	cmp #EDITOR_HEIGHT+EDITOR_ROW_START
	bcs @long
	jmp @short

:	; get the number of lines to move backwards
	lda src::line
	sec
	sbc @target
	sta @diff
	lda src::line+1
	sbc @target+1
	sta @diff+1

	bne @long
	ldy zp::cury
	dey
	tya
	sec
	sbc @diff
	bmi @long

@short:
	ldy #$00
	lda @seekforward
	bne :+

	; move up and move cursor
	ldx @diff
	jsr src::upn
	lda #$00
	sec
	sbc @diff
	tay
	ldx #$00
	jmp cur::move

:	; move down and move cursor
	ldx @diff
	jsr src::downn
	ldy @diff
	ldx #$00
	jmp cur::move

@long:
	; get first line of source buffer to render (target +/- (EDITOR_HEIGHT - cury)
	ldxy @diff
	sub16 #EDITOR_HEIGHT
	bpl @movesrc
	; diff-EDITOR_HEIGHT < 0, need to move in the opposite direction
	stxy @diff
	lda #$00
	sec
	sbc @diff
	tax
	ldy #$00		; hi byte is 0, can't be < -EDITOR_HEIGHT
	lda @seekforward
	beq :+
	jsr src::upn		; move up before we render downward
	jmp @longf_cont
:	jsr src::downn		; move down before we we render upward
	jmp @longb_cont

@movesrc:
	lda @seekforward
	beq @longb

@longf:
	jsr src::downn ; go to the first line to render
@longf_cont:
	lda #EDITOR_ROW_START
	bne @longmove_cont
@longb:
	jsr src::upn ; go to the first line to render
@longb_cont:
	lda #EDITOR_ROW_START+EDITOR_HEIGHT

@longmove_cont:
	sta @row
	; the first line to render is the target line we're going to minus the
	; cursor's Y position

@l0:
	jsr src::get
	php
	ldxy #mem::linebuffer
	lda @row
	jsr text::drawline
	plp
	bcs @clearextra

	lda @seekforward
	bne :+

	; backwards
	dec @row
	lda @row
	cmp #EDITOR_ROW_START
	bcc @renderdone
	jsr src::up
	jmp @l0

:	; forwards
	inc @row
	lda @row
	cmp #EDITOR_ROW_START + EDITOR_HEIGHT + 1
	bcs @renderdone
	jsr src::down
	bcc @l0

@clearextra:
	jsr text::clrline
	lda @row
	bne :+
	lda #$01
	sta @row
:	pha
@clrloop:
	ldxy #mem::linebuffer
	jsr text::drawline
	lda @seekforward
	bne :+
	dec @row
	bpl @clrnext
:	inc @row
@clrnext:
	lda @row
	cmp #EDITOR_ROW_START
	bcc @renderdone
	cmp #EDITOR_ROW_START + EDITOR_HEIGHT + 1
	bcc @clrloop
	pla
	sta @row
@renderdone:
	; move the cursor to the top if we searched backwards or bottomif forward
	ldy @row
	ldx #$00
	jmp cur::set
.endproc

;--------------------------------------
; REPORTERR
; reports the given error
; in:
;  -A: the error code
.proc reporterr
	jmp err::print
.endproc

.DATA
;--------------------------------------
controlcodes:
.byte $9d	; left
.byte $1d	; right
.byte $91	; up arrow
.byte $11	; down
.byte $14	; delete
.byte $0d	; RETURN
numccodes=*-controlcodes

;--------------------------------------
ccvectors:
.word ccleft    ; left
.word ccright	; right
.word ccup      ; up
.word ccdown	; down
.word ccdel 	; delete
.word linedone	; RETURN

;--------------------------------------
titlebar:
.byte "monster                      c=<h>: help"
