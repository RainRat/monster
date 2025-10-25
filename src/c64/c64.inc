.import __screen_rowslo
.import __screen_rowshi

.scope c64
	rowslo = __screen_rowslo
	rowshi = __screen_rowshi
.endscope

.macro OSPROC fn
.proc fn
.endmacro

.macro ENDOSPROC fn
.endproc
.endmacro
