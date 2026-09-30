{ ... }:

# Acesso remoto: SSH só com chave, para o notebook abrir túnel até o Gateway
# do OpenClaw (127.0.0.1:18789). Nada além da porta 22 é aberto por este módulo.
{
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;                              # abre só a 22/tcp

    settings = {
      PasswordAuthentication = false;                 # só chave pública
      KbdInteractiveAuthentication = false;           # sem senha via PAM/teclado
      PermitRootLogin = "no";
      AllowUsers = [ "arthur" ];
      X11Forwarding = false;
      AllowAgentForwarding = false;                   # não precisamos repassar o ssh-agent
      AllowStreamLocalForwarding = false;             # só túneis TCP (LocalForward)
    };
  };

  # Chave pública do notebook (Void). Chave pública não é segredo.
  users.users.arthur.openssh.authorizedKeys.keyFiles = [ ../keys/notebook.pub ];

  # Serviços de usuário (Gateway do OpenClaw) rodam sem sessão aberta no desktop
  users.users.arthur.linger = true;

  # Firewall: ligado (padrão do NixOS). EXCEÇÃO DOCUMENTADA à regra "só a 22":
  # programs.steam.{remotePlay,dedicatedServer}.openFirewall (configuration.nix)
  # abrem TCP 27015 27036 27037 e UDP 27015 27036 27031-27035 10400 10401.
  # Mantidas por decisão do usuário (2026-09-29).
  networking.firewall.enable = true;
}
