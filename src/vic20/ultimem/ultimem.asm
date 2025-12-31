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

;*******************************************************************************
.export __ultimem_select_bank
.proc __ultimem_select_bank
	; TODO:
.endproc

;*******************************************************************************
; USE MAIN
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   ROM1   |   ROM2   |   ROM3   |   RAM1   |   RAM0   |   RAM0  |
;
.export __ultimem_use_MAIN
.proc __ultimem_use_MAIN
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE0
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM2   |   RAM3   |   RAM4   |   ROM4   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE0
.proc __ultimem_use_SOURCE0
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE1
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM5   |   RAM6   |   RAM7   |   ROM4   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE1
.proc __ultimem_use_SOURCE1
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE2
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM9   |   RAMA   |   RAMB   |   ROM5   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE2
.proc __ultimem_use_SOURCE2
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE3
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAMC   |   RAMD   |   RAME   |   ROM6   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE3
.proc __ultimem_use_SOURCE3
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE4
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAMF   |   RAM10  |   RAM11  |   ROM7   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE4
.proc __ultimem_use_SOURCE4
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE5
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM12  |   RAM13  |   RAM14  |   ROM8   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE5
.proc __ultimem_use_SOURCE5
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE6
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM15  |   RAM16  |   RAM17  |   ROM9   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE6
.proc __ultimem_use_SOURCE6
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc


;*******************************************************************************
; USE SOURCE7
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM18  |   RAM19  |   RAM1A  |   ROMA   |   RAM0   |   RAM0  |
;
.export __ultimem_use_SOURCE7
.proc __ultimem_use_SOURCE7
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE SOURCE7
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM1B  |   RAM1C  |   RAM1D  |   ROMB   |   RAM0   |   RAM0  |
;
.export __ultimem_use_MACROS
.proc __ultimem_use_MACROS
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE UDGEDIT
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM1E  |   RAM1F  |   RAM20  |   ROMC   |   RAM0   |   RAM0  |
;
.export __ultimem_use_UDGEDIT
.proc __ultimem_use_UDGEDIT
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
; USE LINKER
; Configures the Ultimem with the following configuration:
;  |  RAM123  |   BLK1   |   BLK2   |   BLK3   |   BLK5   |   IO2    |   IO3   |
;  |   RAM0   |   RAM1E  |   RAM1F  |   RAM20  |   ROMC   |   RAM0   |   RAM0  |
;
.export __ultimem_use_LINKER
.proc __ultimem_use_LINKER
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
.export __ultimem_use_MONITOR
.proc __ultimem_use_MONITOR
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
.export __ultimem_use_BUFF
.proc __ultimem_use_BUFF
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
.export __ultimem_use_SYMBOLS
.proc __ultimem_use_SYMBOLS
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
.export __ultimem_use_SYMVIEW
.proc __ultimem_use_SYMVIEW
	.byte $3c	; BLK1
	.byte $3d	; BLK2
	.byte $3e	; BLK3
	.byte $3f	; BLK5
.endproc

;*******************************************************************************
.export __ultimem_use_ERRORS
.proc __ultimem_use_ERRORS

.endproc
