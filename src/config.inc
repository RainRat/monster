;******************************************************************************
; PREFERENCES/COLORS
TEXT_COLOR	 = $06	      		; text color for the editor
BORDER_COLOR	 = $03|$08     		; border color for the editor
BG_COLOR	 = $01	      		; bg color for the editor

DEFAULT_900F     = (BG_COLOR<<4 | BORDER_COLOR)
DEFAULT_RVS      = DEFAULT_900F^$08

; colors for breakpoints that are enabled and disabled
BREAKPOINT_ON_COLOR  = ($09<<4 | BORDER_COLOR)
BREAKPOINT_OFF_COLOR = ($0e<<4 | BORDER_COLOR)

ERROR_COLOR	 = ($00|$08) 		; $900f color of error highlight
DEBUG_LINE_COLOR = ($70|BORDER_COLOR)	; row cursor color during debug

ASM_SUCCESS_COLOR = ($0d<<4 | BORDER_COLOR)      ; color for asm done message

DEBUG_REG_CHANGED_COLOR = 2  ; color for register that was changed during STEP

CUR_BLINK_SPEED = 250	; number of updates before blink

;******************************************************************************
; SOURCE FORMATTING
TAB_WIDTH = 10

;******************************************************************************
LINESIZE = 40	; the size of the buffer for 1 line on the screen

;******************************************************************************
; BEEP SETTINGS
BEEP_TONE           = $e4
BEEP_ERR_TONE       = $a4
BEEP_VOL            = $0c
SHORT_BEEP_DURATION = 10
LONG_BEEP_DURATION  = 30
