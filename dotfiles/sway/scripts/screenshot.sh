#!/bin/sh
# Uso: screenshot.sh area|screen|window — salva em ~/Pictures/Screenshots e copia
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$1" in
  area)
    geo=$(slurp) || exit 0
    grim -g "$geo" "$file" ;;
  window)
    geo=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
    grim -g "$geo" "$file" ;;
  *)
    grim "$file" ;;
esac

wl-copy < "$file"
notify-send "Screenshot" "Salvo e copiado: $(basename "$file")"
