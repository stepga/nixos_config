{ pkgs, variables, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # blacklist internal microphone
  boot.blacklistedKernelModules = [ "snd_soc_dmic" ];

  # We deal with an LUKS encrypted partition
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  systemd.services.disable-sound-leds = rec {
    # $ man 7 systemd.special:
    # [...]
    # This target is started automatically as soon as a sound card is plugged in or becomes available at boot.
    wantedBy = [ "sound.target" ];
    after = wantedBy;
    serviceConfig.Type = "oneshot";
    script = ''
      echo off > /sys/class/sound/ctl-led/mic/mode
      echo off > /sys/class/sound/ctl-led/speaker/mode # follow-route pending https://discourse.nixos.org/t/20480
      '';
  };

  systemd.services.reenable-connected-internal-display = {
    description = "Re-enabling a disabled internal display if needed.";
    wantedBy = [ "sleep.target" ];
    after = [ "sleep.target" ];

    # do not rely on the binaries being in PATH
    path = with pkgs; [
      xrandr
      coreutils
      gnugrep
    ];

    serviceConfig = {
      Type = "oneshot";
      User = variables.username;
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=/home/${variables.username}/.Xauthority"
      ];
    };

    script = ''#!/usr/bin/env bash
      set -eu

      OK=0
      for i in $(seq 1 20); do
        echo "... waiting for XServer $i/20"
        if xrandr --query >/dev/null 2>&1; then
          OK=1
          break
        fi
        sleep 0.2
      done

      if [ "$OK" -eq 0 ]; then
        echo "xrandr failed ultimatively"
        exit 1
      fi

      CONNECTED=$(xrandr --query | grep -w "connected" | wc -l)
      echo "amount of connected displays: $CONNECTED"

      if [ "$CONNECTED" -eq 1 ]; then
        # only one display is connected, on a notebook this must be the internal one.
        # `xrandr --auto` re-enables it, preventing a disabled black screen on resume.
        xrandr --auto --verbose
      fi
    '';
  };

  networking.hostName = "${variables.hostname}";
  networking.networkmanager.enable = true; # XOR wpa_supplicant via networking.wireless.enable = true;

  time.timeZone = "Europe/Berlin";

  services.openssh.enable = true;

  services.xserver = {
    enable = true;
    enableTearFree = true;
    videoDrivers = [ "amdgpu" ];
    windowManager.i3.enable = true;
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "altgr-intl";
  services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # detect network printers supporting IPP Everywhere (UDP 5353)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable sound.
  #hardware.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    # XXX >>> might help with sound on older hardware during high load
    #alsa.enable = true;
    #alsa.support32Bit = true;
    # XXX <<<
  };
  # RealtimeKit hands out realtime scheduling priority to user processes on
  # demand (e.g. to PulseAudio & Pipewire)
  security.rtkit.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "suspend";
  };

  services.upower = {
    enable = true;
    percentageCritical = 18; # default 5
    criticalPowerAction = "Hibernate";
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${variables.username}" = {
    createHome = true;
    extraGroups = [ "wheel" "video" "audio" "disk" "networkmanager" ];
    group = "users";
    home = "/home/${variables.username}";
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.zsh;
  };

  fonts.packages = with pkgs; [
    font-awesome
    dejavu_fonts
    powerline-fonts
    powerline-symbols
  ];

  environment.variables = {
    "TERMINAL" = "kitty"; # needed for i3-sensible-terminal
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # XXX: kept in systemPackages as these packages are used within systemd.services scripts
  environment.systemPackages = with pkgs; [
    gnugrep
    xrandr
    coreutils-full

    (callPackage ./scripts/clip/derivation.nix {}) # depends on: xclip, imagemagick
    (callPackage ./scripts/termspawn/derivation.nix {})

    fritzing
    musescore

    typescript-language-server

    actual-server
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

  programs.zsh.enable = true;

  programs.ausweisapp = {
    enable = true;
    openFirewall = true;
  };

  # needed for packages like `unrar`
  nixpkgs.config.allowUnfree = true;

  # FIXME: install via home manager led to
  # $ pass foobar
  #  gpg: public key decryption failed: No pinentry
  #  gpg: decryption failed: No pinentry
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # enable pam support for i3lock; https://github.com/NixOS/nixpkgs/issues/401891
  security.pam.services.i3lock.enable = true;

  # For more information, see `man configuration.nix`
  system.stateVersion = "24.11";
}
