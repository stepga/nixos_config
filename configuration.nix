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
  ap_dhcp_range_start = "10.0.0.2";
  ap_dhcp_range_end = "10.0.0.254";
  ap_dhcp_subnet_mask = "255.255.255.0";

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
            iifname "${wan_iface_name}" tcp dport 22 ip saddr ${wan_client_ip_addrs} accept comment "Allow ssh from isp modem dhcp clients"
            iifname "${wan_iface_name}" counter drop comment "Drop all other unsolicited traffic from wan"
          }

          chain forward {
            type filter hook forward priority 0; policy drop;
            iifname "${ap_iface_name}" oifname "${wan_iface_name}" accept comment "Allow trusted LAN to WAN"
            iifname "${wan_iface_name}" oifname "${ap_iface_name}" ct state established, related accept comment "Allow established back to LANs"
          }
        }

        table ip nat {
          chain prerouting {
            type nat hook prerouting priority -100;
            iifname "${ap_iface_name}" tcp dport 80 redirect to 1080
          }

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
  users.users."root".openssh.authorizedKeys.keys = [ secrets.authorized_keys.root ];

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
      PermitRootLogin = "yes";
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

  services.adguardhome = {
    enable = true;
    openFirewall = false;
    mutableSettings = true;
    settings = {
      bind_port = 1080;
      schema_version = 24;

      # XXX the following settings were extracted from an interactively configured
      # AdGuardHome's config file (see /var/lib/AdGuardHome/AdGuardHome.yaml).
      users = [
        {
          name = "admin";
          password = "${secrets.adguardhome}";
        }
      ];
      dhcp = {
        enabled = true;
        interface_name = "${ap_iface_name}";
        local_domain_name = "lan";
        dhcpv4 = {
          gateway_ip = "${ap_ip_addr}";
          subnet_mask = "${ap_dhcp_subnet_mask}";
          range_start = "${ap_dhcp_range_start}";
          range_end = "${ap_dhcp_range_end}";
          lease_duration = 86400;
        };
      };

      filters = [
        {
          enabled = true;
          id = 1;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
        }
        {
          enabled = true;
          id = 2;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
        }
        {
          enabled = true;
          id = 3;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
          name = "HaGeZi's Pro DNS Blocklist";
        }
      ];
      user_rules = [
        "# respond with ${ap_ip_addr} for dns.lan (nftable will do the nat redirect)"
        "${ap_ip_addr} dns.lan"
      ];
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
