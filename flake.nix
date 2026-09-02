# flake.nix
{
  description = "ADMIXTOOLS (qpAdm, qpGraph, qpDstat, f-stats) packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true; # lets `nix build` work despite the unfree tag
            };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, system }:
        {
          admixtools = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.admixtools;
        }
      );

      # Downstream configs use this so they get pkgs.admixtools built against
      # THEIR nixpkgs, not a second copy pinned here.
      overlays.default = final: _prev: {
        admixtools = final.callPackage ./package.nix { };
      };

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            inputsFrom = [ (pkgs.callPackage ./package.nix { }) ];
          };
        }
      );
    };
}
