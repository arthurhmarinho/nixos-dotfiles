# Ícones MacTahoe (estilo macOS Tahoe) — não existe no nixpkgs.
# Upstream: https://github.com/vinceliuice/MacTahoe-icon-theme
# themeVariants: default blue purple green red orange yellow grey nord all
{ lib, stdenvNoCC, fetchFromGitHub, gtk3, hicolor-icon-theme
, themeVariants ? [ "red" ] }:

stdenvNoCC.mkDerivation {
  pname = "mactahoe-icon-theme";
  version = "2026-09-10";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-icon-theme";
    rev = "2026-09-10";
    hash = "sha256-NAahlBOYub0QlqkYStamoCbyWh+H5JG/iFm4Ws9EU3A=";
  };

  nativeBuildInputs = [ gtk3 ];                     # gtk-update-icon-cache
  propagatedBuildInputs = [ hicolor-icon-theme ];

  dontBuild = true;
  dontDropIconThemeCache = true;
  dontPatchELF = true;
  dontRewriteSymlinks = true;

  postPatch = "patchShebangs install.sh";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    ./install.sh --dest $out/share/icons --name MacTahoe \
      ${lib.concatMapStringsSep " " (t: "--theme ${t}") themeVariants}
    runHook postInstall
  '';

  meta = {
    description = "MacOS Tahoe style icon theme for linux desktops";
    homepage = "https://github.com/vinceliuice/MacTahoe-icon-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
