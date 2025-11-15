.seg "code"
.export foo

foo	lda #$00
	sta $900f
	rts

