# wallpicker: seletor de wallpapers com pré-visualização ao vivo (ver wallpicker.py)
{ lib, stdenvNoCC, python3, gtk3, gtk-layer-shell, gobject-introspection
, wrapGAppsHook3, librsvg, webp-pixbuf-loader }:

let
  py = python3.withPackages (p: [ p.pygobject3 p.pycairo ]);
in
stdenvNoCC.mkDerivation {
  pname = "wallpicker";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ wrapGAppsHook3 gobject-introspection ];
  # librsvg/webp-pixbuf-loader: o wrapGAppsHook inclui os loaders do gdk-pixbuf
  buildInputs = [ gtk3 gtk-layer-shell librsvg webp-pixbuf-loader ];

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 wallpicker.py $out/bin/wallpicker
    substituteInPlace $out/bin/wallpicker \
      --replace-fail "#!/usr/bin/env python3" "#!${py}/bin/python3"
    runHook postInstall
  '';

  meta = {
    description = "Seletor de wallpapers com pré-visualização ao vivo (Sway/layer-shell)";
    platforms = lib.platforms.linux;
    mainProgram = "wallpicker";
  };
}
