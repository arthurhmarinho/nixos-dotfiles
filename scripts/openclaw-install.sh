#!/usr/bin/env bash
# Instala/atualiza o OpenClaw via npm em ~/.local (Node vem de modules/openclaw.nix).
# Versão fixa no canal extended-stable; para mudar, edite OPENCLAW_VERSION e rode de novo.
# Revisado: scripts preinstall (checa Node) e postinstall (limpa o próprio dist) — sem rede.
#
# Rode de novo também depois de um nixos-rebuild que atualize o Node: a unit do
# Gateway grava o caminho do node no /nix/store, que o GC apaga após 14 dias.
set -euo pipefail

OPENCLAW_VERSION="2026.8.33"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

# --allow-scripts: só os scripts de ciclo de vida do próprio openclaw rodam;
# os das dependências ficam bloqueados (política de scripts do npm 11).
# koffi e tree-sitter-bash carregam dos prebuilds mesmo assim (testado).
npm install -g "openclaw@${OPENCLAW_VERSION}" \
  --prefix "$HOME/.local" \
  --allow-scripts=openclaw

OC="$HOME/.local/bin/openclaw"
"$OC" --version

# Ajustes de config versionados (provider llama-local, aprovações de exec etc.)
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  "$OC" config patch --file "$REPO/openclaw/openclaw.patch.json5"
fi

# (Re)gera a unit de usuário do Gateway apontando para o node atual
"$OC" gateway install --force --port 18789
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
cp "$HOME/.config/systemd/user/openclaw-gateway.service" "$REPO/openclaw/openclaw-gateway.service"
