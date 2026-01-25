;******************************************************************************
; stack errors
ERR_STACK_UNDERFLOW = 1
ERR_STACK_OVERFLOW  = 2

;******************************************************************************
; string errors
ERR_LINE_TOO_LONG = 3

;******************************************************************************
; expression errors
ERR_INVALID_EXPRESSION = 4

;******************************************************************************
; macro errors
ERR_INVALID_MACRO_ARGS = 5
ERR_SYNTAX_ERROR       = 6
ERR_INVALID_DIRECTIVE  = 7
ERR_LABEL_UNDEFINED    = 8
ERR_UNMATCHED_ENDIF    = 9
ERR_TOO_MANY_MACROS    = 10

;******************************************************************************
; assembly errors
ERR_UNALIGNED_LABEL      = 11
ERR_ILLEGAL_OPCODE       = 12
ERR_ILLEGAL_ADDRMODE     = 13
ERR_OVERSIZED_OPERAND    = 14
ERR_ILLEGAL_LABEL        = 15
ERR_LABEL_TOO_LONG       = 16
ERR_UNEXPECTED_CHAR      = 17
ERR_IO_ERROR             = 18
ERR_NO_MACRO_NAME        = 19
ERR_UNRESOLVABLE_LABEL   = 20
ERR_CYCLIC_INCLUDE       = 21
ERR_FAILED_OPEN_INCLUDE  = 22
ERR_OVERLAPPING_SEGMENTS = 23
ERR_MAX_FILES_EXCEEDED   = 24
ERR_PARAM_NAME_TOO_LONG  = 25
ERR_LINE_NOT_FOUND       = 26
ERR_NO_ORIGIN            = 27
ERR_BRANCH_OUT_OF_RANGE  = 28
ERR_FILE_NOT_FOUND       = 29
ERR_UNKNOWN_SEGMENT      = 30
ERR_PC_TARGET_UNWRITABLE = 31
ERR_CANNOT_REDUCE        = 32

;******************************************************************************
; file i/o errors
ERR_TOO_MANY_OPEN_FILES   = 33
ERR_LOGICAL_FILE_IN_USE   = 34
ERR_DRIVE_DID_NOT_RESPOND = 35
ERR_FILE_TOO_BIG          = 36

;******************************************************************************
ERR_UNNAMED_BUFFER   = 37
ERR_TOO_MANY_BUFFERS = 38
ERR_NO_FILENAME      = 39
ERR_NO_OPEN_SCOPE    = 40

ERR_LABEL_ALREADY_DEFINED = 41
ERR_TOO_MANY_LABELS       = 42
ERR_LABEL_NOT_KNOWN_PASS1 = 43

ERR_INVALID_COMMAND = 44

ERR_COPY_TOO_BIG = 45

ERR_BUFFER_NAME_EXISTS   = 46
ERR_BUFFER_FULL          = 47

;******************************************************************************
; linker errors
ERR_TOO_MANY_GLOBAL_REFS = 48
ERR_TOO_MANY_SEGMENTS    = 49
ERR_SECTION_TOO_SMALL    = 50
ERR_ADDRMODE_MISMATCH    = 52
ERR_ALREADY_EXPORTED     = 53

;******************************************************************************
; general errors
ERR_OOM                  = 54
ERR_CTX_FULL             = 55
ERR_NO_MATCHING_SCOPE    = 56

.import __err_get

.scope err
	get = __err_get
.endscope

;******************************************************************************
; RETURN_ERR
; Executes an RTS after loading .A with the given code and setting the carry flag
; - .C - set
; - .A - the error code
;
.macro RETURN_ERR code
	lda #code
	sec
	rts
.endmacro

;******************************************************************************
; RETURN_OK
; Clears the carry and returns (RTS)
.macro RETURN_OK
	clc
	rts
.endmacro
