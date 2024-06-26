.import __str_cat
.import __str_compare
.import __str_comparez
.import __str_copy
.import __str_len
.import __str_toupper
.import __str_uncompress

.scope str
	cat        = __str_cat
	compare    = __str_compare
	comparez   = __str_comparez
	copy       = __str_copy
	len        = __str_len
	toupper    = __str_toupper
	uncompress = __str_uncompress
.endscope

;******************************************************************************
; STREQ
; Compares the string in (YX) to the string s.
.macro streq s, len
	stx zp::str0
	sty zp::str0+1

	lda #<s
	sta zp::str2
	lda #>s
	sta zp::str2+1
	lda #len
	jsr __str_compare
.endmacro

;******************************************************************************
; REPLACE
; 'replace' the string in .XY with replacewith
.macro strep replace, replacewith
	lda replace
	sta zp::str0
	lda replace+1
	sta zp::str0+1
	lda replacewith
	sta zp::str2
	lda replacewith+1
	sta zp::str2+1
	jsr __str_replace
.endmacro
