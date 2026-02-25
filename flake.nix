{
  description = "Nix binary cache implemented in rust using libnix-store";

  inputs.nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixpkgs-unstable";

  inputs.flake-parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "nixpkgs";
  };
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.crate2nix = {
    url = "github:Mic92/crate2nix/json-output";
    flake = false;
  };
  inputs.nix = {
    url = "github:nixos/nix";
    # We just need some test data, we're not building upstream nix.
    flake = false;
  };
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        inputs.treefmt-nix.flakeModule
        ./herculesCI.nix
      ];
      perSystem =
        {
          lib,
          pkgs,
          self',
          ...
        }:
        let
          packageSet = pkgs.callPackages ./packages.nix {
            crate2nix = inputs.crate2nix;
            nix-src = inputs.nix;
          };
        in
        {
          packages = {
            inherit (packageSet)
              default
              harmonia
              ;
            # Benchmark closure - a decent-sized Python environment for download benchmarks
            bench-closure = pkgs.python3.withPackages (
              ps: with ps; [
                numpy
                pandas
                requests
              ]
            );
          };
          checks =
            let
              testArgs = {
                inherit pkgs;
                inherit (inputs) self;
              };
              packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
              devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
            in
             lib.optionalAttrs pkgs.stdenv.isLinux {
              nix-daemon = import ./tests/nix-daemon.nix testArgs;
              harmonia-daemon = import ./tests/harmonia-daemon.nix testArgs;
              chroot-store = import ./tests/chroot-store.nix testArgs;
            }
            // packages
            // devShells;
          devShells.default = pkgs.callPackage ./devShell.nix {
            nix-src = inputs.nix;
          };

          treefmt = {
            # Used to find the project root
            projectRootFile = "flake.lock";

            programs.rustfmt = {
              enable = true;
              edition = "2024";
            };
            programs.nixfmt.enable = true;
            programs.deadnix.enable = true;
            programs.clang-format.enable = true;
          };
        };
      flake.nixosModules.harmonia =
        { lib, ... }:
        {
          imports = [
            (lib.modules.importApply ./module.nix {
              crate2nix = inputs.crate2nix;
              nix-src = inputs.nix;
            })
          ];
        };
    };
}
