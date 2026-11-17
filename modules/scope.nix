# red-tape/scope — Shared callPackage-like evaluation scope
#
# Depends on /nixpkgs (system, pkgs) and ../scan (flake context).
# Downstream per-system modules use `scope` instead of duplicating setup.
{
  name = "scope";
  inputs = {
    nixpkgs = {
      path = "/nixpkgs";
    };
    project = {
      path = "../project";
    };
  };
  impl =
    { inputs, results, ... }:
    let
      internal = import ../lib/internal.nix;
      system = inputs.nixpkgs.system;
      pkgs = inputs.nixpkgs.pkgs;
      flakeInputs = results.project.inputs;
      self = results.project.self;
    in
    {
      inherit system pkgs self;
      inputs = flakeInputs;
      scope = {
        inherit system pkgs;
        lib = pkgs.lib;
        flake = self;
        inputs = flakeInputs;
        perSystem = internal.mkPerSystem {
          inputs = flakeInputs;
          inherit system;
        };
      };
    };
}
