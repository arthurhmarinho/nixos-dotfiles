#!/bin/sh
# Lista os atalhos do config no fuzzel (Super+Shift+/)
grep -E '^\s*bindsym' "$HOME/.config/sway/config" \
  | sed -E 's/^\s*bindsym (--[a-z-]+ )*//; s/\$mod/Super/g; s/\s+/ /g' \
  | fuzzel --dmenu --prompt 'Atalhos: ' --width 70 --lines 25 >/dev/null
