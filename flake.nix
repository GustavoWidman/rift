{
  description = "rift - a tiling window manager for macOS that focuses on performance and usability";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
  };

  outputs =
    inputs@{
      flake-parts,
      devshell,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
      ];
      imports = [
        devshell.flakeModule
        (import ./nix/package.nix inputs)
        (import ./nix/checks.nix inputs)
        ./nix/module.nix
      ];
      perSystem =
        { ... }:
        {
          devshells.default = {
            motd = "";
          };
        };
    }
    // {
      overlays.default = import ./nix/overlay.nix inputs;
    };
}
