{ config, lib, pkgs, variables, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.loader = {
    timeout = 2;
    grub = {
      enable = true;
      device = "/dev/nvme0n1";
    };
  };

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    arp-scan
    curl
    htop
    hwinfo
    iw
    lshw
    nix-tree  # show package dependencies
    pciutils  # lspci
    rclone
    tmux
    vim
    wget
  ];

  system.stateVersion = "25.11"; # Did you read the comment?
}
