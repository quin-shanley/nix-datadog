{
  description = "A very basic flake";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
  {
    packages = utils.lib.eachDefaultSystemMap (
      system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        default = pkgs.callPackage ./datadog.nix {
          python = pkgs.python3;
        };
      });

    overlays.default = import ./overlay.nix;

    nixosModules = {
      default = import ./module.nix;
    };
  };
}
