.import __vic20_init

.if .defined(FE3)
.include "fe3/finalex.inc"
.elseif .defined(ULTIMEM)
.include "ultimem/ultimem.inc"
.endif

.include "debug.inc"

.scope vic20
	init = __vic20_init
.endscope

.macro OSPROC fn
.proc fn
.endmacro

.macro ENDOSPROC fn
.endproc
.endmacro
