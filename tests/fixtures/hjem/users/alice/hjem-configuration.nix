{ hostName, ... }:
{
  packages = [ "pkg-${hostName}" ];
  files = {
    "enabled.txt" = {
      target = ".config/enabled.txt";
      text = "ok";
    };
    "disabled.txt" = {
      enable = false;
      target = ".config/disabled.txt";
      text = "skip";
    };
  };
  xdg.config.files."app.conf" = {
    target = "app/app.conf";
    text = "cfg";
  };
}
