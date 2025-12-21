.import select_bank_symbols
.import select_bank_debuginfo
.import select_bank_debuginfo
.import select_bank_copybuff
.import select_bank_macro

.import __screen_crowslo
.import __screen_crowshi
.import __screen_rowslo
.import __screen_rowshi
.import __c64_dbg

.include "bsp.inc"
.include "debug.inc"

.scope c64
	rowslo = __screen_rowslo
	rowshi = __screen_rowshi
	crowslo = __screen_crowslo
	crowshi = __screen_crowshi

	dbg    = __c64_dbg
.endscope

.macro OSPROC fn
.proc fn
.endmacro

.macro ENDOSPROC fn
.endproc
.endmacro

.macro SELECT_BANK bank
.if .match ("SYMBOLS", bank)
	jsr select_bank_symbols
.elseif .match("DEBUGINFO", bank)
	jsr select_bank_debuginfo
.elseif .match("LINKER", bank)
	jsr select_bank_linker
.elseif .match("COPYBUFF", bank)
	jsr select_bank_copybuff
.elseif .match("MACRO", bank)
	jsr select_bank_macro
.endif
.endmacro
