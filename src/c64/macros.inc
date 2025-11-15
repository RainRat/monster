.macro IO_BEGIN
	php
	sei
	lda #$36	; make I/O space visible
	sta $01
.endmacro

.macro IO_DONE
	lda #$34	; make all RAM visible
	sta $01
	plp
.endmacro
