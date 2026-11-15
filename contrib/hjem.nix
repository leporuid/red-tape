# contrib/hjem.nix — Hjem and Hjem-Rum host + module support with Manifest v3
# https://github.com/feel-co/hjem
# https://github.com/snugnug/hjem-rum
{
  name = "hjem";
  impl =
    { ... }:
    {
      scanHostTypes = [
        {
          type = "hjem";
          file = "hjem-configuration.nix";
        }
        {
          type = "hjem";
          file = "home-configuration.nix";
        }
      ];

      hostTypes.hjem = {
        outputKey = "hjemConfigurations";
        build =
          {
            name,
            info,
            specialArgs,
            inputs,
            system,
            pkgsFor,
          }:
          let
            hjem =
              inputs.hjem or (throw "red-tape: hjem contrib needs inputs.hjem (e.g. `github:feel-co/hjem`)");

            systemFile = info.hostPath + "/system.nix";
            hostSystem = if builtins.pathExists systemFile then import systemFile else system;
            pkgs = pkgsFor hostSystem;
            lib = inputs.nixpkgs.lib or pkgs.lib;
            isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

            hjem-lib =
              if hjem ? hjem-lib then
                hjem.hjem-lib.${hostSystem} or hjem.hjem-lib.default or { }
              else
                hjem.lib or { };

            utils =
              if builtins.pathExists "${inputs.nixpkgs}/nixos/lib/utils.nix" then
                import "${inputs.nixpkgs}/nixos/lib/utils.nix" {
                  inherit lib pkgs;
                  config = {
                    systemd = {
                      globalEnvironment = { };
                      defaultPath = [ ];
                      enableStrictShellChecks = false;
                    };
                  };
                }
              else
                { };

            # Platform-specific Hjem core modules + optional ecosystem extensions
            hjemModules = lib.flatten [
              (lib.optional (builtins.pathExists "${hjem}/modules/common/user.nix") "${hjem}/modules/common/user.nix")
              (lib.optional (
                !isDarwin && builtins.pathExists "${hjem}/modules/nixos/systemd.nix"
              ) "${hjem}/modules/nixos/systemd.nix")
              (lib.optional (
                isDarwin && builtins.pathExists "${hjem}/modules/darwin/user.nix"
              ) "${hjem}/modules/darwin/user.nix")
              (lib.optional (inputs ? hjem-rum) inputs.hjem-rum.hjemModules.default)
              (lib.optional (inputs ? hjem-impure) inputs.hjem-impure.hjemModules.default)
            ];

            evalResult = lib.evalModules {
              class = "hjem";
              modules = lib.flatten [
                hjemModules
                {
                  user = lib.mkDefault name;
                  directory = lib.mkDefault (if isDarwin then "/Users/${name}" else "/home/${name}");
                  clobberFiles = lib.mkDefault true;
                }
                info.configPath
              ];
              specialArgs = specialArgs // {
                inherit pkgs hjem-lib utils;
                hostName = name;
              };
            };

            cfg = evalResult.config;

            # Synthesize Hjem Manifest v3 schema
            rawFiles = [
              (cfg.files or { })
            ]
            ++ lib.optionals (cfg ? xdg) [
              (cfg.xdg.cache.files or { })
              (cfg.xdg.config.files or { })
              (cfg.xdg.data.files or { })
              (cfg.xdg.state.files or { })
            ];

            activeFiles = lib.flatten (
              map (set: lib.filter (file: file.enable or true) (builtins.attrValues set)) rawFiles
            );

            manifest = {
              version = 3;
              files = activeFiles;
            };

            packages = cfg.packages or [ ];
          in
          {
            inherit manifest packages;
            inherit (evalResult) config options;
            build = pkgs.writeText "build.json" (
              builtins.toJSON {
                inherit manifest packages;
              }
            );
          };
      };

      moduleTypes = {
        hjem = "hjemModules";
        rum = "rumModules";
      };
    };
}
