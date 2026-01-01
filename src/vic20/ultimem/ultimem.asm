;*******************************************************************************
; ULTIMEM.ASM
; This file contains utilities for selecting RAM/ROM configurations in the
; Ultimem
; At a high level, RAM123 and IO 2/3 are generally used as shared RAM across
; all banks.
; BLK's 1, 2, 3, 5 are generally configured to be ROM containing code for the
; bank.
;*******************************************************************************

.include "../../zeropage.inc"

.segment "ULTIREGS"
;*******************************************************************************
; BANK
; This virtual register contains the current "bank", which is used to
; select the appropriate configuration of Ultimem registers by looking them
; up in the tables (see ultim::select_bank)
.export __ultimem_bank
__ultimem_bank: .byte 0

.segment "ULTICFG"

;*******************************************************************************
.export __ultimem_select_bank
.proc __ultimem_select_bank
	stx @savex
	sta @savea
	tax

	lda cfglo,x
	sta $9ff1
	lda cfghi,x
	sta $9ff2
	lda iolo,x
	sta $9ff6
	lda iohi,x
	sta $9ff7
	lda blk1lo,x
	sta $9ff8
	lda blk1hi,x
	sta $9ff9
	lda blk2lo,x
	sta $9ffa
	lda blk2hi,x
	sta $9ffb
	lda blk3hi,x
	sta $9ffc
	lda blk3hi,x
	sta $9ffd
	lda blk5lo,x
	sta $9ffe
	lda blk5hi,x
	sta $9fff

@savex=*+1
	ldx #$00
@savea=*+1
	lda #$00
	rts
.endproc

;*******************************************************************************
;             MAIN   SRC0   SRC1   SRC2   SRC3   SRC4   SRC5   SRC6   SRC7
;             MACS   UDGS   LINK   MON    BUFF   SYMS   SYMV   ERRS
.linecont +
.define io   $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, \
             $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
.define blk1 $0001, $0002, $0005, $0008, $000b, $000e, $0011, $0014, $0017, \
             $001a, $0001, $0005, $0008, $000b, $000e, $0011, $0014
.define blk2 $0002, $0003, $0006, $0009, $000c, $000f, $0012, $0015, $0018, \
             $001b, $0002, $0005, $0008, $000b, $000e, $0011, $0014
.define blk3 $0003, $0001, $0007, $000a, $000d, $0010, $0013, $0016, $0019, \
             $001c, $0001, $0005, $0008, $000b, $000e, $0011, $0014
.define blk5 $0001, $0004, $0004, $0004, $0004, $0004, $0004, $0004, $0004, \
             $0005, $0006, $0007, $0008, $0009, $000a, $000b, $0014
.define cfg  $6a15, $9515, $9515, $9515, $9515, $9515, $9515, $9515, $9515, \
             $9515, $9515, $9515, $9515, $9515, $9515, $9515, $9515
.linecont -

iolo:   .lobytes io
iohi:   .hibytes io
blk1lo: .lobytes blk1
blk1hi: .hibytes blk1
blk2lo: .lobytes blk2
blk2hi: .hibytes blk2
blk3lo: .lobytes blk3
blk3hi: .hibytes blk3
blk5lo: .lobytes blk5
blk5hi: .hibytes blk5
cfglo:  .lobytes cfg
cfghi:  .hibytes cfg
