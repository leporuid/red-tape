{ lib, ... }:
{
  options = {
    user = lib.mkOption {
      type = lib.types.str;
    };
    directory = lib.mkOption {
      type = lib.types.str;
    };
    clobberFiles = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
    files = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    xdg = {
      cache.files = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      config.files = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      data.files = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      state.files = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
  };
}
