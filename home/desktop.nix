{ config, pkgs, lib, variables, ... }:

{
  home.packages = with pkgs; [
    arandr
    brightnessctl
    dunst # dbus notification daemon (needed for mictray)
    eog
    evince
    gedit
    gimp
    gparted
    imagemagick # scripts/clip
    killall # needed for killing pasystray before (re)starting it in i3wm
    mictray
    nautilus
    networkmanagerapplet
    nextcloud-client
    pasystray
    pavucontrol
    pcmanfm
    pulseaudio # pactl in i3wm's config
    rofi
    signal-desktop
    simple-scan
    thunderbird
    xclip
    xdotool
    xss-lock
  ];

  programs.i3status-rust = {
    enable = true;
    bars = {
      default = {
        blocks = [
          {
            block = "disk_space";
            path = "/";
            info_type = "available";
            interval = 10;
            warning = 20.0;
            alert = 10.0;
          }
          {
            block = "memory";
            format = " $icon $mem_total_used_percents.eng(w:2) ";
            format_alt = " $icon_swap $swap_used_percents.eng(w:2) ";
          }
          {
            block = "cpu";
            info_cpu = 20;
            warning_cpu = 50;
            critical_cpu = 90;
          }
          {
            block = "sound";
            click = [
              {
                button = "left";
                cmd = "pavucontrol";
              }
            ];
          }
          {
            block = "battery";
            format = " $icon $percentage (remaining $time_remaining)";
            full_format = " 🔋 $percentage ";
            charging_format = " 🔌 $percentage ";
            empty_format = " 🪫 $percentage ";
            driver = "sysfs";
            device = "BAT0";
          }
          {
            block = "time";
            interval = 60;
            format = " $timestamp.datetime(f:'%a %d/%m %R') ";
          }
        ];
        settings = {
          theme =  {
            theme = "solarized-dark";
            overrides = {
              idle_bg = "#123456";
              idle_fg = "#abcdef";
            };
          };
        };
        # list of available icon sets:
        # https://github.com/greshake/i3status-rust/blob/master/doc/themes.md
        icons = "awesome6";
        theme = "gruvbox-dark";
      };
    };
  };

  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox"; # default changed from ~/.mozilla/firefox to ~/.config/mozilla/firefox in 26.05

    # see https://mozilla.github.io/policy-templates/ for
    policies = {
      DontCheckDefaultBrowser = true;

      EncryptedMediaExtensions = {
        # If Enabled is set to false, encrypted media extensions (like Widevine)
        # are not downloaded by Firefox unless the user consents to installing
        # them.
        Enabled = true;
        # If Locked is set to true and Enabled is set to false, Firefox will not
        # download encrypted media extensions (like Widevine) or ask the user to
        # install them.
        Locked = false;
      };

      # Extension configuration
      ExtensionSettings = with builtins;
        let extension = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "normal_installed";
            private_browsing = true;
          };
        };
        # find addon short ID example:
        #   $ wget https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi
        #   $ unzip vimium_ff-2.4.2.xpi
        #   $ jq .browser_specific_settings.gecko.id manifest.json
        #   "{d7742d87-e61d-4b78-b8a1-b469842139fa}"
        in listToAttrs [
            (extension "tree-style-tab" "treestyletab@piro.sakura.ne.jp")
            (extension "ublock-origin" "uBlock0@raymondhill.net")
            (extension "vimium-ff" "{d7742d87-e61d-4b78-b8a1-b469842139fa}")
          ];

      "3rdparty".Extensions = {
        "uBlock0@raymondhill.net".adminSettings = {
          userSettings = rec {
            importedLists = [
              "https:#filters.adtidy.org/extension/ublock/filters/3.txt"
              "https:#github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
            ];
            externalLists = lib.concatStringsSep "\n" importedLists;
          };

          selectedFilterLists = [
            "CZE-0"
            "adguard-generic"
            "adguard-annoyance"
            "adguard-social"
            "adguard-spyware-url"
            "easylist"
            "easyprivacy"
            "https:#github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
            "plowe-0"
            "ublock-abuse"
            "ublock-badware"
            "ublock-filters"
            "ublock-privacy"
            "ublock-quick-fixes"
            "ublock-unbreak"
            "urlhaus-1"
          ];
        };
      };

      SearchEngines = {
        Remove = [
          "Bing"
          "Ecosia"
          "Perplexity"
          "Wikipedia (en)"
          "eBay"
        ];
        Add = [
          {
            "Name" = "OpenStreetMap";
            "URLTemplate" = "https://www.openstreetmap.org/search?query={searchTerms}";
            "IconURL" = "https://www.openstreetmap.org/favicon.ico";
            "Alias" = "osm";
          }
          {
            "Name" = "Wikipedia en";
            "URLTemplate" = "https://en.wikipedia.org/wiki/Special:Search?go=Go&search={searchTerms}";
            "IconURL" = "https://en.wikipedia.org/favicon.ico";
            "Alias" = "we";
          }
          {
            "Name" = "Wikipedia de";
            "URLTemplate" = "https://de.wikipedia.org/wiki/Special:Search?go=Go&search={searchTerms}";
            "IconURL" = "https://en.wikipedia.org/favicon.ico";
            "Alias" = "wd";
          }
          {
            "Name" = "YouTube";
            "URLTemplate" = "https://www.youtube.com/results?search_query={searchTerms}";
            "IconURL" = "https://www.youtube.com/favicon.ico";
            "Alias" = "yt";
          }
          {
            "Name" = "Nix Packages";
            "URLTemplate" = "https://search.nixos.org/packages?channel=25.11&query={searchTerms}";
            "IconURL" = "https://nixos.org/favicon.ico";
            "Alias" = "np";
          }
          {
            "Name" = "Nix Options";
            "URLTemplate" = "https://search.nixos.org/options?channel=25.11&include_modular_service_options=1&include_nixos_options=1&query={searchTerms}";
            "IconURL" = "https://nixos.org/favicon.ico";
            "Alias" = "no";
          }
          {
            "Name" = "Home Manager Options";
            "URLTemplate" = "https://home-manager-options.extranix.com/?release=release-25.11&query={searchTerms}";
            "IconURL" = "https://nixos.org/favicon.ico";
            "Alias" = "hm";
          }
          {
            "Name" = "English-German Dictionary";
            "URLTemplate" = "https://www.dict.cc/?s={searchTerms}";
            "IconURL" = "https://dict.cc/favicon.ico";
            "Alias" = "en";
          }
        ];
        Default = "Google";
      };
      SearchSuggestEnabled = false;
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "Font Awesome 7 Free Regular";
      size = 12;
    };
    settings = {
      enable_audio_bell = false;
      copy_on_select = "clipboard";
    };
  };

  # compare generated ~/.config/i3/config with `git show $(git rev-list --max-count=1 --all -- i3/config)^:i3/config)`
  xsession.windowManager.i3 = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      keybindings = lib.mkOptionDefault {
        "XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        "XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10%";
        "XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10%";
        "XF86MonBrightnessDown" = "exec --no-startup-id brightnessctl set 5%-";
        "XF86MonBrightnessUp" = "exec --no-startup-id brightnessctl set +5%";
        "${modifier}+Return" = ''exec termspawn'';
        "${modifier}+Shift+c" = "kill";
        "${modifier}+p" = ''exec --no-startup-id "${pkgs.rofi}/bin/rofi -modi drun,run,combi -show combi -show-icons"'';
        "${modifier}+Tab" = "workspace back_and_forth";
        "${modifier}+Shift+Tab" = "move container to workspace back_and_forth";
        "${modifier}+Shift+e" = "mode $exitwarning";
      };
      startup = [
        {
          # xss-lock grabs a logind suspend inhibit lock and will use i3lock to lock the
          # screen before suspend. Use loginctl lock-session to lock your screen.
          command = "${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- i3lock --nofork -c e3da92";
          always = true;
          notification = false;
        }
        {
          command = "${pkgs.networkmanagerapplet}/bin/nm-applet";
          always = true;
          notification = false;
        }
        {
          # Startup pulseaudio controller for the system tray.
          command = "${pkgs.killall}/bin/killall --regexp pasystray ; ${pkgs.pasystray}/bin/pasystray";
          always = true;
          notification = false;
        }
        {
          # Startup dunst as a dbus notification daemon to handle dbus events (e.g. needed by mictray)
          command = "${pkgs.dunst}/bin/dunst";
          always = true;
          notification = false;
        }
        {
          command = "${pkgs.mictray}/bin/mictray";
          always = true;
          notification = false;
        }
        {
          command = "${pkgs.blueman}/bin/blueman-applet";
          always = true;
          notification = false;
        }
        # Start XDG autostart .desktop files using dex. See also
        # https://wiki.archlinux.org/index.php/XDG_Autostart
        #exec --no-startup-id dex --autostart --environment i3
      ];
      fonts = {
        names = [ "DejaVu Sans Mono for Powerline" "Font Awesome 7 Free Regular"];
        size = 12.0;
      };
      bars = [
        {
          fonts = {
            names = [ "DejaVu Sans Mono for Powerline" "Font Awesome 7 Free Regular"];
            size = 12.0;
          };
          position = "top";
          statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs config-default";
        }
      ];
    };
    extraConfig = ''
        set $exitwarning "(E)xit Session 😴(S)leep 💤(H)ibernate ⏻(P)oweroff ⟳(R)eboot 🔒(L)ock"
        mode $exitwarning {
          bindsym e exec i3-msg exit; mode "default"
          bindsym s exec systemctl suspend; mode "default"
          bindsym l exec i3lock -c e3da92; mode "default"
          bindsym p exec systemctl poweroff; mode "default"
          bindsym r exec systemctl reboot; mode "default"
          bindsym h exec systemctl hibernate; mode "default"
          bindsym Escape mode "default"
          bindsym Return mode "default"
        }

        # activate "back and forth" (when i.e. on workspace '4' just hit $mod+4 get to previous one)
        workspace_auto_back_and_forth yes

        # disable titlebar of windows, add thick borders
        default_border pixel
        new_window pixel 4
        new_float pixel 4

        # --------------------
        # layout colors
        # --------------------
        set $BLACK     #000000
        set $WHITE     #FFFFFF
        set $GRAY      #888888
        # --------------------
        set $PINK      #EF476F
        set $ORNGE     #EFCC00
        set $GREEN     #06D6A0
        set $BLUE      #118AB2
        set $BLUEDK    #073B4C
        # --------------------

        #                       bord    bg      text    indicator (split)
        client.focused          $BLUEDK $ORNGE  $BLACK  $GREEN
        client.focused_inactive $BLUEDK $GRAY   $BLACK  $BLUEDK
        client.unfocused        $BLUEDK $GRAY   $BLACK  $BLUEDK
        client.urgent           $BLUEDK $PINK   $BLACK  $BLUEDK

        ## force floating for all new windows
        #for_window [class="[.]*"] floating enable
    '';
  };

  services.picom = {
    enable = true;
    vSync = true;
  };

  programs.mpv = {
    enable = true;
    config = {
      # makes choppy video playback (due to frame pacing/clock sync problems) disappear
      video-sync = "display-resample";
    };
  };
}
