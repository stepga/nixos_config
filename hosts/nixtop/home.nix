{ pkgs, lib, variables, ... }:

{
  home.username = "${variables.username}";
  home.homeDirectory = "/home/${variables.username}";

  imports = [
    ../../home/desktop.nix
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
    transmission_4-gtk
    unixtools.netstat
    unrar
    unzip
    usbutils # usbreset
    wget
    which
    xxd
    yt-dlp
    zip
  ];

  home.sessionPath = [
    "$HOME/go/bin"
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 20000;
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      tig = "TIG_SCRIPT=<(echo :toggle id) tig";
    };
    oh-my-zsh = {
      enable = true;
      theme = "ys";
      plugins = [
        "autojump"
        "git"
        "fzf"
      ];
    };
    initContent = lib.mkOrder 1200 ''
      source ~/.functions.sh
    '';
  };

  home.file.".functions.sh".source = ./functions.sh;

  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "${variables.git.user.email}";
        name = "${variables.git.user.name}";
      };
      alias = {
        "a" = "add";
        "cv" = "commit --verbose";
        "co" = "checkout";
        "ca" = "commit -a --verbose";
        "d" = "diff";
        "wd" = "diff --word-diff";
        "lg" = "log --graph --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(bold blue)%h%C(reset) %C(bold green)(%ad)%C(reset) %C(bold)%s%C(reset) | %C(bold red)%an%C(reset)%C(bold cyan)%d%C(reset)'";
        "ri" = "rebase -i";
        "s" = "status";
      };
      core = {
        "editor" = "nvim";
        "lineNumber" = "true";
        "filemode" = "false";
        "autocrlf" = "false";
      };
      grep = {
        "linenumber" = "true";
      };
      push = {
        "default" = "matching";
      };
      advice = {
        "ignoredHook" = "false";
      };
    };
  };

  programs.go = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = true; # default value of has changed from `true` to `false` in 26.05
    withPython3 = true; # default value of has changed from `true` to `false` in 26.05
    plugins = with pkgs.vimPlugins; [
      barbar-nvim
      fzf-vim
      which-key-nvim

      # git
      vim-signify
      vim-fugitive

      # treesitter: highlighting & indenting; requires gcc
      nvim-treesitter
      # nix ftplugin
      vim-nix

      # go
      go-nvim

      # lsp
      nvim-lspconfig

      # autocompletion plugin
      nvim-cmp
      cmp-buffer
      cmp-path
      cmp-cmdline
      # LSP source for nvim-cmp
      cmp-nvim-lsp
      # Snippets source for nvim-cmp
      cmp_luasnip
      # Snippets plugin vsnip
      cmp-vsnip
      vim-vsnip
    ];
    extraConfig = builtins.readFile ./neovim/init.vim;
  };

  programs.tmux = {
    enable = true;
    baseIndex = 0;
    clock24 = true;
    keyMode = "vi";
    historyLimit = 100000;
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";
}
