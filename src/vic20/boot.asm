;*******************************************************************************
; BOOT.ASM
; This is the entrypoint.  Performs necessary initialization and jumps to the
; editor main loop.
; If CART is defined, copies code from cartridge to RAM.  If it isn't defined,
; loads it from disk.
;*******************************************************************************
.include "../asm.inc"
.include "../config.inc"
.include "../monitor.inc"
.include "../copybuff.inc"
.include "../debug.inc"
.include "../debuginfo.inc"
.include "../draw.inc"
.include "../edit.inc"
.include "../irq.inc"
.include "../io.inc"
.include "../key.inc"
.include "../labels.inc"
.include "../macros.inc"
.include "../memory.inc"
.include "../runtime.inc"
.include "../screen.inc"
.include "../settings.inc"
.include "../sim6502.inc"
.include "../source.inc"
.include "../text.inc"
.include "../vmem.inc"
.include "../zeropage.inc"

.include "fastcopy.inc"
.include "vic20.inc"

.import __SETUP_LOAD__
.import __SETUP_RUN__
.import __SETUP_SIZE__

.import __BANKCODE_LOAD__
.import __BANKCODE_RUN__
.import __BANKCODE_SIZE__

.import __BANKCODE2_LOAD__
.import __BANKCODE2_RUN__
.import __BANKCODE2_SIZE__

.import __BSS_LOAD__
.import __BSS_SIZE__

.import __DATA_LOAD__
.import __DATA_RUN__
.import __DATA_SIZE__

.import __DEBUGINFO_CODE_LOAD__
.import __DEBUGINFO_CODE_RUN__
.import __DEBUGINFO_CODE_SIZE__

.import __FASTTEXT_LOAD__
.import __FASTTEXT_SIZE__
.import __FASTTEXT_RUN__

.import __MACROCODE_LOAD__
.import __MACROCODE_RUN__
.import __MACROCODE_SIZE__

.import __VSCREEN_LOAD__
.import __VSCREEN_RUN__
.import __VSCREEN_SIZE__

.import __IRQ_LOAD__
.import __IRQ_RUN__
.import __IRQ_SIZE__

.import __LINKER_LOAD__
.import __LINKER_RUN__
.import __LINKER_SIZE__

.import __OBJCODE_LOAD__
.import __OBJCODE_RUN__
.import __OBJCODE_SIZE__

.import __LABELS_LOAD__
.import __LABELS_RUN__
.import __LABELS_SIZE__

.import __FASTCOPY_LOAD__
.import __FASTCOPY_RUN__
.import __FASTCOPY_SIZE__

.import __EXPR_LOAD__
.import __EXPR_RUN__
.import __EXPR_SIZE__

.import __UDGEDIT_LOAD__
.import __UDGEDIT_RUN__
.import __UDGEDIT_SIZE__

.import __CONSOLE_LOAD__
.import __CONSOLE_RUN__
.import __CONSOLE_SIZE__

.import __COPYBUFF_LOAD__
.import __COPYBUFF_RUN__
.import __COPYBUFF_SIZE__

.import __RODATA_LOAD__
.import __RODATA_RUN__
.import __RODATA_SIZE__

.linecont +
TOTAL_SIZE = __SETUP_SIZE__+__BANKCODE_SIZE__+__BANKCODE2_SIZE__+__DATA_SIZE__+\
	     __FASTTEXT_SIZE__+__MACROCODE_SIZE__+__VSCREEN_SIZE__+ \
	     __IRQ_SIZE__+__LINKER_SIZE__+__LABELS_SIZE__+__UDGEDIT_SIZE__+ \
	     __EXPR_SIZE__ + __CONSOLE_SIZE__+__COPYBUFF_SIZE__+ \
	     __RODATA_SIZE__ + __DEBUGINFO_CODE_SIZE__+__FASTCOPY_SIZE__+ \
	     __OBJCODE_SIZE__
.linecont -

;*******************************************************************************
; RELOC
; relocates code from 1 address to another
; IN:
;  - .A: destination bank
;  - r0r1: source address
;  - r2r3: dest address
;  - r4:   number of bytes to copy
.macro reloc BANK
@src=r0
@dst=r2
@size=r4
@bank=r6
	sta @bank
	lda @size+1
	beq @lastpage

	ldy #$00
@pageloop:
	lda #BANK
	sta $9c02	; source bank

	lda (@src),y

	ldx @bank
	stx $9c02	; dest bank

	sta (@dst),y
	iny
	bne @pageloop
	inc @src+1
	inc @dst+1
	dec @size+1
	bne @pageloop

@lastpage:
	ldy @size
	beq @done
	dey
:	lda #$a1
	sta $9c02	; source bank
	lda (@src),y
	ldx @bank
	stx $9c02	; dest bank
	sta (@dst),y
	dey
	cpy #$ff
	bne :-

@done:	lda #BANK
	sta $9c02
.endmacro

.ifndef CART	; DISK
.segment "SETUP"
;*******************************************************************************
; BASIC header: SYS 4621
.word @head
@head: .word @next
.word .version
.byte $9e
.asciiz "4621"
@next: .word 0
	lda #$11|$08
	sta $900f		; white/white
	lda #$c0
	sta $9005		; screen @ $1000
	lda #00			; # of columns and rows
	sta $9002
	sta $9003
	jmp start

;*******************************************************************************
; CART header and boot code
.else ; CART
.segment "CART"
.word cart_start	; Entry point for power up
.word edit::init	; Entry point for warm start (RESTORE)

; cartridge header
.byte "a0",$C3,$C2,$CD	; "A0CBM"

; copy cart binary ($0000-$6000) to RAM
cart_start:
	jsr $fd52	; init vectors
	jsr $fdf9	; init I/O

	sei
	lda #$7f
	sta $911e

	lda #$11|$08
	sta $900f		; white/white
	lda #$c0
	sta $9005		; screen @ $1000
	lda #00			; # of columns and rows
	sta $9002
	sta $9003

	ldx #@end-@unlock
:	lda @unlock-1,x
	sta $200-1,x
	dex
	bne :-

	; run the unlock code
	jmp $200

;-----------------------
@unlock:
	ldx $a000
	stx $a000
	sta $9c02
	cmp $9c02

	; activate ROM bank 0
	lda #$40
	sta $9c02

	; copy SETUP
	ldxy #$2000
	stxy r0
	ldxy #__SETUP_RUN__
	stxy r2

	ldx #>TOTAL_SIZE+1	; # of pages to copy
	ldy #$00

@reloc: ; read from ROM bank and write to RAM bank
	lda (r0),y
	sta (r2),y
	iny
	bne @reloc
	inc r0+1
	inc r2+1
	dex			; next page
	bne @reloc

	; set default device number
	lda #DEFAULT_DEVICE
	sta zp::device

	jmp start
@end:
;-----------------------
.segment "SETUP"
.endif	; CART

;*******************************************************************************
; LOWINIT
; Code that is sensitive to initialization order
; This code loads the app and sets up various banked code.
; Once the initialization in complete, jumps to enter to begin the app
.proc lowinit
	lda #CUR_BLINK_SPEED
	sta zp::curtmr

.ifdef CART
; CART init code; copy the application from ROM bank 1
	; copy the app and enter it
	lda #$41	; ROM 32k page #1
	sta $9c02

	; copy everything from $2000-$8000
	ldxy #$2000
	stxy r0
	ldx #$60	; 96 pages
	ldy #$00
@l0:	lda (r0),y	; reads from ROM in ROM bank 1
	sta (r0),y	; writes go to RAM in RAM bank 1
	iny
	bne @l0
	inc r0+1	; next page
	cpx #$30
	bne :+
	ldy #$00
:	dex
	bne @l0

	lda #FINAL_BANK_MAIN
	sta $9c02
	jmp enter

.else
; DISK init code; load the application from file
	; load the app and enter it
	lda #FINAL_BANK_MAIN
	sta $9c02
	ldxy #@mainprg
	lda #@mainprg_len
	jsr $ffbd	; SETNAM
	lda #$01
	ldx $ba		; last used device
	bne :+
	ldx #$0a	; default to #10
:	ldy #$01	; load to address stored in file
	jsr $ffba	; SETLFS

	lda #$00	; load (not verify)
	jsr $ffd5	; LOAD
	jmp enter
@mainprg: .byte "masm.prg"
@mainprg_len=*-@mainprg
.endif
.endproc

;*******************************************************************************
; drawlogo
.macro drawlogo
	; set all color to blue
	lda #$06
	ldx #$00
:	sta $9400,x
	dex
	bne :-

.ifdef NTSC
	ldx #$08
	ldy #$30
.else
	ldx #$10
	ldy #$30
.endif
	stx $9000		; horizontal centering

	lda #$30
	sta $9001

	; draw the boot screen
	ldx #18*7
:	lda bootlogo-1,x
	sta $1000-1,x
	dex
	bne :-

	; now update the # of rows and columns to make the screen visible
	lda #18			; # of columns
	sta $9002
	lda #7<<1		; # of rows
	sta $9003
.endmacro

;*******************************************************************************
; START
; Entrypoint to program
.proc start
	sei
	lda #$7f
	sta $911e

	drawlogo

	; enable all memory
	lda #FINAL_BANK_MAIN
	sta $9c02

	; restore default KERNAL vectors
	jsr $fd52
	ldxy #$eb15
	stxy $0314

;--------------------------------------
; zero the BSS segment
	lda #>__BSS_LOAD__
	sta r0+1
	ldy #<__BSS_LOAD__
	lda #$00
@zerobss:
	sta (r0),y
	iny
	bne :+
	inc r0+1
:	cpy #<(__BSS_LOAD__+__BSS_SIZE__-1)
	bne @zerobss
	ldx r0+1
	cpx #>(__BSS_LOAD__+__BSS_SIZE__-1)
	bne @zerobss

;--------------------------------------
; relocate segments that need to be moved
@cnt=r7
@relocs=r8
	lda #num_relocs
	sta @cnt
	ldxy #relocs
	stxy @relocs
@reloc:	ldy #$00
	lda (@relocs),y
	sta r0
	iny
	lda (@relocs),y
	sta r0+1

	; destination
	iny
	lda (@relocs),y
	sta r2
	iny
	lda (@relocs),y
	sta r2+1

	; size
	iny
	lda (@relocs),y
	sta r4
	iny
	lda (@relocs),y
	sta r4+1

	; bank
	iny
	lda (@relocs),y

	reloc FINAL_BANK_MAIN

	lda @relocs
	clc
	adc #$07
	sta @relocs
	bcc :+
	inc @relocs+1
:	dec @cnt
	bne @reloc

	; perform the machine-specific initialization
	jsr vic20::init

	; initialize the JMP vector
	lda #$4c		; JMP
	sta zp::jmpaddr

	; clean up files
	jsr $ffe7		; CLALL (close all files)

	lda #$80
	sta $028a	; repeat all characters
	sta $0291	; don't swap charset on C= + SHIFT

	; clear row colors
	lda #DEFAULT_900F
	ldx #24-1
:	lda #DEFAULT_900F
	sta mem::rowcolors,x
	lda #COLOR_NORMAL
	sta mem::rowcolors_idx,x
	dex
	bpl :-

	jmp lowinit
.endproc

;*******************************************************************************
bootlogo:
	.include "bootlogo.dat"

;*******************************************************************************
; RELOCS
; Table of start and target addresses for segments that need to be relocated
relocs:
; BANK CODE
.word __BANKCODE_LOAD__, __BANKCODE_RUN__, __BANKCODE_SIZE__
.byte FINAL_BANK_MAIN

; BANK CODE 2
.word __BANKCODE2_LOAD__, __BANKCODE2_RUN__, __BANKCODE2_SIZE__
.byte FINAL_BANK_MAIN

; DATA
.word __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.byte FINAL_BANK_MAIN

; DEBUGINFO_CODE
.word __DEBUGINFO_CODE_LOAD__, __DEBUGINFO_CODE_RUN__, __DEBUGINFO_CODE_SIZE__
.byte FINAL_BANK_DEBUG

; FASTTEXT
.word __FASTTEXT_LOAD__, __FASTTEXT_RUN__, __FASTTEXT_SIZE__
.byte FINAL_BANK_FASTTEXT

; MACRO
.word __MACROCODE_LOAD__, __MACROCODE_RUN__, __MACROCODE_SIZE__
.byte FINAL_BANK_MACROS

; IRQ
.word __IRQ_LOAD__, __IRQ_RUN__, __IRQ_SIZE__
.byte FINAL_BANK_MAIN

; SCREEN
.word __VSCREEN_LOAD__, __VSCREEN_RUN__, __VSCREEN_SIZE__
.byte FINAL_BANK_VSCREEN

; LINKER
.word __LINKER_LOAD__, __LINKER_RUN__, __LINKER_SIZE__
.byte FINAL_BANK_LINKER

; OBJCODE
.word __OBJCODE_LOAD__, __OBJCODE_RUN__, __OBJCODE_SIZE__
.byte FINAL_BANK_LINKER

; LABELS
.word __LABELS_LOAD__, __LABELS_RUN__, __LABELS_SIZE__
.byte FINAL_BANK_SYMBOLS

; EXPR
.word __EXPR_LOAD__, __EXPR_RUN__, __EXPR_SIZE__
.byte FINAL_BANK_UDGEDIT

; UDG EDITOR
.word __UDGEDIT_LOAD__, __UDGEDIT_RUN__, __UDGEDIT_SIZE__
.byte FINAL_BANK_UDGEDIT

; CONSOLE
.word __CONSOLE_LOAD__, __CONSOLE_RUN__, __CONSOLE_SIZE__
.byte FINAL_BANK_MONITOR

; COPYBUFF
.word __COPYBUFF_LOAD__, __COPYBUFF_RUN__, __COPYBUFF_SIZE__
.byte FINAL_BANK_BUFF

; FASTCOPY
.word __FASTCOPY_LOAD__, __FASTCOPY_RUN__, __FASTCOPY_SIZE__
.byte FINAL_BANK_FASTCOPY

; RODATA
.word __RODATA_LOAD__, __RODATA_RUN__, __RODATA_SIZE__
.byte FINAL_BANK_MAIN

num_relocs=(*-relocs)/7

.CODE
;*******************************************************************************
; ENTER
; Entrypoint after initialization, from here on we're safe to use the bitmap
; address space ($1000-$2000) as a bitmap
.export enter
.proc enter
	lda #$00
	sta zp::banksp
	lda #$4c
	sta zp::bankjmpaddr	; write the JMP instruction

	; initialize screen
	jsr scr::init
	sei
	jsr edit::clear
	lda #$00
	sta $c6			; clear keyboard buffer

.ifdef CART
@detect_reset:
	ldx #init_sig_len-1
:	lda init_sig,x
	cmp mem::init_sig,x
	bne @init		; not a match -> complete initialization
	dex
	bpl :-

@recover:
        jsr irq::on
	; signature intact, ask user if they wish to recover
	ldxy #recover_reset
	lda #10
	jsr text::print
	jsr key::waitch
	pha
        jsr irq::off
	pla
	cmp #$79		; Y
	beq @enter
	cmp #$6e		; N
	bne @recover
.endif

@init:
	jsr src::init
	jsr src::new
	jsr dbgi::initonce
	jsr asm::reset
	jsr buff::clear		; clear copy buffer
	jsr run::clr		; init user state (run BASIC startup proc)

	lda #$00
	sta mem::linebuffer
	CALL FINAL_BANK_MONITOR, mon::init

.ifndef TEST
@enter:
.ifdef CART
	; write the "initialized" signature
	ldx #init_sig_len-1
:	lda init_sig,x
	sta mem::init_sig,x
	dex
	bpl :-
.endif

	; init some BASIC variables that are used (keyboard ptrs/delay)
	lda #<$ebdc	; get keyboard decode logic pointer low byte
	sta $028f	; set keyboard decode logic pointer low byte
	lda #>$ebdc	; get keyboard decode logic pointer high byte
	sta $0290	; set keyboard decode logic pointer high byte
	lda #$0a
	sta $0289	; set maximum size of keyboard buffer
	sta $028c	; set repeat delay counter
	lda #$04
	sta $028b	; set repeat timer

	; initialize the status row reverse
	ldx #23
	jsr draw::hiline

        jsr irq::on
	jmp edit::init
.else
	.import testsuite
	jmp testsuite
.endif
.endproc

.ifdef CART
init_sig:
	.byte 6,5,6,0
init_sig_len=*-init_sig

.PUSHSEG
.RODATA
recover_reset:
	.byte " reset detected - restore state? (y/n)",0
.POPSEG
.endif
