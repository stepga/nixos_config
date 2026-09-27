# Help:
# - `man 5 configuration.nix`
# - `nixos-help`
# - `nixos-option <foo>`
# - https://search.nixos.org/options

{ config, lib, pkgs, variables, ... }:

let
  ipaddr_modem = "192.168.1.1";
  ifname_wan = "enp1s0";
  ifname_switch = "enp2s0";
  ipaddr_switch = "10.0.0.1";

  assets_path = "/etc/nixos/assets";
  # see https://github.com/Ultimate-Hosts-Blacklist/Ultimate.Hosts.Blacklist
  ads_host_file_url = "https://hosts.ubuntu101.co.za/hosts";
  ads_host_file_path = "${assets_path}/blacklist-hosts";

  homepage = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html>
      <body>
        <h1>apu2d4 services</h1>

        <ul>
          <li><a href="http://apu2d4.home.arpa:8123">Home Assistant</a></li>
          <li><a href="https://apu2d4.home.arpa:8443">Unifi Controller</a></li>
        </ul>
      </body>
    </html>
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/home-assistant.nix
  ];

  sops.defaultSopsFile = ../../secrets/${variables.hostname}.yaml;

  # declare the SOPS secrets
  sops.secrets."rclone/content" = {};
  sops.secrets."rclone/source" = {};

  sops.secrets."authorized_keys/${variables.username}" = {
    path = "/etc/ssh/authorized_keys.d/${variables.username}";
    mode = "0644";
    owner = "root";
    group = "root";
  };
  sops.secrets."authorized_keys/root" = {
    path = "/etc/ssh/authorized_keys.d/root";
    mode = "0644";
    owner = "root";
    group = "root";
  };
  systemd.tmpfiles.rules = [
    "d /etc/ssh/authorized_keys.d 0755 root root -"
  ];
  services.openssh.extraConfig = ''
    AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
  '';

  # https://github.com/NixOS/nixos-hardware/blob/master/pcengines/apu/default.nix
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.grub.extraConfig = "
    serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
    terminal_input serial
    terminal_output serial
  ";

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  fileSystems."/usb" = {
    device = "/dev/disk/by-uuid/b985e946-77ea-4beb-9fb6-55e3066b4ebe";
    fsType = "ext4";
    # make a mount of the external usb drive asynchronous and non-critical
    options = [ "nofail" ];
  };

  i18n.defaultLocale = "en_US.UTF-8";

  # this host is configured via `networking.interfaces` below, not via NetworkManager
  networking.networkmanager.enable = false;

  environment.systemPackages = with pkgs; [
    arp-scan
    curl
    htop
    ipmitool
    iw
    nix-tree  # show package dependencies
    nload
    pciutils  # lspci
    rclone
    rxvt-unicode  # needed for: rxvt-unicode-unwrapped-9.31-terminfo/share/terminfo/r/rxvt-unicode
    vim
    wget
    net-tools
  ];

  programs = {
    tmux = {
      enable = true;
      clock24 = true;
      keyMode = "vi";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes";
    };
  };

  # allow mDNS
  services.avahi = {
    enable = true;
    reflector = true;
    publish = {
      enable = true;
      domain = true;
    };
    domainName = "local";
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
  };

  networking = {
    enableIPv6 = false;
    domain = "home.arpa"; # hostName is set by the flake
    defaultGateway = "${ipaddr_modem}";
    interfaces = {
      "${ifname_wan}" = {
        useDHCP = true;
      };
      "${ifname_switch}" = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = "${ipaddr_switch}";
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
            iifname "${ifname_wan}" ct state { established, related } accept comment "Allow established traffic"
            iifname "${ifname_wan}" icmp type echo-request counter accept comment "Allow ping"
            iifname "${ifname_wan}" counter drop comment "Drop all other unsolicited traffic from wan"
          }
          chain forward {
            type filter hook forward priority 0; policy accept;
          }
          chain output {
            type filter hook output priority 0; policy accept;
          }
        }
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "${ifname_wan}" masquerade
          }
        }
      '';
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
      dhcp-range = [ "10.0.0.2,10.0.0.254,24h" ];
      interface = "${ifname_switch}";
      listen-address = "${ipaddr_switch}";
      # no reverse-lookup for private ip addresses
      bogus-priv = true;
      cache-size = 10000;
      log-queries = true;
      log-facility = "/tmp/ad-block.log";
      addn-hosts = "${ads_host_file_path}";

      dhcp-authoritative = true;
      no-hosts = true;
      domain = "home.arpa";
      local = "/home.arpa/";
      expand-hosts = true;
      dhcp-option = [
        "option:domain-name,home.arpa"
        "option:domain-search,home.arpa"
      ];
      host-record = [
        "apu2d4.home.arpa,10.0.0.1"
      ];
      dhcp-host = [
        "00:0d:b9:53:63:2d,apu2d4,10.0.0.1,infinite"
        "54:07:7d:1a:16:90,netgear_switch,10.0.0.2,infinite"
        "9c:05:d6:d3:ca:9b,unifi_u6pro,10.0.0.3,infinite"
        "ac:1f:6b:a6:db:7b,blackbox_ipmi,10.0.0.4,infinite"
        "ac:1f:6b:98:8b:9c,blackbox,10.0.0.5,infinite"
        "ca:55:b4:d8:33:5e,freifunk,10.0.0.6,infinite"
      ];
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
      if [[ "$?" -ne 0 || ! -s "${ads_host_file_path}.tmp" ]] ; then
        ${pkgs.coreutils}/bin/echo "curl-ing hosts file failed"
        exit 1
      fi
      # custom banned sites
      ${pkgs.coreutils}/bin/echo "0.0.0.0 boards.4chan.org" >> ${ads_host_file_path}.tmp
      ${pkgs.coreutils}/bin/echo "0.0.0.0 4chan.org" >> ${ads_host_file_path}.tmp
      ${pkgs.coreutils}/bin/echo "0.0.0.0 danisch.de" >> ${ads_host_file_path}.tmp
      ${pkgs.coreutils}/bin/echo "0.0.0.0 pr0gramm.com" >> ${ads_host_file_path}.tmp
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

      ${pkgs.gnugrep}/bin/grep -qs "/usb" /proc/mounts || ${pkgs.mount}/bin/mount /usb

      ${pkgs.coreutils}/bin/mkdir -p /usb/nextcloud_sync
      ${pkgs.coreutils}/bin/mkdir -p /usb/nextcloud_backups

      ${pkgs.rclone}/bin/rclone \
        --config ${config.sops.secrets."rclone/content".path} \
        sync "$(cat ${config.sops.secrets."rclone/source".path})" /usb/nextcloud_sync \
        --backup-dir "/usb/nextcloud_backups/$(date '+%Y_%m_%d-%H_%M_%S')"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  virtualisation.oci-containers = {
    containers.unifi = {
      image = "jacobalberty/unifi";
      extraOptions = [
        "--no-healthcheck"
      ];
      ports = [
        "8880:8880"
        "8443:8443"
        "8080:8080"
        "3478:3478"
      ];
      volumes = [
        "/docker_volumes/unifi:/unifi"
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."apu2d4.home.arpa" = {
      listen = [
        {
          addr = "10.0.0.1";
          port = 80;
        }
      ];
      root = homepage;
    };
  };

  system.stateVersion = "24.05";
}
