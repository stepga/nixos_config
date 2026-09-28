{ config, lib, ... }:
let
  cfg = config.services.tunneldigger;
in
{
  options.services.tunneldigger = {
    enable = lib.mkEnableOption "Tunneldigger L2TPv3 tunnel";

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
      type = lib.types.str;
      description = "Network interface used for the Tunneldigger UDP connection.";
    };

    brokers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Tunneldigger brokers in host:port format.";
    };
  };

  config = lib.mkIf cfg.enable {
    # service comes later
  };
}
