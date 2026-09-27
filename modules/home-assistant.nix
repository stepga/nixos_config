{ config, lib, pkgs, ... }:
{
  services.home-assistant = {
    enable = true;

    extraComponents = [
      "zha"
      "google_translate"
    ];

    config = {
      default_config = {};
    };

    extraPackages = pythonPackages: [
      pythonPackages.starlink-grpc-core
    ];
  };

  users.groups.home-assistant = {};

  users.users.home-assistant = {
    isSystemUser = true;
    group = "home-assistant";
    extraGroups = [ "dialout" ];
  };
}
