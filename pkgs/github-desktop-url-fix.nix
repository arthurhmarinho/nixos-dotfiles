# GitHub Desktop com correção do login pelo navegador no Linux.
#
# Problema: o pacote do nixpkgs é compilado do repositório oficial
# (desktop/desktop), que não trata links x-github-* no Linux. O Firefox abre
# `github-desktop x-github-desktop-dev-auth://oauth?code=…`, a instância
# aberta recebe os argumentos no evento "second-instance", mas a função que
# os processa (minificada como `Rt`) só entende --cli-open/--cli-clone; o
# tratamento de links só existe no evento "open-url", que é exclusivo do macOS.
#
# Correção: em vez de recompilar o app, copia só o main.js, injeta uma linha
# que reenvia os links x-github-* para o evento "open-url" e liga o resto dos
# arquivos originais por symlink. Se uma nova versão mudar o código
# minificado, o --replace-fail quebra o build (em vez de falhar em silêncio).
{ lib, runCommand, makeWrapper, electron, github-desktop }:

let
  gd = github-desktop;
  origApp = "${gd}/share/github-desktop/resources/app";
in
runCommand "github-desktop-${gd.version}" {
  nativeBuildInputs = [ makeWrapper ];
  inherit (gd) meta;
} ''
  app=$out/share/github-desktop/resources/app
  mkdir -p $app $out/bin $out/share

  for f in ${origApp}/* ${origApp}/.[!.]*; do
    [ -e "$f" ] && ln -s "$f" "$app/"
  done

  rm $app/main.js
  cp ${origApp}/main.js $app/main.js
  chmod u+w $app/main.js
  substituteInPlace $app/main.js --replace-fail \
    'async function Rt(e){' \
    'async function Rt(e){for(const u of e)if(/^x-github-(client|desktop-(dev-)?auth):/i.test(u))n.app.emit("open-url",{preventDefault(){}},u);'

  ln -s ${gd}/share/applications $out/share/applications
  ln -s ${gd}/share/icons $out/share/icons

  makeWrapper ${lib.getExe electron} $out/bin/github-desktop \
    --add-flag $app \
    --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
    --inherit-argv0
''
