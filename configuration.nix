# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

let
  modem_ip_addr = "192.168.1.1";
  wan_ip_addr = "192.168.1.2"; # modem's dhcp range starts at 192.168.1.3
  wan_client_ip_addrs = "192.168.1.2-192.168.1.254";
  wan_iface_name = "enp1s0";
  ap_ip_addr = "10.0.0.1";
  ap_iface_name = "wlp4s0";
  ap_dhcp_range = "10.0.0.2,10.0.0.254,24h";

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

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
  };

  networking = {
    enableIPv6 = false;
    hostName = "apu2d4";
    domain = "lan";
    defaultGateway = "${modem_ip_addr}";
    interfaces = {
      "${wan_iface_name}" = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = "${wan_ip_addr}";
          prefixLength = 24;
        } ];
      };
      "${ap_iface_name}" = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = "${ap_ip_addr}";
          prefixLength = 24;
        } ];
      };
    };
    firewall.enable = false;

    nftables = {
      enable = true;
      ruleset = ''
        table ip filter {
          chain input {
            type filter hook input priority 0; policy accept;
            iifname "${wan_iface_name}" ct state { established, related } accept comment "Allow established traffic"
            iifname "${wan_iface_name}" icmp type echo-request counter accept comment "Allow ping"
            iifname "${wan_iface_name}" tcp dport 22 ip saddr { ${wan_client_ip_addrs} } accept comment "Allow ssh from isp modem dhcp clients"
            iifname "${wan_iface_name}" counter drop comment "Drop all other unsolicited traffic from wan"
          }

          chain forward {
            type filter hook forward priority 0; policy drop;
            iifname { "${ap_iface_name}" } oifname { "${wan_iface_name}" } accept comment "Allow trusted LAN to WAN"
            iifname { "${wan_iface_name}" } oifname { "${ap_iface_name}" } ct state established, related accept comment "Allow established back to LANs"
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "${wan_iface_name}" masquerade
          }
        }
      '';
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

  services.hostapd = {
    enable = true;
    interface = "${ap_iface_name}";
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
      dhcp-range = [ "${ap_dhcp_range}" ];
      interface = "${ap_iface_name}";
      listen-address = "${ap_ip_addr}";
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
