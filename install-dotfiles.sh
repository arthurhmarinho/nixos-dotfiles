#!/usr/bin/env bash
# Copia os dotfiles do Sway para ~/.config, fazendo backup do que já existir.
# Uso: bash install-dotfiles.sh [caminho/do/wallpaper.png]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/dotfiles"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# swaylock, starship e fastfetch não estão aqui: são gerados pelo wallust
for app in sway waybar mako fuzzel alacritty zathura wallust mpv; do
  if [ -e "$HOME/.config/$app" ]; then
    mkdir -p "$BACKUP"
    mv "$HOME/.config/$app" "$BACKUP/"
    echo "  backup: ~/.config/$app -> $BACKUP/$app"
  fi
  cp -r "$SRC/$app" "$HOME/.config/$app"
  echo "  ✔ $app"
done

chmod +x "$HOME/.config/sway/scripts/"*.sh "$HOME/.config/waybar/scripts/"*.sh

# Arquivos avulsos (sem substituir a pasta inteira: o fish guarda histórico/variáveis lá)
mkdir -p "$HOME/.config/fish"
for f in fish/config.fish; do
  [ -e "$HOME/.config/$f" ] && mkdir -p "$BACKUP/$(dirname "$f")" && cp "$HOME/.config/$f" "$BACKUP/$f"
  cp "$SRC/$f" "$HOME/.config/$f"
  echo "  ✔ $f"
done
mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers" "$HOME/Videos/Gravações"

# Wallpaper opcional: vai para ~/Pictures/Wallpapers e é aplicado no fim
if [ $# -ge 1 ] && [ -f "$1" ]; then
  cp "$1" "$HOME/Pictures/Wallpapers/"
  NEW_WALL="$HOME/Pictures/Wallpapers/$(basename "$1")"
fi

# Valida o config do Sway
if command -v sway >/dev/null; then
  sway --validate --config "$HOME/.config/sway/config" && echo "  ✔ config do Sway válido"
fi


# Tema dinâmico: gera as cores (wallust) do wallpaper atual ou do novo
mkdir -p "$HOME/.config/fastfetch"
if command -v wallust >/dev/null && [ -n "${SWAYSOCK:-}" ]; then
  if [ -n "${NEW_WALL:-}" ]; then
    "$HOME/.config/sway/scripts/wallpaper.sh" set "$NEW_WALL"
  else
    "$HOME/.config/sway/scripts/wallpaper.sh" retheme
  fi
  echo "  ✔ cores geradas a partir do wallpaper"
else
  echo "  ! wallust ausente ou fora do Sway: as cores serão geradas no próximo login"
fi

echo
echo "Pronto. Dentro do Sway, recarregue com Super+Shift+C (ou faça logout/login)."
