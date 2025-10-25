.import __vic20_init

.include "finalex.inc"

.scope vic20
	init = __vic20_init
.endscope

.macro OSPROC fn
.proc fn
.endmacro

.macro ENDOSPROC fn
.endproc
.endmacro
