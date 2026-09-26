{ config, lib, pkgs, inputs, ... }:

let
  opencodeConfig = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    permission = {
      external_directory = "deny";
      bash = "ask";
    };
  });
in
{
  environment.systemPackages = [
    pkgs.bubblewrap

    (pkgs.writeShellScriptBin "opencode-sandbox" ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Usage: opencode-sandbox [readonly-path ...] [-- opencode-args ...]

      Run OpenCode in a filesystem sandbox.

      The current working directory is mounted read/write.
      Additional paths can be specified before '--' and are mounted read-only.

      Options:
        -h, --help    Show this help and exit
        --            End of sandbox arguments; remaining arguments go to OpenCode.

      Examples:
        opencode-sandbox
        opencode-sandbox /home/me/datasets
        opencode-sandbox /home/me/datasets /home/me/docs
        opencode-sandbox /home/me/datasets -- --model anthropic/claude-sonnet-4-5
      EOF
      }

      project="$(realpath -e "$(pwd)")"
      state_dir="$HOME/.local/state/opencode-sandbox"

      mkdir -p "$state_dir"

      readonly_paths=()

      while [[ "$#" -gt 0 ]]; do
        case "$1" in
          -h|--help)
            usage
            exit 0
            ;;

          --)
            shift
            break
            ;;

          -*)
            echo "error: unexpected option before '--': $1" >&2
            echo >&2
            usage >&2
            exit 2
            ;;

          *)
            path="$(realpath -e -- "$1")"
            readonly_paths+=("$path")
            shift
            ;;
        esac
      done

      bwrap_args=(
        --die-with-parent
        --new-session
        --unshare-pid
        --unshare-ipc
        --unshare-uts
        --unshare-cgroup

        --proc /proc
        --dev /dev
        --tmpfs /tmp

        --ro-bind /nix/store /nix/store
        --ro-bind /run/current-system/sw /run/current-system/sw

        --ro-bind /etc/resolv.conf /etc/resolv.conf
        --ro-bind /etc/ssl /etc/ssl

        --dir /home
        --dir /home/opencode
        --bind "$state_dir" /home/opencode

        --ro-bind ${opencodeConfig} /home/opencode/opencode.json

        --bind "$project" "$project"
        --chdir "$project"

        --setenv HOME /home/opencode
        --setenv PATH /run/current-system/sw/bin
        --setenv SHELL /run/current-system/sw/bin/bash

        --share-net
      )

      for path in "''${readonly_paths[@]}"; do
        bwrap_args+=(
          --ro-bind
          "$path"
          "$path"
        )
      done

      exec ${pkgs.bubblewrap}/bin/bwrap \
        "''${bwrap_args[@]}" \
        ${inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/opencode "$@"
    '')
  ];
}
