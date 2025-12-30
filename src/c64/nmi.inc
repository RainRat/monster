.ifndef C64_NMI_INC
C64_NMI_INC = 1

.import __nmi_disable
.import __nmi_enable

.scope nmi
	enable  = __nmi_enable
	disable = __nmi_disable
.endscope

.endif
