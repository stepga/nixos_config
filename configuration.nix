# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

let
  secrets = import ./secrets.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./apu2d4.nix
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
    enableIPv6 = false;
    hostName = "apu2d4";
    domain = "lan";
    defaultGateway = "192.168.1.1";
    interfaces = {
      enp1s0.ipv4.addresses = [ {
        address = "192.168.1.2"; # XXX dhcp range starts at 192.168.1.3
        prefixLength = 24;
      } ];
    };
    interfaces = {
      wlp4s0.ipv4.addresses = [ {
        address = "10.0.0.1";
        prefixLength = 24;
      } ];
    };
    firewall.enable = false;
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

  services.hostapd = {
    enable = true;
    interface = "wlp4s0";
    ssid = secrets.wifi.ssid;
    wpaPassphrase = secrets.wifi.passphrase;
    hwMode = "a";
    channel = 0;
    countryCode = "US";
    extraConfig =
    ''
        # turn off dfs (ie outdoor ir/radar detection)
        ieee80211h=0

        ieee80211n=1
        wmm_enabled=1
        ht_capab=[HT40+][HT40-][SHORT-GI-20][SHORT-GI-40][DSSS_CK-40][MAX-AMSDU-7935]

        ieee80211ac=1
        vht_oper_chwidth=1
        vht_capab=[SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-MPDU-11454]
    '';
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      # Never forward A or AAAA queries for plain names, without dots or domain
      # parts, to upstream nameservers. If the name is not known from /etc/hosts
      # or DHCP then a "not found" answer is returned.
      domain-needed = true;
      # networking.nameservers in /etc/resolv.conf shoud be replaced by 127.0.0.1
      server = [ "8.8.8.8" "8.8.4.4" ];
      dhcp-range = [ "10.0.0.2,10.0.0.254,24h" ];  # TODO use variable
      interface = "wlp4s0";  # TODO use variable
      listen-address = "10.0.0.1";  # TODO use variable
      # no reverse-lookup for private ip addresses
      bogus-priv = true;
      cache-size = 10000;
      log-queries = true;
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  system.stateVersion = "23.05";

  programs = {
    tmux = {
      enable = true;
      clock24 = true;
      keyMode = "vi";
    };
  };
}
