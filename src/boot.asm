.include "asm.inc"
.include "bitmap.inc"
.include "debug.inc"
.include "edit.inc"
.include "fastcopy.inc"
.include "fasttext.inc"
.include "finalex.inc"
.include "irq.inc"
.include "labels.inc"
.include "macros.inc"
.include "memory.inc"
.include "module.inc"
.include "source.inc"
.include "vmem.inc"
.include "zeropage.inc"

.import __BSS_LOAD__
.import __BSS_SIZE__

.import __DATA_LOAD__
.import __DATA_RUN__
.import __DATA_SIZE__

.import __FASTTEXT_LOAD__
.import __FASTTEXT_SIZE__
.import __FASTTEXT_RUN__

.import __MACROCODE_LOAD__
.import __MACROCODE_RUN__
.import __MACROCODE_SIZE__

.import __SAVESCR_LOAD__
.import __SAVESCR_RUN__
.import __SAVESCR_SIZE__

.import __IRQ_LOAD__
.import __IRQ_RUN__
.import __IRQ_SIZE__

.import __LINKER_LOAD__
.import __LINKER_RUN__
.import __LINKER_SIZE__

.import __LABELS_LOAD__
.import __LABELS_RUN__
.import __LABELS_SIZE__

;******************************************************************************
; RELOC
; relocates code from 1 address to another
; IN:
;  - .A: destination bank
;  - r0r1: source address
;  - r2r3: dest address
;  - r4:   number of bytes to copy
.macro reloc
@src=r0
@dst=r2
@size=r4
@bank=r6
	sta @bank
@copy:	ldy #$00
	lda #$a1
	sta $9c02
	lda (@src),y
	ldx @bank
	stx $9c02
	sta (@dst),y
	incw @src
	incw @dst
	decw @size
	ldxy @size
	cmpw #$00
	bne @copy
	lda #$a1
	sta $9c02
.endmacro

.segment "SETUP"
;******************************************************************************
; BASIC header: SYS 4621
.word @head
@head: .word @next
.word .version
.byte $9e
.asciiz "4621"
@next: .word 0
	jmp start

;******************************************************************************
; LOADMODS
; load modules from disk to their designated bank
; This lives in the SETUP first because loading main.prg can clobber data above
; $2000
.proc loadmods

;--------------------------------------
; setup interrupt vectors
	ldxy #@module_udgedit
	lda #MOD_UDGEDIT
	jsr mod::load

;--------------------------------------
; generate low code (must occur after we're done init'ing
	jsr fe3::init
	lda #FINAL_BANK_FASTCOPY
	jsr fcpy::init
	lda #FINAL_BANK_FASTCOPY2
	jsr fcpy::init

	lda #FINAL_BANK_MAIN
	sta $9c02

	ldxy #@module_main
	lda #MOD_MAIN
	jsr mod::load

	jmp enter
@module_udgedit: .byte "udg.prg",0
@module_main:    .byte "monster.prg",0
.endproc

;******************************************************************************
; START
; Entrypoint to program
start:
	sei

	; enable all memory
	lda #$a1
	sta $9c02

	; restore default KERNAL vectors
	jsr $fd52

	; print loading message
	ldx #$00
:	lda @loading,x
	jsr $ffd2
	inx
	cpx #@loadinglen
	bne :-

	; install dummmy IRQ
	ldxy #$eb15
	stxy $0314

;--------------------------------------
; zero the BSS segment
	ldxy #__BSS_LOAD__
	stxy r0
@zerobss:
	ldy #$00
	tya
	sta (r0),y
	incw r0
	ldxy r0
	cmpw #(__BSS_LOAD__+__BSS_SIZE__)
	bne @zerobss

;--------------------------------------
; relocate segments that need to be moved
@cnt=r7
@relocs=r8
	sei
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

	reloc

	lda @relocs
	clc
	adc #$07
	sta @relocs
	bcc :+
	inc @relocs+1
:
	dec @cnt
	bne @reloc

	lda #FINAL_BANK_FASTTEXT
	sta $9c02
	jsr ftxt::init

;--------------------------------------
; initialize the JMP vector
	lda #$4c		; JMP
	sta zp::jmpaddr


;--------------------------------------
; clean up files
	jsr $ffe7		; CLALL (close all files)

;--------------------------------------
; misc. setup
	; save current screen for debugger
	;jsr dbg::save_progstate

	; TODO: enable write-protection for the $2000-$8000 blocks when
	; all SMC is removed from the segments in that range
	lda #$a1
	sta $9c02	; enable 35K of RAM for final expansion

	sta $028a	; repeat all characters
	sta $0291	; don't swap charset on C= + SHIFT

	jmp loadmods

@loading: .byte "init.."
@loadinglen=*-@loading

;******************************************************************************
; RELOCS
; Table of start and target addresses for segments that need to be relocated
relocs:
; DATA
.word __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.byte FINAL_BANK_MAIN

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
.word __SAVESCR_LOAD__, __SAVESCR_RUN__, __SAVESCR_SIZE__
.byte FINAL_BANK_SAVESCR

; LINKER
.word __LINKER_LOAD__, __LINKER_RUN__, __LINKER_SIZE__
.byte FINAL_BANK_LINKER

; LABELS
.word __LABELS_LOAD__, __LABELS_RUN__, __LABELS_SIZE__
.byte FINAL_BANK_SYMBOLS

num_relocs=(*-relocs)/7

.export get_crunched_byte
.proc get_crunched_byte
.endproc

.CODE
;******************************************************************************
; ENTER
; Entrypoint after initialization, from here on we're safe to use the bitmap
; address space ($1000-$2000) as a bitmap
.export enter
enter:
	ldx #<irq::sys_update
        ldy #>irq::sys_update
        lda #$20
        jsr irq::raster
	lda #<start
	sta $0316		; BRK
	sta $0318		; NMI
	lda #>start
	sta $0317		; BRK
	sta $0319		; NMI

	ldx #$ff
	txs
	jsr asm::reset
	jsr src::new
	jsr edit::init
	jmp edit::run
