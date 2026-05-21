{
  description = "Noctalia - A lightweight Wayland shell and bar";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      wrappers,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem =
        perSystem:
        lib.genAttrs systems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          perSystem { inherit pkgs system; }
        );

      mkDate =
        longDate:
        nixpkgs.lib.concatStringsSep "-" [
          (builtins.substring 0 4 longDate)
          (builtins.substring 4 2 longDate)
          (builtins.substring 6 2 longDate)
        ];

      shortRev = self.shortRev or "dirty";
      version = mkDate (self.lastModifiedDate or "19700101") + "_" + shortRev;
    in
    {
      overlays.default = final: prev: {
        noctalia = final.callPackage ./nix/package.nix { inherit version shortRev; };
      };

      packages = forEachSystem (
        { pkgs, ... }:
        {
          default = pkgs.callPackage ./nix/package.nix { inherit version shortRev; };
        }
      );

      devShells = forEachSystem (
        { pkgs, system }:
        {
          default = pkgs.callPackage ./nix/devshell.nix {
            noctalia = self.packages.${system}.default;
          };
        }
      );

      apps = forEachSystem (
        { system, ... }:
        {
          default = {
            type = "app";
            program = lib.getExe self.packages.${system}.default;
          };
        }
      );

      homeModules.default =
        { pkgs, lib, ... }:
        {
          imports = [ ./nix/home-module.nix ];
          programs.noctalia.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      wrappers = forEachSystem (
        { pkgs, system }:
        {
          default = (wrappers.lib.evalModule ./nix/wrapper-module.nix).config.wrap {
            inherit pkgs;
            package = self.packages.${system}.default;
          };
        }
      );
    };
}
