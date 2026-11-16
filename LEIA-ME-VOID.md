# Ricing Sway (do NixOS) → Void Linux no notebook

Cópia do repositório `~/nixos-sway` do desktop (com histórico git). O que
interessa para o Void:

| Pasta/arquivo | O que é |
|---|---|
| `dotfiles/` | configs: sway, waybar, mako, fuzzel, alacritty, zathura, mpv, fish, wallust (modelos de cor), easyeffects (presets) |
| `install-dotfiles.sh` | copia os dotfiles para `~/.config` (faz backup do que existir) e gera as cores |
| `pkgs/wallpicker/wallpicker.py` | seletor de wallpapers com pré-visualização (Super+Shift+W) |
| `pkgs/mediapanel/mediapanel.py` | painel do player (clique no ícone de música da barra) |
| `assets/`, `wallpapers-extra/` | wallpaper padrão, foto do usuário e os wallpapers da pasta `~/Pictures/Wallpapers` |
| `configuration.nix`, `flake.*`, `modules/`, `pkgs/*.nix` | só do NixOS — servem de referência do que foi instalado |

Os nomes de pacotes do Void abaixo foram escritos de memória: confira cada
um com `xbps-query -Rs <nome>` antes de instalar.

## 1. Pacotes

```sh
# Base do ricing
sudo xbps-install -S sway swaybg swayidle swaylock waybar fuzzel mako \
  alacritty fish-shell starship fastfetch grim slurp wl-clipboard jq \
  playerctl pavucontrol brightnessctl libnotify polkit-gnome \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk pipewire wireplumber

# Leitor de PDF, player, equalizador
sudo xbps-install zathura zathura-pdf-mupdf mpv easyeffects

# Para o wallpicker e o mediapanel (Python + GTK3 + layer-shell)
sudo xbps-install python3-gobject python3-cairo gtk-layer-shell libplayerctl

# Fonte com os ícones da barra
sudo xbps-install nerd-fonts-ttf        # ou baixe a JetBrainsMono Nerd Font
```

- **SwayFX** (blur, sombras, cantos): veja se existe `swayfx` no Void. Sem ele,
  use o `sway` normal e **comente** no `sway/config` as linhas `corner_radius`,
  `shadows*`, `blur*`, `default_dim_inactive`, `dim_inactive_colors.*`,
  `layer_effects` e `smart_corner_radius` (o sway puro não as aceita).
- **wallust** e **autotiling-rs** provavelmente não estão nos repositórios:
  `sudo xbps-install cargo` e depois `cargo install wallust autotiling-rs`
  (ficam em `~/.cargo/bin`, que precisa estar no PATH).
- **Temas** (opcional): WhiteSur GTK, MacTahoe icons e Capitaine cursors têm
  `install.sh` nos repositórios do vinceliuice/keeferrourke no GitHub.

## 2. Programas próprios (wallpicker e mediapanel)

```sh
mkdir -p ~/.local/bin
cp pkgs/wallpicker/wallpicker.py ~/.local/bin/wallpicker
cp pkgs/mediapanel/mediapanel.py ~/.local/bin/mediapanel
chmod +x ~/.local/bin/wallpicker ~/.local/bin/mediapanel
```

Eles usam `#!/usr/bin/env python3` e o GTK do sistema; `~/.local/bin` precisa
estar no PATH (no fish: `fish_add_path ~/.local/bin`).

## 3. Ajustes obrigatórios antes de instalar (específicos do desktop/NixOS)

Edite em `dotfiles/` antes de rodar o instalador:

1. **Monitores** — `sway/config`, seção "monitores": `$main`/`$side` usam o
   serial dos dois AOC do desktop. No notebook, troque pelo nome da tela
   (`swaymsg -t get_outputs`, geralmente `eDP-1`) ou apague o bloco.
2. **Waybar só no DP-1** — `waybar/config.jsonc`: remova a linha
   `"output": "DP-1",` (ou ponha `eDP-1`).
3. **Temperaturas** — `waybar/config.jsonc`, `temperature#cpu` e
   `temperature#gpu`: os caminhos `/sys/devices/pci0000:00/...` são do
   Ryzen + RX580. No notebook, ache os certos com
   `grep . /sys/class/hwmon/*/name` (procure `k10temp`/`coretemp` e a GPU).
4. **Polkit** — `sway/config`: `exec /etc/polkit-gnome-agent` é um link do
   NixOS. No Void: `exec /usr/libexec/polkit-gnome-authentication-agent-1`.
5. **Ícones das notificações** — `mako/config`: troque
   `icon-path=/run/current-system/sw/share/icons/...` por
   `/usr/share/icons/<seu tema>` (ou apague a linha).
6. **Usuário** — vários arquivos têm `/home/arthur` fixo (`waybar/style.css`,
   `fuzzel/fuzzel.ini`, `zathura/zathurarc`, `wallust/templates/swaylock`).
   Se o usuário no Void também for `arthur`, não precisa mexer.
7. **Teclado** — `sway/config`, bloco `input type:keyboard`: está `br`
   (ABNT2). Ajuste para o teclado do notebook.
8. Linha `include /etc/sway/config.d/*` no fim do `sway/config`: existe no
   Void também; pode manter.

## 4. Instalar

```sh
cd ricing-sway-nixos
mkdir -p ~/Pictures/Wallpapers && cp wallpapers-extra/* ~/Pictures/Wallpapers/
bash install-dotfiles.sh          # rode DENTRO do Sway para já gerar as cores
```

O instalador faz backup de cada pasta de `~/.config` que substituir em
`~/.config-backup-<data>`.

## 5. Atalhos principais

| Atalho | Ação |
|---|---|
| Super+T / Super+Space | terminal / launcher |
| Super+Q | fechar janela |
| Super+, | menu de Configurações (wallpaper, tema, áudio, rede…) |
| Super+Shift+W | seletor de wallpapers (troca as cores do sistema junto) |
| Super+Shift+E | menu de energia |
| Super+Alt+L | bloquear |
| PrtSc / Ctrl+PrtSc / Alt+PrtSc | print de área / tela / janela |
| Super+Shift+/ | lista de todos os atalhos |

## O que não vem junto

Tela de login (SDDM/SilentSDDM), portal de captura de tela e pacotes do
sistema são configurados no `configuration.nix` do NixOS — no Void isso é
feito à mão (serviços do runit, `xbps-install`).
