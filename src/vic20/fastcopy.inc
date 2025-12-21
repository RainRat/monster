.import __fastcopy_save_prog_state
.import __fastcopy_save_debug_state
.import __fastcopy_restore_debug_state
.import __fastcopy_restore_prog_state
.import __fastcopy_restore_prog_visual

.scope fcpy
	restore_debug_state = __fastcopy_restore_debug_state
	restore_progstate   = __fastcopy_restore_prog_state
	save_debug_state    = __fastcopy_save_debug_state
	save_prog_state     = __fastcopy_save_prog_state
	restore_prog_visual = __fastcopy_restore_prog_visual
.endscope
