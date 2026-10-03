#!/bin/sh
# Menu de Configurações no fuzzel (botão 󰒓 da barra e Super+,)
walls="$HOME/Pictures/Wallpapers"
wallpaper="$HOME/.config/sway/scripts/wallpaper.sh"

menu() {  # menu PROMPT LINHAS < opções
  fuzzel --dmenu --prompt "$1" --lines "$2" --width 34
}

pick_wallpaper() {
  mkdir -p "$walls"
  files=$(find "$walls" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            -printf '%f\n' | sort)
  n=$(printf '%s\n' "$files" | grep -c . || true)

  choice=$( { printf '%s\n' "$files" | grep . | sed 's/^/󰸉  /'
              printf '%s\n' "󰉋  Abrir pasta de wallpapers" "󰑓  Wallpaper padrão"; } \
            | menu "󰸉  Wallpaper  " $(( n + 2 > 12 ? 12 : n + 2 )) ) || exit 0

  case "$choice" in
    *"Abrir pasta"*)     nautilus "$walls" & ;;
    *"Wallpaper padrão"*) "$wallpaper" default ;;
    *)                   "$wallpaper" set "$walls/${choice#󰸉  }" ;;
  esac
}

choice=$(printf '%s\n' \
  "󰸉  Wallpaper" \
  "󰕾  Áudio" \
  "󰈀  Rede" \
  "󰌌  Atalhos do teclado" \
  "󰑓  Recarregar Sway" \
  | menu "󰒓  Configurações  " 5) || exit 0

case "$choice" in
  *Wallpaper*) pick_wallpaper ;;
  *Áudio*)     pavucontrol & ;;
  *Rede*)      alacritty -e nmtui & ;;
  *Atalhos*)   "$HOME/.config/sway/scripts/keybinds.sh" ;;
  *Recarregar*) swaymsg reload >/dev/null ;;
esac
