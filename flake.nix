{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      variables = import ./variables.nix;
      hostnames = builtins.attrNames variables.hosts;

      # per-host variable set: common defaults, merged with the passed `hostname`
      # variable and the host-specific variables within `variables.nix`
      perHostVariables = hostname:
        variables.common
        // { inherit hostname; }
        // (variables.hosts.${hostname} or { });

      mkHost = hostname:
        let
          hostVariables = perHostVariables hostname;
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/common.nix
            ./hosts/${hostname}/configuration.nix

            {
              networking.hostName = hostname;
            }

            home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = { variables = hostVariables; };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users."${hostVariables.username}" = import ./hosts/${hostname}/home.nix;
            }
          ];
          specialArgs = { variables = hostVariables; };
        };
    in
    {
      nixosConfigurations = lib.genAttrs hostnames mkHost;
    };
}
