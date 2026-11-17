# Normal NixOS module that accepts self alongside standard module arguments
{
  self,
  config,
  ...
}:
{
  _fromSelfMod = self;
}
