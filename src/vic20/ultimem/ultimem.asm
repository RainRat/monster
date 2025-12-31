;*******************************************************************************
; ULTIMEM.ASM
;*******************************************************************************

.include "../../zeropage.inc"

;*******************************************************************************
.export __ultimem_select_bank
.proc __ultimem_select_bank
	; TODO:
.endproc

;*******************************************************************************
.export __ultimem_push_bank
.proc __ultimem_push_bank
	lda $9c02		; get current bank
	ldx zp::banksp
	inc zp::banksp
	sta zp::bankstack,x	; save current bank
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_MAIN
.proc __ultimem_use_MAIN
	lda #$00
	sta $9ff8	; BLK1
	lda #$01
	sta $9ffa	; BLK2
	lda #$02
	sta $9ffc	; BLK3
	lda #$03
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE0
.proc __ultimem_use_SOURCE0
	lda #$04
	sta $9ff8	; BLK1
	lda #$05
	sta $9ffa	; BLK2
	lda #$06
	sta $9ffc	; BLK3
	lda #$07
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE1
.proc __ultimem_use_SOURCE1
	lda #$08
	sta $9ff8	; BLK1
	lda #$09
	sta $9ffa	; BLK2
	lda #$0a
	sta $9ffc	; BLK3
	lda #$0b
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE2
.proc __ultimem_use_SOURCE2
	lda #$0c
	sta $9ff8	; BLK1
	lda #$0d
	sta $9ffa	; BLK2
	lda #$0e
	sta $9ffc	; BLK3
	lda #$0f
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE3
.proc __ultimem_use_SOURCE3
	lda #$10
	sta $9ff8	; BLK1
	lda #$11
	sta $9ffa	; BLK2
	lda #$12
	sta $9ffc	; BLK3
	lda #$13
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE4
.proc __ultimem_use_SOURCE4
	lda #$14
	sta $9ff8	; BLK1
	lda #$15
	sta $9ffa	; BLK2
	lda #$16
	sta $9ffc	; BLK3
	lda #$17
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE5
.proc __ultimem_use_SOURCE5
	lda #$18
	sta $9ff8	; BLK1
	lda #$19
	sta $9ffa	; BLK2
	lda #$1a
	sta $9ffc	; BLK3
	lda #$1b
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE6
.proc __ultimem_use_SOURCE6
	lda #$1c
	sta $9ff8	; BLK1
	lda #$1d
	sta $9ffa	; BLK2
	lda #$1e
	sta $9ffc	; BLK3
	lda #$1f
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SOURCE7
.proc __ultimem_use_SOURCE7
	lda #$20
	sta $9ff8	; BLK1
	lda #$21
	sta $9ffa	; BLK2
	lda #$22
	sta $9ffc	; BLK3
	lda #$23
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_MACROS
.proc __ultimem_use_MACROS
	lda #$24
	sta $9ff8	; BLK1
	lda #$25
	sta $9ffa	; BLK2
	lda #$26
	sta $9ffc	; BLK3
	lda #$27
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_UDGEDIT
.proc __ultimem_use_UDGEDIT
	lda #$28
	sta $9ff8	; BLK1
	lda #$29
	sta $9ffa	; BLK2
	lda #$2a
	sta $9ffc	; BLK3
	lda #$2b
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_LINKER
.proc __ultimem_use_LINKER
	lda #$2c
	sta $9ff8	; BLK1
	lda #$2d
	sta $9ffa	; BLK2
	lda #$2e
	sta $9ffc	; BLK3
	lda #$2f
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_MONITOR
.proc __ultimem_use_MONITOR
	lda #$30
	sta $9ff8	; BLK1
	lda #$31
	sta $9ffa	; BLK2
	lda #$32
	sta $9ffc	; BLK3
	lda #$33
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_BUFF
.proc __ultimem_use_BUFF
	lda #$34
	sta $9ff8	; BLK1
	lda #$35
	sta $9ffa	; BLK2
	lda #$36
	sta $9ffc	; BLK3
	lda #$37
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SYMBOLS
.proc __ultimem_use_SYMBOLS
	lda #$38
	sta $9ff8	; BLK1
	lda #$39
	sta $9ffa	; BLK2
	lda #$3a
	sta $9ffc	; BLK3
	lda #$3b
	sta $9ffe	; BLK5
	rts
.endproc

;*******************************************************************************
.export __ultimem_use_SYMVIEW
.proc __ultimem_use_SYMVIEW
	lda #$3c
	sta $9ff8	; BLK1
	lda #$3d
	sta $9ffa	; BLK2
	lda #$3e
	sta $9ffc	; BLK3
	lda #$3f
	sta $9ffe	; BLK5
	rts
.endproc
