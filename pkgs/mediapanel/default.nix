# mediapanel: painel do player com volume por app e presets de equalizador (ver mediapanel.py)
{ lib, stdenvNoCC, python3, gtk3, gtk-layer-shell, gobject-introspection
, wrapGAppsHook3, playerctl, pipewire, wireplumber, easyeffects }:

let
  py = python3.withPackages (p: [ p.pygobject3 p.pycairo ]);
in
stdenvNoCC.mkDerivation {
  pname = "mediapanel";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ wrapGAppsHook3 gobject-introspection ];
  buildInputs = [ gtk3 gtk-layer-shell playerctl ];   # playerctl: typelib Playerctl-2.0

  # pw-dump (pipewire), wpctl (wireplumber) e easyeffects no PATH do painel
  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ pipewire wireplumber easyeffects ]})
  '';

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 mediapanel.py $out/bin/mediapanel
    substituteInPlace $out/bin/mediapanel \
      --replace-fail "#!/usr/bin/env python3" "#!${py}/bin/python3"
    runHook postInstall
  '';

  meta = {
    description = "Painel do player (MPRIS) com volume por app e equalizador (Sway/layer-shell)";
    platforms = lib.platforms.linux;
    mainProgram = "mediapanel";
  };
}
