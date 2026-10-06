{ config, lib, pkgs, ... }:

let
  cfg = config.services.tunneldigger;

  startScript = pkgs.writeShellScript "tunneldigger-start" ''
    set -eu

    broker=${lib.escapeShellArg cfg.broker}
    brokerHost="''${broker%:*}"

    brokerIp="$(
      ${pkgs.getent}/bin/getent ahostsv4 "$brokerHost" |
        ${pkgs.gawk}/bin/awk 'NR == 1 { print $1; exit }'
    )"

    if [ -z "$brokerIp" ]; then
      echo "Could not resolve broker: $brokerHost" >&2
      exit 1
    fi

    echo "Resolved $brokerHost to $brokerIp"

    underlay="$(
      ${pkgs.iproute2}/bin/ip route get "$brokerIp" |
        ${pkgs.gawk}/bin/awk '
          {
            for (i = 1; i <= NF; i++) {
              if ($i == "dev") {
                print $(i + 1)
                exit
              }
            }
          }
        '
    )"

    if [ -z "$underlay" ]; then
      echo "Could not determine route interface for broker: $brokerIp" >&2
      exit 1
    fi

    echo "Using $underlay as underlay interface for $broker"

    mkdir -p /run/tunneldigger
    echo "$underlay" > /run/tunneldigger/underlay

    exec ${cfg.package}/bin/tunneldigger \
      -f \
      -u ${lib.escapeShellArg cfg.uuid} \
      -i ${lib.escapeShellArg cfg.interface} \
      -b "$broker" \
      -I "$underlay"
  '';

  waitForInterface = pkgs.writeShellScript "tunneldigger-wait-for-interface" ''
    set -eu

    interface=${lib.escapeShellArg cfg.interface}

    echo "Waiting for $interface..."

    for i in $(seq 1 30); do
      if ${pkgs.iproute2}/bin/ip link show "$interface" >/dev/null 2>&1; then
        echo "$interface exists."
        exit 0
      fi

      sleep 1
    done

    echo "Timed out waiting for $interface" >&2
    exit 1
  '';
in
{
  options.services.tunneldigger = {
    enable = lib.mkEnableOption "Tunneldigger L2TPv3 tunnel";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tunneldigger;
      defaultText = lib.literalExpression "pkgs.tunneldigger";
      description = "Tunneldigger package to use.";
    };

    uuid = lib.mkOption {
      type = lib.types.str;
      description = "UUID used to identify the Tunneldigger client.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "ff0";
      description = "Name of the Tunneldigger tunnel interface.";
    };

    underlayInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Network interface used for the Tunneldigger UDP connection.
        If null, the interface used to reach the broker is determined automatically.
      '';
    };

    broker = lib.mkOption {
      type = lib.types.str;
      description = "Tunneldigger broker in host:port format.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.tunneldigger = {
      description = "Tunneldigger L2TPv3 tunnel";

      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.getent
        pkgs.gawk
        pkgs.iproute2
      ];

      serviceConfig = {
        ExecStart =
          if cfg.underlayInterface != null then
            "${cfg.package}/bin/tunneldigger -f -u ${lib.escapeShellArg cfg.uuid} -i ${lib.escapeShellArg cfg.interface} -b ${lib.escapeShellArg cfg.broker} -I ${lib.escapeShellArg cfg.underlayInterface}"
          else
            "${startScript}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    environment.etc."tunneldigger-dhcpcd.conf".text = ''
      nohook resolv.conf
    '';

    systemd.services.tunneldigger-dhcp = {
      description = "DHCP on Tunneldigger interface";

      wantedBy = [ "multi-user.target" ];
      after = [ "tunneldigger.service" ];
      requires = [ "tunneldigger.service" ];

      serviceConfig = {
        Type = "simple";

        ExecStartPre = waitForInterface;

        ExecStart = pkgs.writeShellScript "tunneldigger-dhcp-start" ''
          set -eu

          interface=${lib.escapeShellArg cfg.interface}

          ${pkgs.iproute2}/bin/ip link set "$interface" up

          exec ${pkgs.dhcpcd}/bin/dhcpcd \
            -4 \
            --nobackground \
            --config /etc/tunneldigger-dhcpcd.conf \
            "$interface"
        '';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
