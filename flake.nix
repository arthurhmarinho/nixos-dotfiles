{
  description = "NixOS do Arthur — desktop (Sway + SilentSDDM)";

  inputs = {
    # nixos-unstable: pacotes mais novos. Para algo mais estável, use um canal
    # de release, ex: "github:NixOS/nixpkgs/nixos-26.05"
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # "nixos" precisa bater com networking.hostName
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
