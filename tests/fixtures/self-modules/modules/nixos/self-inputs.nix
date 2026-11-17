# Module taking self and inputs without flake (must stay uncalled)
{
  self,
  inputs,
}:
{ ... }:
{
  _fromSelfInputs = inputs;
}
