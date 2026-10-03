#!/bin/sh
# Menu de Configurações no fuzzel (botão 󰒓 da barra e Super+,)
wallpaper="$HOME/.config/sway/scripts/wallpaper.sh"
modefile="$HOME/.local/share/wallpaper/mode"

menu() {  # menu PROMPT LINHAS < opções
  fuzzel --dmenu --prompt "$1" --lines "$2" --width 36
}

if [ "$(cat "$modefile" 2>/dev/null || echo auto)" = fixo ]; then
  tema="󰏘  Tema: vermelho fixo  →  usar cores do wallpaper"
else
  tema="󰏘  Tema: cores do wallpaper  →  usar vermelho fixo"
fi

choice=$(printf '%s\n' \
  "󰸉  Escolher wallpaper" \
  "$tema" \
  "󰑓  Wallpaper padrão" \
  "󰕾  Áudio" \
  "󰈀  Rede" \
  "󰌌  Atalhos do teclado" \
  "󰜉  Recarregar Sway" \
  | menu "󰒓  Configurações  " 7) || exit 0

case "$choice" in
  *"Escolher wallpaper"*) mkdir -p "$HOME/Pictures/Wallpapers"; waypaper & ;;
  *"usar cores do wallpaper"*) "$wallpaper" mode auto ;;
  *"usar vermelho fixo"*)      "$wallpaper" mode fixo ;;
  *"Wallpaper padrão"*)   "$wallpaper" default ;;
  *Áudio*)     pavucontrol & ;;
  *Rede*)      alacritty -e nmtui & ;;
  *Atalhos*)   "$HOME/.config/sway/scripts/keybinds.sh" ;;
  *Recarregar*) swaymsg reload >/dev/null ;;
esac
