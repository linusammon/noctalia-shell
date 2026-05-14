{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.noctalia;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  generateConfig =
    format: name: value:
    if lib.isString value then
      pkgs.writeText name value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      format.generate name value;

  generateToml = generateConfig tomlFormat;
  generateJson = generateConfig jsonFormat;
in
{
  options.programs.noctalia = {
    enable = lib.mkEnableOption "Noctalia configuration";

    systemd.enable = lib.mkEnableOption "Noctalia systemd user service";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "Noctalia package to use";
    };

    config = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      default = { };
      description = "Noctalia configuration";
    };

    customPalettes = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      description = "Custom color palettes";
    };

    desktopWidgets = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      default = { };
      description = "Desktop widgets configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.noctalia = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Noctalia - A lightweight Wayland shell and bar";
        Documentation = "https://docs.noctalia.dev/v5/";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers =
          lib.optional (cfg.config != { }) "${config.xdg.configFile."noctalia/config.toml".source}"
          ++ lib.optional (
            cfg.desktopWidgets != { }
          ) "${config.xdg.stateFile."noctalia/desktop_widgets.toml".source}"
          ++ lib.mapAttrsToList (
            name: _: "${config.xdg.configFile."noctalia/palettes/${name}.json".source}"
          ) cfg.customPalettes;
      };

      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg = {
      configFile = lib.mkMerge [
        (lib.mkIf (cfg.config != { }) {
          "noctalia/config.toml".source = generateToml "config.toml" cfg.config;
        })
        (lib.mapAttrs' (
          name: palette:
          lib.nameValuePair "noctalia/palettes/${name}.json" {
            source = generateJson "${name}-palette.json" palette;
          }
        ) cfg.customPalettes)
      ];

      stateFile = lib.mkIf (cfg.desktopWidgets != { }) {
        "noctalia/desktop_widgets.toml".source = generateToml "desktop_widgets.toml" cfg.desktopWidgets;
      };
    };

    assertions = [
      {
        assertion = !cfg.systemd.enable || cfg.package != null;
        message = "programs.noctalia.package cannot be null when programs.noctalia.systemd.enable is true";
      }
    ];
  };
}
