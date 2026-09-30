{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Inclui o resultado do escaneamento de hardware (NÃO REMOVA)
      ./hardware-configuration.nix
      # Tema SilentSDDM (vem do flake.nix)
      inputs.silentSDDM.nixosModules.default
      # GPU (Mesa/RADV + Vulkan)
      ./modules/gpu-vulkan.nix
      # LLM local: llama-server (Vulkan) em 127.0.0.1:8080
      ./modules/llama-server.nix
      # Agente OpenClaw: Node 24 + ~/.local/bin no PATH
      ./modules/openclaw.nix
      # SSH só com chave (túnel do notebook) + linger
      ./modules/ssh.nix
    ];

  # --- NIX ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;          # deduplica arquivos na /nix/store
  };
  nix.gc = {                             # limpa gerações antigas toda semana
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Permite pacotes proprietários (Steam, Spotify, Discord, Obsidian...)
  nixpkgs.config.allowUnfree = true;

  # --- BOOTLOADER ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;   # só 10 gerações no menu de boot
  boot.loader.efi.canTouchEfiVariables = true;

  # --- KERNEL E HARDWARE (Ryzen + RX580) ---
  boot.kernelPackages = pkgs.linuxPackages_zen;       # baixa latência, desktop/jogos
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  # GPU e Vulkan: ver modules/gpu-vulkan.nix

  hardware.bluetooth.enable = true;

  # --- REDE E LOCALIZAÇÃO ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Fortaleza";                # mesmo fuso de Natal/RN (UTC-3)

  i18n.defaultLocale = "pt_BR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Layout do teclado: uma única fonte para console e SDDM (o Sway usa o
  # mesmo layout no seu config). O SDDM (compositor weston) e o console leem
  # services.xserver.xkb — isso NÃO liga o servidor X.
  services.xserver.xkb = {
    layout = "br";                  # br = ABNT2 (variante padrão)
    variant = "";
  };
  console.useXkbConfig = true;      # console usa o mesmo layout do xkb

  # --- INTERFACE GRÁFICA (SWAY) ---
  programs.sway = {
    enable = true;
    package = pkgs.swayfx;                            # fork do Sway: cantos, blur, sombras
    wrapperFeatures.gtk = true;                       # apps GTK com tema correto
    extraPackages = with pkgs; [
      swaylock swayidle swaybg
      waybar fuzzel mako libnotify
      grim slurp wl-clipboard jq
      brightnessctl playerctl pavucontrol
      wev                                           # mostra teclas/botões pressionados
      autotiling-rs                                 # divide janelas em espiral (dwindle)
    ];
  };

  # Tela de login: SDDM + SilentSDDM (o mesmo tema do CachyOS)
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      # Se o greeter não abrir, troque para false e adicione: services.xserver.enable = true;
    };
    defaultSession = "sway";
  };

  programs.silentSDDM = {
    enable = true;
    theme = "default";   # presets: default, rei, ken, silvia, everforest, nord, catppuccin-*

    # Mesmo wallpaper do desktop e foto do usuário (arquivos em ./assets)
    backgrounds.rubi = ./assets/sddm-wallpaper.png;
    profileIcons.arthur = ./assets/johnny-joestar.jpg;

    # Opções: https://github.com/uiriansan/SilentSDDM/wiki/Options
    settings = {
      "LockScreen"  = { background = "sddm-wallpaper.png"; };
      "LoginScreen" = { background = "sddm-wallpaper.png"; };
      "LoginScreen.LoginArea.Avatar" = {
        shape = "circle";
        active-border-size = 2;
        active-border-color = "#e0533d";
      };
      "LoginScreen.LoginArea.PasswordInput" = {
        background-color = "#121010";
        background-opacity = 0.6;
      };
      "LoginScreen.LoginArea.LoginButton" = {
        background-color = "#e0533d";
        background-opacity = 0.6;
        active-background-color = "#e0533d";
        active-background-opacity = 0.9;
      };
    };
  };

  # Portais (compartilhar tela, seletor de arquivos)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Compartilhar tela e screenshot pelo portal wlr. Não redefinir
    # config.sway.default: o módulo do Sway já o define (gtk).
    config.sway."org.freedesktop.impl.portal.ScreenCast" = "wlr";
    config.sway."org.freedesktop.impl.portal.Screenshot" = "wlr";
  };

  # Agente de polkit (pedidos de senha gráficos), iniciado pelo config do Sway
  security.polkit.enable = true;
  environment.etc."polkit-gnome-agent".source =
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";

  # Chaveiro (senhas salvas de apps como GitHub Desktop)
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Pendrives, lixeira e rede no Nautilus
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # --- SOM (PIPEWIRE) ---
  services.pulseaudio.enable = false;                 # antes: hardware.pulseaudio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- USUÁRIO ---
  programs.fish.enable = true;
  programs.starship.enable = true;

  users.users.arthur = {
    isNormalUser = true;
    description = "Arthur";
    shell = pkgs.fish;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" "gamemode" ];
  };

  # --- PERFORMANCE ---
  programs.gamemode.enable = true;
  zramSwap.enable = true;
  services.fstrim.enable = true;

  # --- JOGOS E STEAM ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  services.flatpak.enable = true;

  # --- AMBIENTE ---
  environment.sessionVariables = {
    TERMINAL = "alacritty";
    NIXOS_OZONE_WL = "1";          # apps Electron (Discord, Obsidian, Zed...) nativos em Wayland
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE = "24";
  };

  # --- TEMA (GTK, Qt, ícones, cursor) — paleta vermelha ---
  # GTK: WhiteSur escuro com destaque vermelho · Ícones: MacTahoe vermelho
  # Cursor: Capitaine. Os apps GTK no Wayland leem o dconf (não o settings.ini).
  # (os pacotes do tema estão em environment.systemPackages, seção "Tema")

  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "WhiteSur-Dark-red";
        icon-theme = "MacTahoe-red-dark";
        cursor-theme = "capitaine-cursors";
        cursor-size = pkgs.lib.gvariant.mkInt32 24;
        color-scheme = "prefer-dark";
        font-name = "Noto Sans 10";
        monospace-font-name = "JetBrainsMono Nerd Font 10";
      };
    }];
  };

  # Apps X11/Xwayland e outros toolkits
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=WhiteSur-Dark-red
    gtk-icon-theme-name=MacTahoe-red-dark
    gtk-cursor-theme-name=capitaine-cursors
    gtk-cursor-theme-size=24
    gtk-application-prefer-dark-theme=1
    gtk-font-name=Noto Sans 10
  '';

  # Qt: lê ícones/fontes/modo escuro do dconf (acima) + estilo escuro
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # Cursor no SDDM
  services.displayManager.sddm.settings.Theme = {
    CursorTheme = "capitaine-cursors";
    CursorSize = 24;
  };

  # --- FONTES ---
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  # --- PACOTES DO SISTEMA ---
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # Tema
    (whitesur-gtk-theme.override {
      colorVariants = [ "dark" ];
      themeVariants = [ "red" ];
      opacityVariants = [ "normal" ];
    })
    (callPackage ./pkgs/mactahoe-icon-theme.nix { themeVariants = [ "red" ]; })
    capitaine-cursors

    # Sistema
    vim
    wget
    curl
    git
    pciutils
    unzip
    htop
    fastfetch

    # Terminal e desenvolvimento
    alacritty
    neovim
    ripgrep
    fd
    fzf
    gcc
    gnumake
    claude-code
    zed-editor
    (callPackage ./pkgs/github-desktop-url-fix.nix { })   # corrige o login pelo navegador
    jetbrains-toolbox              # instala o IntelliJ (assinatura Ultimate)

    # Arquivos e produtividade
    nautilus
    obsidian
    onlyoffice-desktopeditors

    # Engenharia
    freecad
    kicad

    # Pessoais
    discord                        # ou vesktop (melhor compartilhamento de tela no Wayland)
    spotify

    # Jogos
    lutris
    bottles
    protonup-qt
    mangohud
    winetricks
    wowup-cf
  ];

  # NÃO altere: indica a versão em que o sistema foi instalado, não a versão atual.
  # Em instalação nova, mantenha o valor que o instalador gerou.
  system.stateVersion = "26.05";
}
