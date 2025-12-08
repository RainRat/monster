.import __vic20_init

.include "finalex.inc"
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

.macro SELECT_BANK bank
.endmacro
