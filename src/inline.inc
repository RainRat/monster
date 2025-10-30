.import __inline_setup
.import __inline_setup_done
.import __inline_getarg_b
.import __inline_getarg_w
.import __inline_getarg_zp_ind
.import __inline_getarg_zp_ind_off

.scope inline
	setup             = __inline_setup
	setup_done        = __inline_setup_done
	getarg_b          = __inline_getarg_b
	getarg_w          = __inline_getarg_w
	getarg_zp_ind     = __inline_getarg_zp_ind
	getarg_zp_ind_off = __inline_getarg_zp_ind_off
.endscope
