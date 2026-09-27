{ config, lib, pkgs, variables, ... }:

{
  home.username = "${variables.username}";
  home.homeDirectory = "/home/${variables.username}";

  home.stateVersion = "25.11";
}
