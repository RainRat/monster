.ifndef VIC20_EXPANSION_INC
VIC20_EXPANSION_INC = 1

.if .defined(fe3)
	.include "fe3/banks.inc"
	.include "fe3/finalex.inc"
.elseif .defined(ultimem)
	.include "ultimem/banks.inc"
	.include "ultimem/ultimem.inc"
.endif

.endif
