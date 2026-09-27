{
  # variables shared by all hosts
  common = {
    username = "feni";
    git = {
      user = {
        email = "stepga@nirgendwo.eu";
        name = "Stephan Gabert";
      };
    };
  };

  # per-host variables; `hostname` is injected automatically and can be overridden here
  hosts = {
    nixtop = { };
    blackbox = { };
    apu2d4 = { };
  };
}
