;******************************************************************************
; ERRLOG.ASM
; This file contains the code for a general purpose logging.
; Log files are stored to disk
;******************************************************************************

.include "file.inc"
.include "macros.inc"
.include "zeropage.inc"

;******************************************************************************
.BSS
file_id: .byte 0

.CODE

;******************************************************************************
; NEW
; Begins a new log by opening a log file (log) and, if necessary, deleting the
; existing one
.export __log_new
.proc __log_new
	ldxy #@filename
	jsr file::open
	rts

.PUSHSEG
.RODATA
@filename: .byte "log",0
.POPSEG
.endproc

;******************************************************************************
; OUT
; Writes the 0-terminated string to the open log file
.export __log_out
.proc __log_out
	; TODO:
	rts
.endproc

;******************************************************************************
; CLOSE
; Closes the log file that was created with log::new.
.export __log_close
.proc __log_close
	lda file_id
	jmp file::close
.endproc
