#!/bin/sh
# Wallpaper atual: ~/.local/share/wallpaper/current (fora dos dotfiles, para o
# install-dotfiles.sh não desfazer a escolha). O swaylock usa o mesmo arquivo.
#
# Uso: wallpaper.sh restore        aplica o atual (ou o padrão, se não houver)
#      wallpaper.sh set ARQUIVO    copia ARQUIVO como atual e aplica
#      wallpaper.sh default        volta ao wallpaper padrão do ricing
set -e

dir="$HOME/.local/share/wallpaper"
cur="$dir/current"
default="$HOME/.config/sway/wallpaper.png"
mkdir -p "$dir"

apply() {
  swaymsg "output * bg \"$cur\" fill #121010" >/dev/null
}

case "$1" in
  set)
    [ -f "$2" ] || { notify-send "Wallpaper" "Arquivo não encontrado: $2"; exit 1; }
    cp -f "$2" "$cur"
    apply
    notify-send -i "$cur" "Wallpaper" "Aplicado: $(basename "$2")"
    ;;
  default)
    cp -f "$default" "$cur"
    apply
    notify-send -i "$cur" "Wallpaper" "Voltou ao padrão"
    ;;
  restore|*)
    [ -f "$cur" ] || cp -f "$default" "$cur"
    apply
    ;;
esac
