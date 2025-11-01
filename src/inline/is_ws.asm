;*******************************************************************************
; IS WS
; Checks if the given character is a whitespace character
; IN:
;  - .A: the character to test
; OUT:
;  - .Z: set if if the character in .A is whitespace
	cmp #$0d	; newline
	beq :+
	cmp #$09	; TAB
	beq :+
	cmp #$0a	; UNIX newline
	beq :+
	cmp #' '
:	rts
