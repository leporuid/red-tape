{
  description = "red-tape — convention-based project builder on adios-flake";

  inputs = {
    adios-flake.url = "github:Mic92/adios-flake";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { adios-flake, nixpkgs, ... }:
    let
      redTape = import ./lib { inherit adios-flake; };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      eachSystem =
        f:
        builtins.foldl' (
          acc: system:
          acc
          // {
            ${system} = f (import nixpkgs { inherit system; });
          }
        ) { } systems;
    in
    {
      inherit (redTape) modules;

      lib = {
        inherit (redTape) mkPerSystem mkHjemSpecialArgs;
      };

      mkFlake =
        args:
        redTape.mkFlake (
          args
          // {
            systems = args.systems or systems;
          }
        );

      formatter = eachSystem (pkgs: pkgs.nixfmt-tree);

      hjemSchemas = {
        hjemConfigurations = {
          version = 1;
          doc = "The `hjemConfigurations` flake output defines standalone Hjem configurations with Manifest v3.";
          inventory = output: {
            children = builtins.mapAttrs (_: cfg: {
              what = "Hjem configuration";
              evalChecks.hasManifest = cfg ? manifest && (cfg.manifest.version or null) == 3;
            }) output;
          };
        };

        hjemModules = {
          version = 1;
          doc = "The `hjemModules` flake output defines importable Hjem modules.";
          inventory = output: {
            children = builtins.mapAttrs (name: _: {
              what = "Hjem module";
              evalChecks.isValid =
                builtins.isAttrs output.${name}
                || builtins.isFunction output.${name}
                || builtins.isPath output.${name};
            }) output;
          };
        };

        rumModules = {
          version = 1;
          doc = "The `rumModules` flake output defines importable Hjem-Rum modules.";
          inventory = output: {
            children = builtins.mapAttrs (name: _: {
              what = "Hjem-Rum module";
              evalChecks.isValid =
                builtins.isAttrs output.${name}
                || builtins.isFunction output.${name}
                || builtins.isPath output.${name};
            }) output;
          };
        };
      };

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nix-unit
            pkgs.nixfmt-tree
          ];
        };
      });
    };
}
