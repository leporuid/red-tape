# Tests for contrib/hjem.nix and flake.hjemSchemas
{ flake }:
let
  prelude = import ./prelude.nix;
  inherit (prelude)
    discover
    builders
    fixtures
    coreHostTypes
    ;
  inherit (discover) scanDir scanSubdirs scanHosts;
  inherit (builders) buildHosts buildModules;

  hjem = (import ../contrib/hjem.nix).impl { };
  hjemHostTypes = coreHostTypes ++ hjem.scanHostTypes;
  hjemHosts = scanHosts (fixtures + "/hjem/users") hjemHostTypes;

  hjemResult = buildHosts {
    discovered = hjemHosts;
    inputs = {
      hjem = fixtures + "/hjem/mock-hjem";
      inherit (flake.inputs) nixpkgs;
    };
    extraHostTypes = hjem.hostTypes;
    defaultSystem = "x86_64-linux";
    pkgsFor = system: {
      _type = "pkgs";
      inherit system;
      inherit (flake.inputs.nixpkgs) lib;
      stdenv.hostPlatform.isDarwin = system == "aarch64-darwin" || system == "x86_64-darwin";
      writeText = name: text: {
        type = "derivation";
        inherit name text;
      };
    };
  };

  hjemModulesResult = buildModules {
    discovered = scanSubdirs (fixtures + "/hjem/modules") scanDir;
    extraModuleTypes = hjem.moduleTypes;
  };
in
{
  testHjemScanHostTypes = {
    expr = {
      alice = hjemHosts.alice.type;
      bob = hjemHosts.bob.type;
    };
    expected = {
      alice = "hjem";
      bob = "hjem";
    };
  };

  testHjemOutputKeys = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames hjemResult.hjemConfigurations);
    expected = [
      "alice"
      "bob"
    ];
  };

  testHjemDefaultUserAndDirectoryLinux = {
    expr = {
      inherit (hjemResult.hjemConfigurations.alice.config) user directory clobberFiles;
    };
    expected = {
      user = "alice";
      directory = "/home/alice";
      clobberFiles = true;
    };
  };

  testHjemSystemOverrideAndDarwinDirectory = {
    expr = {
      inherit (hjemResult.hjemConfigurations.bob.config) user directory;
    };
    expected = {
      user = "bob";
      directory = "/Users/bob";
    };
  };

  testHjemManifestV3AndBuild = {
    expr =
      let
        alice = hjemResult.hjemConfigurations.alice;
      in
      {
        version = alice.manifest.version;
        fileCount = builtins.length alice.manifest.files;
        targets = builtins.sort builtins.lessThan (map (f: f.target) alice.manifest.files);
        packages = alice.packages;
        buildType = alice.build.type;
      };
    expected = {
      version = 3;
      fileCount = 2;
      targets = [
        ".config/enabled.txt"
        "app/app.conf"
      ];
      packages = [ "pkg-alice" ];
      buildType = "derivation";
    };
  };

  testHjemModuleTypes = {
    expr = {
      hjem = builtins.attrNames hjemModulesResult.hjemModules;
      rum = builtins.attrNames hjemModulesResult.rumModules;
    };
    expected = {
      hjem = [ "base" ];
      rum = [ "fish" ];
    };
  };

  testHjemSchemasConfigurations = {
    expr =
      let
        inv = flake.hjemSchemas.hjemConfigurations.inventory {
          alice = hjemResult.hjemConfigurations.alice;
          invalid = {
            manifest.version = 2;
          };
        };
      in
      {
        aliceValid = inv.children.alice.evalChecks.hasManifest;
        invalidValid = inv.children.invalid.evalChecks.hasManifest;
      };
    expected = {
      aliceValid = true;
      invalidValid = false;
    };
  };

  testHjemSchemasModules = {
    expr =
      let
        sample = {
          validAttr = { };
          validFn = _: { };
          validPath = ./hjem.nix;
          invalidStr = "not-a-module";
        };
        hjemInv = flake.hjemSchemas.hjemModules.inventory sample;
        rumInv = flake.hjemSchemas.rumModules.inventory sample;
      in
      {
        hjemAttr = hjemInv.children.validAttr.evalChecks.isValid;
        hjemFn = hjemInv.children.validFn.evalChecks.isValid;
        hjemPath = hjemInv.children.validPath.evalChecks.isValid;
        hjemInvalid = hjemInv.children.invalidStr.evalChecks.isValid;
        rumAttr = rumInv.children.validAttr.evalChecks.isValid;
        rumInvalid = rumInv.children.invalidStr.evalChecks.isValid;
      };
    expected = {
      hjemAttr = true;
      hjemFn = true;
      hjemPath = true;
      hjemInvalid = false;
      rumAttr = true;
      rumInvalid = false;
    };
  };

  testHjemManifestFileToJson = {
    expr =
      let
        res = buildHosts {
          discovered = {
            carol = {
              type = "hjem";
              configPath = builtins.toFile "carol-hjem.nix" ''
                {
                  files."gen.conf" = {
                    target = ".config/gen.conf";
                    source = "/nix/store/mock-gen";
                    clobber = true;
                    generator = _: "ignored";
                  };
                }
              '';
              hostPath = fixtures + "/hjem/users/alice";
            };
          };
          inputs = {
            hjem = {
              outPath = fixtures + "/hjem/mock-hjem";
              lib = {
                fileToJson = f: {
                  inherit (f) target source clobber;
                };
              };
            };
            inherit (flake.inputs) nixpkgs;
          };
          extraHostTypes = hjem.hostTypes;
          defaultSystem = "x86_64-linux";
          pkgsFor = system: {
            _type = "pkgs";
            inherit system;
            inherit (flake.inputs.nixpkgs) lib;
            stdenv.hostPlatform.isDarwin = false;
            writeText = name: text: {
              type = "derivation";
              inherit name text;
            };
          };
        };
        carol = res.hjemConfigurations.carol;
      in
      {
        files = carol.manifest.files;
        hasBuildJson = builtins.stringLength carol.build.text > 0;
      };
    expected = {
      files = [
        {
          target = ".config/gen.conf";
          source = "/nix/store/mock-gen";
          clobber = true;
        }
      ];
      hasBuildJson = true;
    };
  };
}
