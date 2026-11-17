# Tests for lib export
let
  prelude = import ./prelude.nix;
  inherit (prelude) fixtures;
  inherit (builtins) pathExists;

  scanLib =
    src:
    let
      p = src + "/lib/default.nix";
    in
    if pathExists p then p else null;

  importLib =
    libPath: args:
    if libPath == null then
      { }
    else
      let
        mod = import libPath;
      in
      if builtins.isFunction mod then mod args else mod;
in
{
  testLibPresent = {
    expr = (scanLib (fixtures + "/full")) != null;
    expected = true;
  };

  testLibImport = {
    expr =
      let
        libPath = scanLib (fixtures + "/full");
        lib = importLib libPath {
          flake = null;
          inputs = { };
        };
      in
      lib.greet "world";
    expected = "Hello, world!";
  };

  testNoLib = {
    expr = scanLib (fixtures + "/empty");
    expected = null;
  };

  testPlainLib = {
    expr =
      let
        libPath = scanLib (fixtures + "/plain-lib");
        lib = importLib libPath { };
      in
      lib.add 1 2;
    expected = 3;
  };

  testMkPerSystem = {
    expr =
      let
        internal = import ../lib/internal.nix;
        res = internal.mkPerSystem {
          system = "x86_64-linux";
          inputs = {
            nixpkgs.legacyPackages.x86_64-linux.hello = "hello-legacy";
            nixpkgs.packages.x86_64-linux.hello = "hello-pkg";
            nonAttr = "raw-value";
          };
        };
      in
      {
        hello = res.nixpkgs.hello;
        inherit (res) nonAttr;
      };
    expected = {
      hello = "hello-pkg";
      nonAttr = "raw-value";
    };
  };
}
