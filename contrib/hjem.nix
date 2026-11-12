# contrib/hjem.nix — Hjem module support
# https://github.com/feel-co/hjem
{
  name = "hjem";
  impl =
    { ... }:
    {
      moduleTypes = {
        hjem = "hjemModules";
      };
    };
}
