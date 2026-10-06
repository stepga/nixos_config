{ ... }:

{
  imports = [
    # shared settings for all hosts
    ../../common/home/common.nix
  ];

  home.stateVersion = "25.11";
}
