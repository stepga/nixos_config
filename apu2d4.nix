{ config, lib, pkgs, ... }:

{
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.grub.extraConfig = "
    serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
    terminal_input serial
    terminal_output serial
  ";

  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_1.override {
    argsOverride = rec {
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
        sha256 = "58520e7ae5a6af254ddf7ddbfc42e4373b0d36c67d467f6e35a3bd1672f5fb0a";
      };
      version = "6.1.60";
      modDirVersion = "6.1.60";
    };
  });

  # patch ath driver: allow setting regulatory domain
  # this will cause a kernel-recompile, use only with
  # * kernel pinning
  # * remote builder & nix-copy-closure
  networking.wireless.athUserRegulatoryDomain = true;

  # workaround for setting regdomain and driving 5ghz with ath10k card
  nixpkgs.config.allowUnfree = true;
  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
  };
}
