# Tests for host building
let
  prelude = import ./prelude.nix;
  inherit (prelude)
    discover
    builders
    fixtures
    coreHostTypes
    ;
  inherit (discover) scanHosts;
  inherit (builders) buildHosts;

  fullHosts = scanHosts (fixtures + "/full/hosts") coreHostTypes;

  testResult = buildHosts {
    discovered = { inherit (fullHosts) custom; };
  };

  homeManager = (import ../contrib/home-manager.nix).impl { };
  homeHostTypes = coreHostTypes ++ homeManager.scanHostTypes;
  homeHosts = scanHosts (fixtures + "/home/hosts") homeHostTypes;

  homeResult = buildHosts {
    discovered = homeHosts;
    inputs = {
      home-manager = {
        lib.homeManagerConfiguration =
          args:
          args
          // {
            activationPackage = {
              type = "derivation";
              name = "home-activation-${args.pkgs.system}";
            };
          };
      };
    };
    extraHostTypes = homeManager.hostTypes;
    defaultSystem = "x86_64-linux";
  };

  darwin = (import ../contrib/darwin.nix).impl { };
  darwinHostTypes = coreHostTypes ++ darwin.scanHostTypes;
  darwinHosts = scanHosts (fixtures + "/darwin/hosts") darwinHostTypes;
  darwinResult = buildHosts {
    discovered = darwinHosts;
    inputs = {
      nix-darwin.lib.darwinSystem = args: {
        inherit args;
        config = {
          nixpkgs.hostPlatform.system = "aarch64-darwin";
          system.build.toplevel = "drv-darwin-toplevel";
        };
      };
    };
    extraHostTypes = darwin.hostTypes;
    defaultSystem = "aarch64-darwin";
  };

  systemManager = (import ../contrib/system-manager.nix).impl { };
  smHostTypes = coreHostTypes ++ systemManager.scanHostTypes;
  smHosts = scanHosts (fixtures + "/system-manager/hosts") smHostTypes;
  smResult = buildHosts {
    discovered = smHosts;
    inputs = {
      system-manager.lib.makeSystemConfig = args: {
        inherit args;
        config = {
          nixpkgs.hostPlatform.system = "aarch64-linux";
          build.toplevel = "drv-sm-toplevel";
        };
      };
    };
    extraHostTypes = systemManager.hostTypes;
    defaultSystem = "aarch64-linux";
  };

  autoChecksMixedResult = buildHosts {
    discovered = {
      linuxHost = {
        type = "nixos";
        configPath = fixtures + "/full/hosts/myhost/configuration.nix";
      };
      armHost = {
        type = "nixos";
        configPath = fixtures + "/full/hosts/db/configuration.nix";
      };
      hmMatch = {
        type = "home-manager";
        configPath = fixtures + "/home/hosts/alice/home-configuration.nix";
        hostPath = fixtures + "/home/hosts/alice";
      };
      hmOther = {
        type = "home-manager";
        configPath = fixtures + "/home/hosts/bob/home-configuration.nix";
        hostPath = fixtures + "/home/hosts/bob";
      };
      hjemUser = {
        type = "hjem";
        configPath = fixtures + "/hjem/users/alice/hjem-configuration.nix";
        hostPath = fixtures + "/hjem/users/alice";
      };
    };
    inputs = {
      nixpkgs = {
        lib.nixosSystem =
          { specialArgs, ... }:
          let
            isArm = specialArgs.hostName == "armHost";
          in
          {
            config = {
              nixpkgs.hostPlatform.system = if isArm then "aarch64-linux" else "x86_64-linux";
              system.build.toplevel = "drv-${specialArgs.hostName}";
            };
          };
      };
      home-manager.lib.homeManagerConfiguration =
        args:
        args
        // {
          activationPackage = "drv-hm-${args.extraSpecialArgs.hostName}";
        };
    };
    extraHostTypes = homeManager.hostTypes // {
      hjem = {
        outputKey = "hjemConfigurations";
        getSystem = _: null;
        getCheckTarget = _: null;
        build =
          { ... }:
          {
            manifest.version = 3;
            packages = [ ];
            config = { };
            options = { };
            build = "drv-hjem-build-json";
          };
      };
    };
    defaultSystem = "x86_64-linux";
  };
in
{
  testCustomHostLoaded = {
    expr = testResult.nixosConfigurations.custom.value._type;
    expected = "test-nixos-system";
  };

  testCustomHostName = {
    expr = testResult.nixosConfigurations.custom.value.hostName;
    expected = "custom";
  };

  testEmptyHosts = {
    expr =
      let
        result = buildHosts { discovered = { }; };
      in
      {
        hasAutoChecks = builtins.isFunction result.autoChecks;
        noOutputKeys = builtins.attrNames (builtins.removeAttrs result [ "autoChecks" ]);
      };
    expected = {
      hasAutoChecks = true;
      noOutputKeys = [ ];
    };
  };

  testHostDiscoveryTypes = {
    expr =
      let
        hosts = scanHosts (fixtures + "/full/hosts") coreHostTypes;
      in
      {
        myhost = hosts.myhost.type;
        custom = hosts.custom.type;
      };
    expected = {
      myhost = "nixos";
      custom = "custom";
    };
  };

  testHomeConfigurationGetsDefaultPkgs = {
    expr = homeResult.homeConfigurations.alice.pkgs.system;
    expected = "x86_64-linux";
  };

  testHomeConfigurationSystemOverride = {
    expr = homeResult.homeConfigurations.bob.pkgs.system;
    expected = "aarch64-darwin";
  };

  testHomeConfigurationOutputKey = {
    expr = builtins.attrNames homeResult.homeConfigurations;
    expected = [
      "alice"
      "bob"
    ];
  };

  testDarwinHostLoaded = {
    expr = {
      type = darwinHosts.macbook.type;
      hasOutput = darwinResult.darwinConfigurations ? macbook;
      hostName = darwinResult.darwinConfigurations.macbook.args.specialArgs.hostName;
      moduleCount = builtins.length darwinResult.darwinConfigurations.macbook.args.modules;
      moduleType = darwin.moduleTypes.darwin;
      check = (darwinResult.autoChecks "aarch64-darwin")."darwin-macbook";
    };
    expected = {
      type = "darwin";
      hasOutput = true;
      hostName = "macbook";
      moduleCount = 1;
      moduleType = "darwinModules";
      check = "drv-darwin-toplevel";
    };
  };

  testDarwinMissingInputThrows = {
    expr =
      (builtins.tryEval (
        (buildHosts {
          discovered = darwinHosts;
          inputs = { };
          extraHostTypes = darwin.hostTypes;
          defaultSystem = "aarch64-darwin";
        }).darwinConfigurations.macbook
      )).success;
    expected = false;
  };

  testSystemManagerHostLoaded = {
    expr = {
      type = smHosts.edge.type;
      hasOutput = smResult.systemConfigs ? edge;
      hostName = smResult.systemConfigs.edge.args.specialArgs.hostName;
      moduleCount = builtins.length smResult.systemConfigs.edge.args.modules;
      check = (smResult.autoChecks "aarch64-linux")."system-manager-edge";
    };
    expected = {
      type = "system-manager";
      hasOutput = true;
      hostName = "edge";
      moduleCount = 1;
      check = "drv-sm-toplevel";
    };
  };

  testSystemManagerMissingInputThrows = {
    expr =
      (builtins.tryEval (
        (buildHosts {
          discovered = smHosts;
          inputs = { };
          extraHostTypes = systemManager.hostTypes;
          defaultSystem = "aarch64-linux";
        }).systemConfigs.edge
      )).success;
    expected = false;
  };

  testAutoChecksHeterogeneousHosts = {
    expr = {
      x86Checks = autoChecksMixedResult.autoChecks "x86_64-linux";
      darwinChecks = autoChecksMixedResult.autoChecks "aarch64-darwin";
    };
    expected = {
      x86Checks = {
        "home-manager-hmMatch" = "drv-hm-hmMatch";
        "nixos-linuxHost" = "drv-linuxHost";
      };
      darwinChecks = {
        "home-manager-hmOther" = "drv-hm-hmOther";
      };
    };
  };
}
