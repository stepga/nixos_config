{ config, lib, pkgs, variables, ... }:

{
  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # hosts with a statically configured network set this to false
  networking.networkmanager.enable = lib.mkDefault true; # XOR wpa_supplicant via networking.wireless.enable = true;

  time.timeZone = "Europe/Berlin";

  services.openssh.enable = true;

  # needed for packages like `unrar`
  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${variables.username}" = {
    createHome = true;
    group = "users";
    home = "/home/${variables.username}";
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.zsh;
    extraGroups = lib.mkDefault [ "wheel" ];
  };
}
