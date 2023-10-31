# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

let
  secrets = import ./secrets.nix;
in
{
  imports =
    [ # Include the results of the hardware scan.
      <nixos-hardware/pcengines/apu>
      ./hardware-configuration.nix
    ];

  boot = {
    loader = {
      timeout = 2;
      grub = {
        enable = true;
        device = "/dev/sda";
      };
    };
  };

  networking = {
    hostName = "apu2d4";
    domain = "network"; # "networking.fqdn: ${networking.hostName}.${networking.domain}"
    wireless = {
      enable = true;  # Enables wireless support via wpa_supplicant.
    };
    firewall = {
      enable = false;
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."feni" = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [ ];
    openssh = {
      authorizedKeys.keys = [ secrets.authorized_keys.feni ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    curl
    htop
    iw
    nix-tree  # show package dependencies
    pciutils  # lspci
    rxvt-unicode  # needed for: rxvt-unicode-unwrapped-9.31-terminfo/share/terminfo/r/rxvt-unicode
    tmux
    vim
    wget
  ];

  # List services that you want to enable:

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  system.stateVersion = "23.05";
}
