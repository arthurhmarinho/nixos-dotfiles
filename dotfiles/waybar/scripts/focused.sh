#!/bin/sh
# Módulo da Waybar: ícone do programa em foco (abaixo dos workspaces).
# Acompanha os eventos do Sway e escolhe o ícone pelo app_id/classe e pelo
# título (ex.: terminal rodando o Claude Code, WhatsApp no Firefox).
# Saída: uma linha JSON {text, tooltip, class} só quando algo muda.

u() { printf "\\U$(printf %08X "0x$1")"; }   # ícone pelo código Unicode

focused() {
  swaymsg -t get_tree | jq -c \
    --arg claude "$(u F06A9)" --arg term "$(u F018D)" --arg firefox "$(u F0239)" \
    --arg whatsapp "$(u F05A3)" --arg youtube "$(u F05C3)" --arg spotify "$(u F04C7)" \
    --arg discord "$(u F066F)" --arg obs "$(u F0567)" --arg pdf "$(u F0226)" \
    --arg video "$(u F040A)" --arg idea "$(u F0B37)" --arg code "$(u F0169)" \
    --arg notes "$(u F082E)" --arg steam "$(u F04D3)" --arg game "$(u F02B4)" \
    --arg folder "$(u F024B)" --arg mixer "$(u F057E)" --arg office "$(u F0219)" \
    --arg cad "$(u F01A7)" --arg github "$(u F02A4)" --arg app "$(u F08C6)" '
    [.. | objects | select(.focused? == true)][0] as $f
    | if $f == null or $f.type == "workspace" or $f.type == "output" then
        {text: "", tooltip: "", class: "empty"}
      else
        (($f.app_id // $f.window_properties.class // "") | ascii_downcase) as $id
        | ($f.name // "" | sub("^[✳✻✽✶✢·◐◑◒◓⠀-⣿] "; "")) as $t0 | ($f.name // "") as $t
        | (if ($id | test("alacritty|foot|kitty|terminal")) then
             (if ($t | test("^[✳✻✽✶✢·◐◑◒◓⠀-⣿] |claude"; "i")) then [$claude, "Claude Code"]
              else [$term, "Terminal"] end)
           elif ($id | test("firefox")) then
             (if ($t | test("whatsapp"; "i")) then [$whatsapp, "WhatsApp"]
              elif ($t | test("youtube"; "i")) then [$youtube, "YouTube"]
              else [$firefox, "Firefox"] end)
           elif ($id | test("^steam_app_")) then [$game, "Jogo"]
           elif ($id | test("^steam$")) then [$steam, "Steam"]
           elif ($id | test("spotify")) then [$spotify, "Spotify"]
           elif ($id | test("discord|vesktop")) then [$discord, "Discord"]
           elif ($id | test("obs")) then [$obs, "OBS"]
           elif ($id | test("zathura")) then [$pdf, "Zathura"]
           elif ($id | test("mpv")) then [$video, "mpv"]
           elif ($id | test("jetbrains")) then [$idea, "IntelliJ IDEA"]
           elif ($id | test("zed|code")) then [$code, "Editor"]
           elif ($id | test("obsidian")) then [$notes, "Obsidian"]
           elif ($id | test("nautilus")) then [$folder, "Arquivos"]
           elif ($id | test("pavucontrol|easyeffects")) then [$mixer, "Áudio"]
           elif ($id | test("onlyoffice")) then [$office, "OnlyOffice"]
           elif ($id | test("freecad|kicad")) then [$cad, "Engenharia"]
           elif ($id | test("github")) then [$github, "GitHub Desktop"]
           elif ($id | test("lutris|bottles|gamescope")) then [$game, "Jogo"]
           else [$app, ($f.app_id // $f.window_properties.class // "Programa")] end) as $m
        | {text: $m[0], tooltip: "\($m[1])\n\($t0)", class: "app"}
      end'
}

last=""
emit() { out=$(focused); [ "$out" != "$last" ] && { echo "$out"; last="$out"; }; }

emit
# Reavalia a cada evento de janela (foco, título) ou de workspace
swaymsg -t subscribe -m '["window","workspace"]' | while read -r _; do emit; done
