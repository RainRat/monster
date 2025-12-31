.ifndef VIC20_EXPANSION_INC
VIC20_EXPANSION_INC = 1

.if .defined(FE3)
	.include "fe3/finalex.inc"
.elseif .defined(ultimem)
	.include "ultimem/ultimem.inc"
.endif

.endif
