;*******************************************************************************
; WATCHES.ASM
; This file contains code/data for interacting with breakpoints.
; Watches are addresses that the debugger will use to determine where to halt a
; trace.  Watches also have a flag associated with them, which allows the
; watch to be triggered only when the value is read from or written to.
;*******************************************************************************

.include "config.inc"
.include "cursor.inc"
.include "debug.inc"
.include "draw.inc"
.include "edit.inc"
.include "errors.inc"
.include "expr.inc"
.include "flags.inc"
.include "gui.inc"
.include "key.inc"
.include "keycodes.inc"
.include "labels.inc"
.include "layout.inc"
.include "macros.inc"
.include "memory.inc"
.include "source.inc"
.include "strings.inc"
.include "text.inc"
.include "util.inc"
.include "view.inc"
.include "vmem.inc"
.include "zeropage.inc"

.include "vic20/finalex.inc"

;*******************************************************************************
; CONSTANTS
HEIGHT = WATCHVIEW_STOP-WATCHVIEW_START-1
MAX_WATCHPOINTS = 8	; max number of watchpoints that may be set

.BSS
;*******************************************************************************
scroll: .byte 0
row:	.byte 0

__watches_num:  .byte 0		    ; number of active watches

NUM_WATCH_TABLES=7
watch_data:
__watches_watcheslo:   .res MAX_WATCHPOINTS   ; addresses of the set watchpoints
__watches_watcheshi:   .res MAX_WATCHPOINTS   ; addresses of the set watchpoints
__watches_watch_vals:  .res MAX_WATCHPOINTS   ; values of the set watchpoints
__watches_watch_prevs: .res MAX_WATCHPOINTS   ; previous values of watches
__watches_watch_flags: .res MAX_WATCHPOINTS   ; flags for watches (e.g. DIRTY)

; the following are used for watches that represent a range of values
; e.g. [$1000, $1100)
__watches_watches_stoplo:    .res MAX_WATCHPOINTS ; end address of watch range
__watches_watches_stophi:    .res MAX_WATCHPOINTS ; end address of watch range

.export __watches_num
.export __watches_watch_flags

.CODE
;*******************************************************************************
; INIT
; Initializes the watch editor
.export __watches_init
.proc __watches_init
	lda #$00
	sta row
	sta scroll
	rts
.endproc

;*******************************************************************************
; EDIT
; Begins the breakpoint editor
.export __watches_edit
.proc __watches_edit
	; display the title
	ldxy #@menu
	lda #WATCHVIEW_STOP
	jmp gui::listmenu

.PUSHSEG
.RODATA
@menu:
.byte HEIGHT				; max height
.word @getkey				; key handler
.word __watches_tostring		; get line handler
.word __watches_num			; # of breakpoints pointer
.word strings::watches_title		; title
.POPSEG

;--------------------------------------
@getkey:
	cmp #K_RETURN
	bne @chkdel

	; invoke the memory editor at the selected watch's address
	lda row
	clc
	adc scroll
	tax
	lda __watches_watcheslo,x
	sta view::addr
	lda __watches_watcheshi,x
	sta view::addr+1
	jsr view::edit		; invoke the memory editor
	sec			; after returning from mem editor, quit
	rts

@chkdel:
	cmp #K_DEL		; DEL
	bne @done

	lda row
	clc
	adc scroll
	tax
	jsr __watches_remove

@done:	RETURN_OK
.endproc

;*******************************************************************************
; UPDATE
; Reads the new values of all locations being watched and stores them
; If the watch represents a RANGE of values, does not store new value.
; OUT:
;  - .A: the ID of the first watch triggered (if any)
;  - .C: set if any watch was triggered
.export __watches_update
.proc __watches_update
@cnt=r0
@addr=r1
	ldx __watches_num
	beq @done
	dex
	stx @cnt
@l0:	ldx @cnt
	lda __watches_watch_vals,x
	sta __watches_watch_prevs,x	; store curr value as prev

	ldx @cnt
	lda __watches_watcheslo,x
	ldy __watches_watcheshi,x
	tax

	jsr vmem::load
	ldx @cnt
	cmp __watches_watch_prevs,x	; same as old value?
	beq :+
	pha
	lda #WATCH_DIRTY
	ora __watches_watch_flags,x
	sta __watches_watch_flags,x	; mark value as DIRTY
	pla
:	sta __watches_watch_vals,x	; store new value
	dec @cnt
	bpl @l0
@done:	rts
.endproc

;*******************************************************************************
; IN RANGE
; Checks if the given address is in the range of the given watch
; IN:
;  - .XY: the address to check
;  - .A:  the ID of the watch to check
; OUT:
;  - .Z: set if the given address IS within the given watch's range
.proc in_range
@addr=r0
@watchstart=r2
@watchstop=r4
	stxy @addr
	tax
@chklo:
	lda @addr+1
	cmp __watches_watcheshi,x
	bcc @no 		; if MSB < addr's, not in range of this watch
	beq :+
	bcs @chkstop		; if MSB > addr's, addr is above low bound

:	lda @addr
	cmp __watches_watcheslo,x
	bcc @no			; if MSB == addr's and LSB > addr's, try next

@chkstop:
	lda @addr+1
	cmp __watches_watches_stophi,x
	bcc @yes
	beq :+
	bcs @no			; if MSB > addr, not in range of this watch
:	lda @addr
	cmp __watches_watches_stoplo,x ; if LSB <= addr, addr is in range
	beq @yes
	bcc @yes
@no:	sec
	rts
@yes:	RETURN_OK
.endproc

;*******************************************************************************
; MARK
; Marks the watch for the given address (if there is one) as DIRTY. Even if
; its value has not changed.
; IN:
;  - .XY: the address to mark dirty (if a watch exists for it)
;  - .A:  the mode to mark dirty: WATCH_LOAD, WATCH_STORE, or WATCH_LOAD_STORE
; OUT:
;  - .A: the first watch that matched the criteria to activate the trigger
;  - .C: set if the given address was being watched by at least 1 watch
.export __watches_mark
.proc __watches_mark
@cnt=r6
@addr=r7
@found=r9
@mode=ra
@match=rb
	sta @mode

	lda #$00
	sta @found

	stxy @addr
	ldx __watches_num
	beq @done
	dex
	stx @cnt

@l0:	lda @cnt
	ldxy @addr
	jsr in_range		; is the address in range for this watch?
	bcs @next
	ldx @cnt

	lda @mode
	and __watches_watch_flags,x
	beq @next			; if different mode, skip

	lda #WATCH_DIRTY
	ora __watches_watch_flags,x
	sta __watches_watch_flags,x	; mark this watchpoint as DIRTY
	inc @found
	stx @match

@next:	dec @cnt
	bpl @l0
@done:	ldx @found
	cpx #$01		; set .C if @found >= 1
	lda @match
	rts
.endproc

;*******************************************************************************
; ADD
; Adds a watch for the given memory location.
; IN:
;  - .XY: the address to add a watch for
;  - r0:  the STOP address to add the watch for
;  - .A:  the type of watch (WATCH_LOAD, WATCH_STORE, or WATCH_LOAD_STORE)
; OUT:
;   - .C: set if the watch was not added
.export __watches_add
.proc __watches_add
@stop=r0
@addr=r2
@flags=r4
	sta @flags
	stxy @addr
	ldx __watches_num
	beq :+

	; check if watch (in r2) already exists
	jsr getwatch
	bcs @done		; already a watch here, exit

	ldx __watches_num
:	lda @addr
	sta __watches_watcheslo,x
	lda @addr+1
	sta __watches_watcheshi,x

	lda @stop
	sta __watches_watches_stoplo,x
	lda @stop+1
	sta __watches_watches_stophi,x

	ldxy @addr
	jsr vmem::load
	ldx __watches_num
	sta __watches_watch_vals,x

	lda @flags
	sta __watches_watch_flags,x

	inc __watches_num
@done:	rts
.endproc

;*******************************************************************************
; REMOVE
; Removes the watch with the given ID
; IN:
;  - .A: the ID of the watch to remove
.export __watches_remove
.proc __watches_remove
@id=r6
@data=r7
	cmp __watches_num
	bcs @ret		; can't remove (invalid ID)

	sta @id
	ldxy #watch_data
	stxy @data

	ldx #NUM_WATCH_TABLES

	; shift watche data down
@l0:	ldy @id
	iny
@l1:	lda (@data),y
	dey
	sta (@data),y
	iny
	iny
	cpy __watches_num
	bcc @l1

	; move to next table
	lda @data
	; sec
	adc #MAX_WATCHPOINTS-1
	sta @data
	bcc @next
	inc @data+1

@next:	dex
	bne @l0
	dec __watches_num

@done:	clc
@ret:	rts
.endproc

;*******************************************************************************
; GETWATCH DATA
; Returns the properties of the given watch
; IN:
;   - .A: the ID of the watch to get the properties of
; OUT:
;   - .A: the flags for the watch
;   - .X: the number of watches total
;   - r4: the start address of the watch
;   - r6: the stop address of the watch
;   - r8: the current value of the watched address
;   - r9: the previous value of the watched address
.export __watches_getdata
.proc __watches_getdata
@start=r4
@stop=r6
@val=r8
@prev=r9
	tax

	lda __watches_watcheslo,x
	sta @start
	lda __watches_watcheshi,x
	sta @start+1

	lda __watches_watches_stoplo,x
	sta @stop
	lda __watches_watches_stophi,x
	sta @stop+1

	lda __watches_watch_vals,x
	sta @val

	lda __watches_watch_prevs,x
	sta @prev

	lda __watches_watch_flags,x
	ldx __watches_num
	rts
.endproc

;*******************************************************************************
; TOSTRING
; Returns the rendered string for the given watch.
; This is displayed in both the TUI and GUI watch viewer
; IN:
;  - .A: the watch to get the string for
; OUT:
;  - .XY: the rendered string for that watch
.export __watches_tostring
.proc __watches_tostring
@id=r2		; id of the watch to get
@range=r3	; if !0, start != stop (watch is a range)
@start=r4	; start address
@stop=r6	; stop address (same as start if NOT range)
@val=r8		; value of watch (if NOT range)
@prev=r9	; previous value of watch (if NOT range)
	sta @id
	jsr __watches_getdata
	tax			; save flags
	lda #$00
	sta @range

	lda @start
	cmp @stop
	beq :+
	inc @range		; flag that start != stop

:	lda @start+1
	cmp @stop+1
	beq :+
	inc @range		; flag that start != stop

:	; print the watch info
	lda @range		; is it a range of addresses?
	beq @valline		; not a range, continue

; if the stat address != stop address, print start and stop
@rangeline:
	; push the stop address
	lda @stop
	pha
	lda @stop+1
	pha

	; push the start address
	lda @start
	pha
	lda @start+1
	pha

	; push SPACE if not dirty or '!' if dirty
	ldy #' '
	txa				; get flags
	and #WATCH_DIRTY		; dirty?
	beq :+				; if NOT dirty, don't push previous value
	ldy #'!'			; dirty
:	tya
	pha

	; if start addr != stop addr, print the address range
	ldx #<strings::watches_range_line
	ldy #>strings::watches_range_line
	bne @getdatadone

; if the start address == stop address, just print the one address and its val
@valline:
	; push current value of the watch
	lda @val
	pha

	; is this watch dirty?
	ldxy #strings::watches_line	; default to "clean" string
	txa				; get flags
	and #WATCH_DIRTY		; dirty?
	beq :+				; if NOT dirty, don't push previous value

	; dirty, push previous value
	lda @prev
	pha				; push previous value if dirty
	ldxy #strings::watches_changed_line

:	; push the address
	lda @start
	pha
	lda @start+1
	pha

@getdatadone:
	; push the ID of the watch
	lda @id
	pha
	jsr text::render
	rts
.endproc

;*******************************************************************************
; GETWATCH
; Returns the index of the watch at the given address
; IN:
;  - r0: the stop address of the watch
;  - r2: the address of the watch
; OUT:
;  - .C: set if the watch exists
;  - .X: the id of the watch
.export getwatch
.proc getwatch
@stop=r0
@addr=r2
	ldx __watches_num
@l0:	lda @addr
	cmp __watches_watcheslo-1,x
	bne @next
	lda @addr+1
	cmp __watches_watcheshi-1,x
	bne @next
	lda @stop
	cmp __watches_watches_stoplo,x
	bne @next
	lda @stop+1
	cmp __watches_watches_stophi,x
	beq @done
@next:	dex
	bne @l0
	clc			; no watch exists
@done:	rts
.endproc
