#!/bin/sh
# Wallpaper + tema dinâmico.
#
# O wallpaper atual fica em ~/.local/share/wallpaper/current (fora dos
# dotfiles, para o install-dotfiles.sh não desfazer a escolha). As cores saem
# dele pelo wallust (modo "auto") ou da paleta vermelha fixa (modo "fixo"); os
# arquivos gerados vão para ~/.cache/wallust e são incluídos pelos configs.
# A tela de login (SDDM) recebe uma cópia em /var/lib/sddm-wallpaper.
#
# Uso: wallpaper.sh set ARQUIVO   aplica ARQUIVO como wallpaper (e as cores)
#      wallpaper.sh default       volta ao wallpaper padrão do ricing
#      wallpaper.sh mode auto|fixo  cores do wallpaper ou vermelho fixo
#      wallpaper.sh retheme       regenera as cores do wallpaper atual
#      wallpaper.sh restore       aplica o atual (no login / reload do Sway)
set -e

dir="$HOME/.local/share/wallpaper"
cur="$dir/current"
modefile="$dir/mode"
default="$HOME/.config/sway/wallpaper.png"
fixed="$HOME/.config/wallust/fixed-red.json"
cache="$HOME/.cache/wallust"
mkdir -p "$dir" "$cache"

mode() { cat "$modefile" 2>/dev/null || echo auto; }

# Escolhe o destaque entre as cores vivas da paleta (color9..14): a de maior
# saturação com luminosidade média (nem pastel, nem escura), e a realça um pouco.
pick_accent() {
  jq -r '.colors | [.color9,.color10,.color11,.color12,.color13,.color14][]' "$1" | awk '
    function hex(s) { return strtonum("0x" s) / 255 }
    function abs(x) { return x < 0 ? -x : x }
    function hue2rgb(p, q, t) {
      if (t < 0) t += 1; if (t > 1) t -= 1
      if (t < 1/6) return p + (q - p) * 6 * t
      if (t < 1/2) return q
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
      return p
    }
    {
      h = substr($1, 2); r = hex(substr(h,1,2)); g = hex(substr(h,3,2)); b = hex(substr(h,5,2))
      mx = r; if (g > mx) mx = g; if (b > mx) mx = b
      mn = r; if (g < mn) mn = g; if (b < mn) mn = b
      l = (mx + mn) / 2; d = mx - mn
      s = (d == 0) ? 0 : d / (1 - abs(2*l - 1))
      if (d == 0) hu = 0
      else if (mx == r) hu = ((g - b) / d) % 6
      else if (mx == g) hu = (b - r) / d + 2
      else hu = (r - g) / d + 4
      hu = hu / 6; if (hu < 0) hu += 1
      score = (l >= 0.40 && l <= 0.68) ? s : s * 0.4
      if (score > best) { best = score; bh = hu; bs = s; bl = l }
    }
    END {
      s = bs * 1.3 + 0.05; if (s > 0.85) s = 0.85          # mais vivo, sem estourar
      if (bl < 0.50) bl = 0.50; if (bl > 0.62) bl = 0.62   # legível sobre fundo escuro
      q = bl < 0.5 ? bl * (1 + s) : bl + s - bl * s; p = 2 * bl - q
      printf "#%02X%02X%02X\n", hue2rgb(p,q,bh+1/3)*255, hue2rgb(p,q,bh)*255, hue2rgb(p,q,bh-1/3)*255
    }'
}

theme() {
  if [ "$(mode)" = fixo ]; then
    wallust cs -q -s "$fixed"
  else
    # 1) paleta da imagem  2) destaque escolhido vira color1  3) aplica tudo
    wallust run -q -s "$cur" || { wallust cs -q -s "$fixed"; return; }
    acc=$(pick_accent "$cache/colors.json")
    jq --arg a "$acc" '.colors.color1 = $a | .colors.color9 = $a' \
      "$cache/colors.json" > "$cache/palette.json"
    wallust cs -q -s "$cache/palette.json"
  fi
}

reload_all() {
  swaymsg reload >/dev/null                                # bordas (inclui ~/.cache/wallust/sway)
  pkill -USR2 -x .waybar-wrapped 2>/dev/null || pkill -USR2 -x waybar 2>/dev/null || true
  makoctl reload 2>/dev/null || true
  # Alacritty relê o arquivo importado sozinho; fuzzel/swaylock/zathura/starship/
  # fastfetch/fish usam as cores novas ao abrir.
}

# Tela de login (SDDM): copia o wallpaper para a pasta que o SDDM lê
# (/var/lib/sddm-wallpaper, criada pelo configuration.nix). Grava num
# temporário e renomeia, para o SDDM nunca ler um arquivo pela metade.
sync_sddm() {
  d=/var/lib/sddm-wallpaper
  [ -d "$d" ] && [ -w "$d" ] || return 0
  cmp -s "$cur" "$d/wallpaper" && return 0
  cp -f "$cur" "$d/.wallpaper.tmp" && chmod 644 "$d/.wallpaper.tmp" && mv -f "$d/.wallpaper.tmp" "$d/wallpaper"
}

apply_bg() {
  bg=$(jq -r '.special.background' "$cache/colors.json" 2>/dev/null || echo "#121010")
  swaymsg "output * bg \"$cur\" fill $bg" >/dev/null
}

case "$1" in
  set)
    [ -f "$2" ] || { notify-send "Wallpaper" "Arquivo não encontrado: $2"; exit 1; }
    cp -f "$2" "$cur"
    theme; apply_bg; reload_all; sync_sddm
    notify-send -i "$cur" "Wallpaper" "Aplicado: $(basename "$2")"
    ;;
  default)
    cp -f "$default" "$cur"
    theme; apply_bg; reload_all; sync_sddm
    notify-send -i "$cur" "Wallpaper" "Voltou ao padrão"
    ;;
  mode)
    case "$2" in auto|fixo) echo "$2" > "$modefile" ;; *) echo "uso: $0 mode auto|fixo"; exit 1 ;; esac
    theme; apply_bg; reload_all; sync_sddm
    [ "$2" = auto ] && msg="Cores tiradas do wallpaper" || msg="Tema vermelho fixo"
    notify-send -i "$cur" "Tema" "$msg"
    ;;
  retheme)
    [ -f "$cur" ] || cp -f "$default" "$cur"
    theme; apply_bg; reload_all; sync_sddm
    ;;
  restore|*)
    # Chamado pelo exec_always do Sway (também a cada reload): só aplica o fundo;
    # gera as cores apenas se ainda não existirem (primeiro login).
    [ -f "$cur" ] || cp -f "$default" "$cur"
    if [ ! -f "$cache/sway" ]; then theme; apply_bg; reload_all; else apply_bg; fi
    sync_sddm
    ;;
esac
