# NixOS: SwayFX + Waybar + wallust

Desktop Ryzen + RX 580 com dois monitores AOC. Sistema declarado em flake.
As cores do tema saem do wallpaper (wallust).

| Caminho | O que é |
|---|---|
| `flake.nix`, `configuration.nix`, `hardware-configuration.nix` | o sistema (host `nixos`) |
| `modules/` | GPU Vulkan, llama-server, OpenClaw, SSH, Tailscale |
| `pkgs/` | pacotes próprios: wallpicker, mediapanel, ícones MacTahoe, correção do GitHub Desktop |
| `dotfiles/` | configs: sway, waybar, mako, fuzzel, alacritty, zathura, mpv, fish, wallust, easyeffects |
| `install-dotfiles.sh` | copia `dotfiles/` para `~/.config`, com backup, e gera as cores |
| `assets/`, `wallpapers-extra/` | wallpaper padrão, avatar e os wallpapers do seletor |
| `LEIA-ME-VOID.md` | roteiro para levar este ricing ao Void Linux |

## Aplicar

```sh
sudo nixos-rebuild switch --flake .#nixos
bash install-dotfiles.sh assets/sddm-wallpaper.png
```

Monitores, temperatura da CPU/GPU na Waybar e o teclado `br` são específicos desta máquina.
O `LEIA-ME-VOID.md` lista onde cada um está.
