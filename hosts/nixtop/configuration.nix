{ config, lib, pkgs, variables, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # shared desktop/X11 setup (window manager, sound, printing, ...)
      ../../modules/desktop.nix

      ../../modules/security-check.nix
    ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  # blacklist internal microphone
  boot.blacklistedKernelModules = [ "snd_soc_dmic" ];

  # We deal with an LUKS encrypted partition
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
    };
  };

  # >>>
  # XXX quick test server (works fine with kodi on firetvstick)
  services.samba = {
    enable = true;

    settings = {
      global = {
        workgroup = "WORKGROUP";
        "map to guest" = "Bad User";
        "guest account" = "nobody";
      };

      public = {
        path = "/srv/samba/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "force user" = "nobody";
        "force group" = "nogroup";
        "create mask" = "0666";
        "directory mask" = "0777";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/samba 0755 root root -"
    "d /srv/samba/public 0777 nobody nogroup -"
  ];

  networking.firewall.allowedTCPPorts = [ 445 139 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  # <<<

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  users.users."${variables.username}".extraGroups = [
    "wheel" "video" "audio" "disk" "networkmanager" "dialout"
  ];

  # After rebuilding, check whether the user timer is active:
  #   systemctl --user status low-battery-suspend.timer
  # If it is not enabled, enable it once:
  #   systemctl --user enable --now low-battery-suspend.timer
  # Verify:
  #   systemctl --user list-timers low-battery-suspend.timer
  systemd.user.services.low-battery-suspend = {
    description = "Low battery suspend prompt";

    serviceConfig = {
      Type = "oneshot";

      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=%h/.Xauthority"
      ];

      ExecStart = pkgs.writeShellScript "low-battery-suspend" ''
        BAT="/sys/class/power_supply/BAT0"

        if [ ! -e "$BAT/capacity" ]; then
          echo "expected file does not exist: $BAT/capacity"
          exit 1
        fi

        cap=$(<"$BAT/capacity")
        status=$(<"$BAT/status")
        echo "battery: $cap%, status: $status"

        if [ "$status" != "Discharging" ] || [ "$cap" -gt 15 ]; then
          exit 0
        fi

        if ! ${pkgs.xdpyinfo}/bin/xdpyinfo >/dev/null 2>&1; then
          echo "no X server available: aborting this check"
          exit 0
        fi

        choice=$(
          ${pkgs.coreutils}/bin/timeout 30s ${pkgs.runtimeShell} -c '
            printf "Suspend now\nCancel\n" |
              ${pkgs.rofi}/bin/rofi -dmenu -p "Battery '"$cap"'% - auto-suspend in 30s"
          '
        )
        rc=$?

        echo "rofi result: choice=[$choice], rc=$rc"

        if [ "$choice" = "Suspend now" ]; then
          echo "'Suspend now' has been chosen"
          systemctl suspend
          exit 0
        fi

        # timeout returns exit code 124 if command actually times out
        if [ "$rc" -eq 124 ]; then
          echo "timeout: auto-suspend"
          systemctl suspend
        fi

        exit 0
      '';
    };
  };

  systemd.user.timers.low-battery-suspend = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "2min";
    };
  };

  # XXX: kept in systemPackages as these packages are used within systemd.services scripts
  environment.systemPackages = with pkgs; [
    gnugrep
    xrandr
    coreutils-full

    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system.stateVersion = "24.11";
}
