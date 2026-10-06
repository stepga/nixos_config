{ config, lib, pkgs, variables, ... }:

{
  services.xserver = {
    enable = true;
    enableTearFree = true;
    windowManager.i3.enable = true;
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "altgr-intl";
  services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Detect network printers supporting IPP Everywhere (UDP 5353)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  # RealtimeKit hands out realtime scheduling priority to user processes on
  # demand (e.g. to PulseAudio & Pipewire)
  security.rtkit.enable = true;

  # Enable touchpad support (enabled default in most desktop managers)
  services.libinput.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "suspend";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = false;
      };
    };
  };
  services.blueman.enable = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    powerline-fonts
  ];

  environment.variables = {
    "TERMINAL" = "kitty"; # needed for i3-sensible-terminal
  };

  environment.systemPackages = with pkgs; [
    fritzing
    musescore

    typescript-language-server

    actual-server

    (pkgs.callPackage ../../scripts/clip/derivation.nix {}) # depends on: xclip, imagemagick
    (pkgs.callPackage ../../scripts/termspawn/derivation.nix {})
  ];

  # Create a dedicated user and group for Actual Budget
  users.users.actual = {
    isSystemUser = true;
    group = "actual";
    home = "/var/lib/actual";
    createHome = true;
  };
  users.groups.actual = { };

  # Run the actual server as a systemd service
  systemd.services.actual = {
    description = "Actual Budget Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "actual";
      Group = "actual";
      WorkingDirectory = "/var/lib/actual";
      ExecStart = "${pkgs.actual-server}/bin/actual-server";
      Restart = "always";
    };
  };

  documentation.dev.enable = true;

  programs.ausweisapp = {
    enable = true;
    openFirewall = true;
  };

  # XXX: install via home manager led to
  # $ pass foobar
  #  gpg: public key decryption failed: No pinentry
  #  gpg: decryption failed: No pinentry
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # enable pam support for i3lock; https://github.com/NixOS/nixpkgs/issues/401891
  security.pam.services.i3lock.enable = true;
}
