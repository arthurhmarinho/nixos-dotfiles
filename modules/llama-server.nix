{ lib, pkgs, ... }:

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

      # unsloth/Qwen3.5-9B-MTP-GGUF (5,87 GB): mesmos pesos + cabeça MTP
      # (multi-token prediction) para decodificação especulativa. Sem mmproj.
      model = "${modelsDir}/Qwen3.5-9B-MTP-Q4_K_M.gguf";
      alias = "qwen3.5-9b";                           # id retornado em /v1/models (OpenClaw usa)

      # Medido na RX 580 (prompt 7k, resposta de código 400 tok):
      #   sem MTP 15,7 tok/s · draft 2: 19,3 (+23%, 91% aceitos) · 3: 17,9 · 6: 15,1
      #   custo: prefill 130 → 122 tok/s. Saída idêntica em distribuição (o modelo
      #   principal confere cada token do rascunho).
      spec-type = "draft-mtp";
      spec-draft-n-max = 2;

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

  # Não sobe no boot: segura ~6,5 GB de VRAM. Iniciar à mão:
  #   sudo systemctl start llama-cpp   (e `stop` antes de jogar)
  systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];

  # Com ProtectHome/DynamicUser o Mesa não acha um ~/.cache gravável e desliga
  # o cache de shaders (recompila tudo a cada start). Usa o CacheDirectory do módulo.
  systemd.services.llama-cpp.environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp/mesa";

  # Diretório dos modelos: meu usuário baixa, o serviço (DynamicUser) só lê
  systemd.tmpfiles.rules = [ "d ${modelsDir} 0755 arthur users -" ];
}
