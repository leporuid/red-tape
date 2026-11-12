# contrib/hjem.nix — Hjem and Hjem-Rum module support
# https://github.com/feel-co/hjem
# https://github.com/snugnug/hjem-rum
{
  name = "hjem";
  impl =
    { ... }:
    {
      moduleTypes = {
        hjem = "hjemModules";
        rum = "rumModules";
      };
    };
}
