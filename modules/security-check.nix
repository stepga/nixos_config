
{ config, lib, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  vulnxscan = inputs.sbomnix.apps.${system}.vulnxscan.program;

  securityCheckSource = pkgs.runCommand "nix-security-check-source" {} ''
    mkdir -p $out
    cp ${./security-check/security-check.rb} $out/security-check.rb
    cp ${./security-check/report.html.erb} $out/report.html.erb
    cp ${./security-check/report.css} $out/report.css
  '';

  securityCheck = pkgs.writeShellApplication {
    name = "nix-security-check";

    runtimeInputs = [
      pkgs.ruby
      pkgs.coreutils
      pkgs.libnotify
    ];

    text = ''
      exec ${pkgs.ruby}/bin/ruby \
        ${securityCheckSource}/security-check.rb \
        "$@"
    '';
  };
in
{
  systemd.user.services.nix-security-check = {
    description = "Check current NixOS system for vulnerabilities";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${securityCheck}/bin/nix-security-check";
    };

    environment = {
      VULNXSCAN = vulnxscan;
    };
  };

  systemd.user.timers.nix-security-check = {
    description = "Periodically check NixOS system for vulnerabilities";

    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };

    wantedBy = [
      "timers.target"
    ];
  };
}
