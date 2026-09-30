#!/usr/bin/env bash
# Instala/atualiza o OpenClaw via npm em ~/.local (Node vem de modules/openclaw.nix).
# Versão fixa no canal extended-stable; para mudar, edite OPENCLAW_VERSION e rode de novo.
# Revisado: scripts preinstall (checa Node) e postinstall (limpa o próprio dist) — sem rede.
set -euo pipefail

OPENCLAW_VERSION="2026.8.33"

# --allow-scripts: só os scripts de ciclo de vida do próprio openclaw rodam;
# os das dependências ficam bloqueados (política de scripts do npm 11).
npm install -g "openclaw@${OPENCLAW_VERSION}" \
  --prefix "$HOME/.local" \
  --allow-scripts=openclaw

"$HOME/.local/bin/openclaw" --version
