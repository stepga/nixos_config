{ pkgs, ... }:

{
  imports = [
    # shared settings for all hosts
    ../../common/home/common.nix
    # shared shell/editor setup (zsh, git, neovim, tmux, go)
    ../../common/home/shell.nix
    # shared desktop/X11 setup (window manager, terminal, browser, ...)
    ../../common/home/desktop.nix
  ];

  home.packages = with pkgs; [
    acpi
    age
    alsa-utils # aplay
    amdgpu_top
    android-file-transfer
    arp-scan
    autojump
    bear
    ccls
    colordiff
    delve
    dig
    dmidecode
    entr # launch and auto-reload on file change: `find ./src/ | entr -r go test src/foo.go`
    file
    fzf
    gcc
    gnumake
    gopls
    gore
    htop
    ipmitool
    jq
    libinput
    lshw
    man-pages
    man-pages-posix
    mdcat # mdless
    ncdu
    nftables
    nil
    nixfmt
    nload
    nvd
    pass
    pciutils # lspci
    pstree
    python3
    ripgrep
    ripgrep-all # rga, rga-fzf
    ruby
    tcpdump
    tig
    unixtools.netstat
    unrar
    unzip
    usbutils # usbreset
    wget
    which
    xxd
    yt-dlp
    zip

    # enforce transmission-gtk being executed via freifunk tunnel
    (writeShellScriptBin "transmission-gtk" ''
      exec ${freifunk}/bin/ff.sh ${transmission_4-gtk}/bin/transmission-gtk "$@"
    '')
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";
}
