;*******************************************************************************
; CTX.ASM
; This file contains the code for interacting with the assembly "context"
; The "context" is a special buffer used by the .MAC and .REP directives to
; store lines of data, which is required to complete the assembly of these
; directives when their corresponding .ENDMAC or .ENDREP directive is found.
;*******************************************************************************

.include "config.inc"
.include "errors.inc"
.include "macros.inc"
.include "memory.inc"
.include "util.inc"
.include "zeropage.inc"

;*******************************************************************************
; CONSTANTS
CONTEXT_SIZE = $200	; size of buffer per context
PARAM_LENGTH = 16	; size of param (stored after the context data)
MAX_PARAMS   = 4	; max params for a context
MAX_CONTEXTS = 3	; $1000-$400 / $200

SIZEOF_CTX_HEADER = 11

;*******************************************************************************
; CONTEXTS
; Contexts are stored in spare mem, which is unused by the assembler during the
; assembly of a program.
; The number of contexts is limited by the size of a context (defined as
; CONTEXT_SIZE).
.export contexts
contexts     = mem::spare
contexts_top = mem::spareend

.assert $ff & contexts = 0, error, "contexts must be page-aligned"

;*******************************************************************************
.segment "BSS_NOINIT"

;*******************************************************************************
; ACTIVE
; !0: a context is active
.export __ctx_active
__ctx_active:
activectx: .byte 0

;*******************************************************************************
; OPEN
; !0: current context is "closed" (ctx::end was called)
.export __ctx_open
__ctx_open: .byte 0

ctx       = zp::ctx+0	; address of context

;*******************************************************************************
; CTX META
meta      = zp::ctx+2
iter      = meta+0	; (REP) iterator's current value (set externally)
iterend   = meta+2	; (REP) iterator's end value (set externally)
cur       = meta+4	; cursor to current ctx data
params    = meta+6	; address of params (grows down from CONTEXT+$200-PARAM_LENGTH)
numparams = meta+8	; the number of parameters for the context
type      = meta+9	; the type of the context
numlines  = meta+10	; number of lines in the context

parent    = meta+11	; address of parent context's line buffer

.CODE
;*******************************************************************************
; INIT
; initializes the context state by clearing the stack
.export  __ctx_init
.proc __ctx_init
	; init ctx pointer to base of contexts - CONTEXT_SIZE
	lda #<(contexts-CONTEXT_SIZE+2)
	sta ctx
	lda #>(contexts-CONTEXT_SIZE+2)
	sta ctx+1

	lda #$00
	sta activectx	; set activectx id to base (0)
	sta __ctx_open	; no context open

	rts
.endproc

;*******************************************************************************
; PUSH
; Saves the current context and beings a new one
; OUT:
; - .C: set if there is no room to create a new context
.export __ctx_push
.proc __ctx_push
	pha			; save the context type

	lda activectx
	beq @init		; no active context -> continue
	cmp #MAX_CONTEXTS+1
	bcc @save

@err:	;sec
	pla			; clean stack
	lda #ERR_STACK_OVERFLOW	; too many contexts
	rts

@save:	; set current context's cursor as new one's parent
	lda cur
	sta parent
	lda cur+1
	sta parent+1

	; save the active context's state
	ldy #SIZEOF_CTX_HEADER-1
@l0:	lda meta,y
	sta (ctx),y
	dey
	bpl @l0

@init:	inc activectx
	inc __ctx_open		; flag that a context is now open

	; move ctx pointer to next context space
	lda ctx
	clc
	adc #<CONTEXT_SIZE
	lda ctx+1
	adc #>CONTEXT_SIZE
	sta ctx+1

	; initialize metadata (numparams, line count, buffer)
	lda #$00
	sta numparams
	sta numlines
	sta mem::ctxbuffer

	pla			; get context type
	sta type

	; fall through to __ctx_rewind to initialize cur pointer
.endproc

;*******************************************************************************
; REWIND
; Rewinds the context so that the cursor points to the beginning of its line
; data
.export  __ctx_rewind
.proc __ctx_rewind
	jsr __ctx_getdata	; get base address of context lines
	stxy cur		; reset cursor to it

	; init param buffer to end of ctx buffer (grows downward)
	txa
	clc
	adc #<(CONTEXT_SIZE-SIZEOF_CTX_HEADER-PARAM_LENGTH)
	sta params
	tya
	adc #>(CONTEXT_SIZE-SIZEOF_CTX_HEADER-PARAM_LENGTH)
	sta params+1

	rts
.endproc

;*******************************************************************************
; POP
; Restores the last PUSH'ed context
; OUT:
;  -.C: set if there are no contexts to pop
.export __ctx_pop
.proc __ctx_pop
	lda activectx
	bne :+
	RETURN_ERR ERR_STACK_UNDERFLOW

:	lda ctx
	sec
	sbc #<CONTEXT_SIZE
	sta ctx
	lda ctx+1
	sbc #>CONTEXT_SIZE
	sta ctx+1

	; restore the ctx metadata (iter, iterend, cur, param, etc.)
	ldy #SIZEOF_CTX_HEADER-1
@l0:	lda (ctx),y
	sta meta,y
	dey
	bpl @l0

	; if we modified this context (the previous one's parent), update the
	; cursor with the modified value
	lda parent
	sta cur
	lda parent+1
	sta cur+1

	lda #$01
	sta __ctx_open	; mark context as open (again)

	dec activectx
@done:	RETURN_OK
.endproc

;*******************************************************************************
; GETLINE
; Returns a line from the active context.
; OUT:
;  - .XY: the address of the line returned
;  - .A: the # of bytes read (0 if EOF)
;  - .Z: set if EOF (0 bytes read)
;  - .C: set on error
;  - mem::ctxbuffer: the line read from the context
.export __ctx_getline
.proc __ctx_getline
@out=mem::ctxbuffer
	; read until a newline or EOF
	ldy #$00
	lda (cur),y
	beq @ok		; if line is empty -> we're done

@read:	lda (cur),y
	sta @out,y
	beq @done
	iny
	cpy #LINESIZE
	bcc @read
	RETURN_ERR ERR_LINE_TOO_LONG

@done:	iny
	tya
	clc
	adc cur
	sta cur
	bcc :+
	inc cur+1
:	ldxy #@out
	tya		; restore # of bytes read
@ok:	RETURN_OK
.endproc

;*******************************************************************************
; GETPARAMS
; returns a list of the parameters for the active context
; IN:
;  - .XY: address of buffer to store params in
; OUT:
;  - .A: the number of parameters
;  - (.XY): the updated buffer filled with 0-separated params
.export __ctx_getparams
.proc __ctx_getparams
@buff=r0
@cnt=r2
@params=r3
	stxy @buff
	ldx numparams
	beq @done
	stx @cnt

	lda params
	sta @params
	lda params+1
	sta @params+1

@l0:	ldy #$00
@l1:	lda (@params),y
	sta (@buff),y
	beq @next
	iny
	cpy #PARAM_LENGTH
	bcc @l1
	RETURN_ERR ERR_PARAM_NAME_TOO_LONG

@next:	; @buff += .Y+1
	tya
	sec		; +1
	adc @buff
	sta @buff
	bcc :+
	inc @buff+1

:	; @params -= PARAM_LENGTH
	lda @params
	sec
	sbc #PARAM_LENGTH
	sta @params
	bcs :+
	dec @params+1
:	dec @cnt
	bne @l0

@done:	lda numparams
	RETURN_OK
.endproc

;*******************************************************************************
; GETDATA
; returns the address of the data for the active context.
; OUT:
;  - .XY: the address of the data for the current context
.export __ctx_getdata
.proc __ctx_getdata
	lda ctx
	clc
	adc #SIZEOF_CTX_HEADER
	tax
	lda ctx+1
	adc #$00
	tay
	rts
.endproc

;*******************************************************************************
; WRITE PARENT
; Writes the given line to parent of the current context's line buffer
; Comments are ignored to save space in the context buffer.
; IN:
;  - .XY: the line to write to the active context
; OUT:
;  - .XY: the address of the active context.
;  - .C:  set on error
.export __ctx_write_parent
.proc __ctx_write_parent
@line=r0
	stxy @line
	ldy #$00
	lda (@line),y
	beq @ok		; don't store empty lines

@write: lda (@line),y
	beq @done
	cmp #$0d
	beq @done
	cmp #';'
	beq @done
	sta (parent),y

	incw @line
	incw parent
	bne @write

	; TODO: make sure ctx isn't full
	;sec
	;lda #ERR_CTX_FULL
	;rts

@err:	; sec
	lda #ERR_LINE_TOO_LONG
	rts

@done:	lda #$00
	sta (parent),y	; terminate this line in the buffer
	incw parent

@ok:	inc numlines
	RETURN_OK
.endproc

;*******************************************************************************
; WRITE
; Writes the given line to the context at its current position
; Comments are ignored to save space in the context buffer.
; IN:
;  - .XY: the line to write to the active context
; OUT:
;  - .XY: the address of the active context.
;  - .C:  set on error
.export __ctx_write
.proc __ctx_write
@line=r0
	stxy @line
	ldy #$00
	lda (@line),y
	beq @ok		; don't store empty lines

@write: lda (@line),y
	beq @done
	cmp #$0d
	beq @done
	cmp #';'
	beq @done
	sta (cur),y

	incw @line

	; increment context pointer and make sure the context isn't full
	incw cur
	lda cur+1
	cmp #>contexts_top
	bcc @write
	lda cur
	cmp #<contexts_top
	bne @write

	;sec
	lda #ERR_CTX_FULL
	rts

@err:	; sec
	lda #ERR_LINE_TOO_LONG
	rts

@done:	lda #$00
	sta (cur),y	; terminate this line in the buffer
	incw cur

@ok:	inc numlines
	RETURN_OK
.endproc

;*******************************************************************************
; END
; Closes the active context by writing a terminating 0 to its line data
; and decrementing the activectx value.
; Calling this tells the assembler to, for example, begin emitting assembly
; instead of storing lines to the context.
; This is called before the corresponding ctx::pop, which will completely
; deactivate the context.
; IN:
;   - .A: the type of context we're closing
; OUT:
;   - .C: set on error
.export __ctx_end
.proc __ctx_end
	; make sure the open context type matches the type we're closing
	cmp type
	beq :+
	RETURN_ERR ERR_NO_MATCHING_SCOPE ; if scope types mismatch, return err

:	; write a terminating 0 to the context's buffer
	ldy #$00
	tya
	sta (cur),y
	sta __ctx_open	; mark context as closed
	RETURN_OK
.endproc

;*******************************************************************************
; ADDPARAM
; Adds the given parameter to the active context
; IN:
;  - .XY: the 0, whitepace, or ',' terminated parameter to add to the active
;  context
; OUT:
;  - .XY: the rest of the string after the parameter that was extracted
.export __ctx_addparam
.proc __ctx_addparam
@param=r0
	stxy @param

	ldy #$00
@copy:  lda (@param),y
	sta (params),y
	beq @done
	cmp #','
	beq @done
	jsr util::is_whitespace
	beq @done
	iny
	cpy #PARAM_LENGTH
	bne @copy
	RETURN_ERR ERR_LINE_TOO_LONG

@done:	inc numparams
	lda #$00
	sta (params),y	; 0-terminate

	; move pointer to next open param
	; params -= PARAM_LENGTH
	lda params
	sec
	sbc #PARAM_LENGTH
	sta params
	bcs :+
	dec params+1

:	; get addr of rest of string for caller
	tya
	clc
	adc @param
	tax
	lda @param+1
	adc #$00
	tay
	RETURN_OK
.endproc

;*******************************************************************************
; NUMLINES
; Returns the length (in lines) of the context
; OUT:
;  - .A: the number of lines in the context
.export __ctx_numlines
.proc __ctx_numlines
	lda numlines
	rts
.endproc
