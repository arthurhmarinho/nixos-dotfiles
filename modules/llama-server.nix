{ pkgs, ... }:

# llama-server (llama.cpp) com Vulkan: API compatível com OpenAI só em loopback.
# Opções: nixos/modules/services/misc/llama-cpp.nix — cada chave de `settings`
# vira uma flag `--chave valor` do llama-server (ver `llama-server --help`).
let
  # Fora do /nix/store (arquivos grandes, baixados à mão). O serviço roda com
  # ProtectHome=true, por isso não pode ficar em ~.
  modelsDir = "/var/lib/llama-models";
in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;                  # llama-cpp.override { vulkanSupport = true; }
    openFirewall = false;

    settings = {
      host = "127.0.0.1";
      port = 8080;

      # unsloth/Qwen3.5-9B-GGUF (5,68 GB); sem mmproj (visão), não precisamos
      model = "${modelsDir}/Qwen3.5-9B-Q4_K_M.gguf";
      alias = "qwen3.5-9b";                           # id retornado em /v1/models

      ctx-size = 32768;
      n-gpu-layers = "all";                           # todas as camadas na RX 580
      parallel = 1;                                   # 1 slot = o agente usa os 32k inteiros
      jinja = true;                                   # template do GGUF → tool calling (já é o padrão; explícito)

      # Recomendação do model card para thinking mode em código
      temp = 0.6;
      top-p = 0.95;
      top-k = 20;
      min-p = 0.0;
    };
  };

  # Diretório dos modelos: meu usuário baixa, o serviço (DynamicUser) só lê
  systemd.tmpfiles.rules = [ "d ${modelsDir} 0755 arthur users -" ];
}
