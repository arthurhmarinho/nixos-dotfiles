{ ... }:

# Tailscale: rede privada (WireGuard) entre os meus dispositivos, para acessar
# o desktop por SSH de fora de casa. O Gateway do OpenClaw continua em loopback;
# o acesso segue sendo o mesmo túnel SSH, só que pelo IP/nome do Tailscale.
#
# Primeira vez (em casa):  sudo tailscale up     → abre link de login no navegador
# Conferir:                tailscale status · tailscale ip -4
{
  services.tailscale = {
    enable = true;
    # Não abre porta UDP no firewall: o Tailscale atravessa o NAT com conexões
    # de saída (e usa relays DERP se precisar). Mantém a regra "nenhuma porta
    # nova além da 22".
    openFirewall = false;
    # Sem subnet router / exit node: só este host na tailnet.
    useRoutingFeatures = "none";
    # Sem envio de arquivos entre dispositivos (menos superfície).
    disableTaildrop = true;
  };
}
