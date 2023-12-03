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
        sha256 = "629daa38f3ea67f29610bfbd53f9f38f46834d3654451e9474100490c66dc7e7";
      };
      version = "6.1.64";
      modDirVersion = "6.1.64";
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

  fileSystems."/usb" = {
    device = "/dev/disk/by-uuid/b985e946-77ea-4beb-9fb6-55e3066b4ebe";
    fsType = "ext4";
    # make a mount of the external usb drive asynchronous and non-critical
    options = [ "nofail" ];
  };
}
