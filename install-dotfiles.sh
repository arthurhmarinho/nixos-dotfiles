#!/usr/bin/env bash
# Copia os dotfiles do Sway para ~/.config, fazendo backup do que já existir.
# Uso: bash install-dotfiles.sh [caminho/do/wallpaper.png]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/dotfiles"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

for app in sway waybar mako fuzzel swaylock alacritty fastfetch zathura; do
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
[ -e "$HOME/.config/starship.toml" ] && mkdir -p "$BACKUP" && cp "$HOME/.config/starship.toml" "$BACKUP/"
cp "$SRC/starship/starship.toml" "$HOME/.config/starship.toml"
echo "  ✔ starship.toml"
mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

# Wallpaper opcional
if [ $# -ge 1 ] && [ -f "$1" ]; then
  cp "$1" "$HOME/.config/sway/wallpaper.png"
  sed -i 's|^output \* bg \$bg solid_color|# output * bg $bg solid_color|; s|^# output \* bg ~/.config/sway/wallpaper.png|output * bg ~/.config/sway/wallpaper.png|' "$HOME/.config/sway/config"
  echo "  ✔ wallpaper aplicado"
fi

# Valida o config do Sway
if command -v sway >/dev/null; then
  sway --validate --config "$HOME/.config/sway/config" && echo "  ✔ config do Sway válido"
fi

echo
echo "Pronto. Dentro do Sway, recarregue com Super+Shift+C (ou faça logout/login)."
