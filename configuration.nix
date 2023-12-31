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

  assets_path = "/etc/nixos/assets";
  ads_host_file_url = "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt";
  ads_host_file_path = "${assets_path}/ads-and-tracking-extended.txt";

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
    rclone
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
    radios."${ap_iface_name}" = {
      band = "5g";
      channel = 0;
      # disables scan for overlapping BSSs in HT40+/- mode
      # (likely violates regulatory requirements)
      noScan = true;
      countryCode = "US";
      networks.${ap_iface_name} = {
        ssid = secrets.wifi.ssid;
        authentication = {
          mode = "wpa2-sha256";
          wpaPassword = secrets.wifi.passphrase;
        };
      };
      # IEEE  802.11n; HT (high throughput); enabled by default
      # XXX using ACS (channel = 0) together with HT40- (wifi4.capabilities) is unsupported by hostapd
      wifi4.capabilities = [
        "HT40+"
        #"HT40-"
        "SHORT-GI-20"
        "SHORT-GI-40"
        "DSSS_CK-40"
        "MAX-AMSDU-7935"
      ];
      wifi5 = {
        # IEEE 802.11ac; VHT (very high throughput); enabled by default
        capabilities = [
          "SHORT-GI-80"
          "TX-STBC-2BY1"
          "RX-STBC-1"
          "MAX-MPDU-11454"
        ];
        # vht_oper_chwidth=1
        # "20or40": 0 (default)
        # "80":     1
        # "160":    2
        # "80+80":  3
        operatingChannelWidth = "80";
      };
    };
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
      log-facility = "/tmp/ad-block.log";
      addn-hosts = "${ads_host_file_path}";
    };
  };

  systemd.timers."dnsmasq-hosts-file" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1d";
      OnCalendar = "daily";
      Persistent = true;
      Unit = "dnsmasq-hosts-file.service";
    };
  };

  systemd.services."dnsmasq-hosts-file" = {
    script = ''
      set -eu
      ${pkgs.coreutils}/bin/mkdir -p ${assets_path}
      ${pkgs.curl}/bin/curl -o ${ads_host_file_path}.tmp ${ads_host_file_url}
      ${pkgs.coreutils}/bin/mv ${ads_host_file_path}.tmp ${ads_host_file_path}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers."rclone-nextcloud" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "6m";
      OnUnitActiveSec = "1d";
      OnCalendar = "daily";
      Persistent = true;
      Unit = "rclone-nextcloud.service";
    };
  };

  systemd.services."rclone-nextcloud" = {
    script = ''
      set -eu
      ${pkgs.gnugrep}/bin/grep -qs "/usb" /proc/mounts || mount /usb
      ${pkgs.coreutils}/bin/mkdir -p /usb/nextcloud_sync
      ${pkgs.coreutils}/bin/mkdir -p /usb/nextcloud_backups
      ${pkgs.coreutils}/bin/echo "${secrets.rclone.content}" > /tmp/rclone.config
      ${pkgs.rclone}/bin/rclone --config /tmp/rclone.config \
        sync ${secrets.rclone.source} /usb/nextcloud_sync \
        --backup-dir "/usb/nextcloud_backups/$(date '+%Y_%m_%d-%H_%M_%S')"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
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
