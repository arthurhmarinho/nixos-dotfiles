#!/bin/sh
# Menu de energia no fuzzel (botão ⏻ da barra e Super+Shift+E)
choice=$(printf '%s\n' \
  "󰌾  Bloquear" \
  "󰍃  Sair do Sway" \
  "󰤄  Suspender" \
  "󰜉  Reiniciar" \
  "󰐥  Desligar" \
  | fuzzel --dmenu --prompt '⏻  ' --lines 5 --width 22)

case "$choice" in
  *Bloquear*)  swaylock -f ;;
  *Sair*)      swaymsg exit ;;
  *Suspender*) swaylock -f && systemctl suspend ;;
  *Reiniciar*) systemctl reboot ;;
  *Desligar*)  systemctl poweroff ;;
esac
