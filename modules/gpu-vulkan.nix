{ pkgs, ... }:

# GPU AMD RX 580 (Polaris, gfx803) via Mesa.
# O ROCm não suporta mais a Polaris, então computação (IA local) usa Vulkan
# pelo driver RADV do Mesa — que já vem com hardware.graphics, sem AMDVLK.
{
  hardware.amdgpu.initrd.enable = true;               # carrega o amdgpu cedo no boot

  hardware.graphics = {
    enable = true;
    enable32Bit = true;                               # necessário para Steam/Wine
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools                                      # vulkaninfo, para validar a GPU
  ];
}
