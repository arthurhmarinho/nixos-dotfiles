{ pkgs, ... }:

# OpenClaw (agente self-hosted). O pacote do nixpkgs está atrasado (Node 22,
# abaixo do mínimo atual) e o caminho Nix oficial exige home-manager, então:
#   - Node vem do Nix (declarativo, aqui);
#   - o OpenClaw vem do npm, versão fixa, em ~/.local (ver scripts/openclaw-install.sh);
#   - o Gateway roda como serviço de usuário gerado por `openclaw gateway install`.
# Docs: https://docs.openclaw.ai/install · Node exigido: 24.16+ ou 26.1+
{
  environment.systemPackages = with pkgs; [
    nodejs_24                                         # node + npm
  ];

  # `npm install -g --prefix ~/.local` coloca o binário em ~/.local/bin
  environment.localBinInPath = true;

  # Repos do GitHub visíveis dentro do workspace do agente (~/projetos).
  # tools.fs.workspaceOnly bloqueia symlinks que saem do workspace
  # ("Symlink escapes sandbox root"); um bind mount é uma pasta real lá dentro.
  # Mesmos arquivos, sem cópia: editar em um lugar = editar no outro.
  fileSystems."/home/arthur/projetos/GitHub" = {
    device = "/home/arthur/GitHub";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };
}
