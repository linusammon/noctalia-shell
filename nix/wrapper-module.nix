{
  pkgs,
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    generatedConfigDirname = lib.mkOption {
      type = lib.types.str;
      default = "${config.binName}-config";
      description = "Name of the directory which is created as the NOCTALIA_CONFIG_HOME in the wrapper output";
      apply = x: lib.removePrefix "/" (lib.removeSuffix "/" x);
    };
    configDrvOutput = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "Name of the derivation output where the generated NOCTALIA_CONFIG_HOME is output to.";
    };
    configPlaceholder = lib.mkOption {
      type = lib.types.str;
      default = "${placeholder config.configDrvOutput}/${config.generatedConfigDirname}";
      readOnly = true;
      description = "The placeholder for the generated config directory.";
    };
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith { typeName = "TOML"; };
      default = { };
      example = lib.literalExpression ''
        {
          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Catppuccin";
          };

          wallpaper = {
            enabled = true;
            default.path = "/path/to/wallpapers/wallpaper.png";
          };
        }
      '';
      description = ''
        Attribute set of Noctalia configuration options,
        to be written to `~/.config/noctalia/config.toml`.

        See <https://docs.noctalia.dev/v5/configuration/>.
      '';
    };
    customPalettes = lib.mkOption {
      type = lib.types.attrsOf (
        wlib.types.structuredValueWith {
          typeName = "JSON";
          nullable = false;
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          "my-palette" = {
            colors = {
              primary = "#ff0000";
              secondary = "#00ff00";
            };
          };
        }
      '';
      description = ''
        Custom color palette options as an attribute set,
        to be written to `~/.config/noctalia/colors.json`.

        See <https://docs.noctalia.dev/v5/theming/#custom_palette>.
      '';
    };
  };
  config.package = lib.mkDefault null;
  config.env.NOCTALIA_CONFIG_HOME = "${placeholder config.configDrvOutput}/";
  config.constructFiles = lib.mkMerge [
    (lib.mkIf (config.settings != { }) {
      settings = {
        relPath = "noctalia/config.toml";
        output = config.configDrvOutput;
        content = builtins.toJSON config.settings;
        builder = ''${lib.getExe pkgs.remarshal} -f json -i "$1" -t toml -o "$2"'';
      };
    })
    (lib.mkIf (config.customPalettes != { }) (
      builtins.listToAttrs (
        lib.mapAttrsToList (name: palette: {
          name = "palette-${name}";
          value = {
            relPath = "noctalia/palettes/${name}.json";
            output = config.configDrvOutput;
            content = builtins.toJSON palette;
          };
        }) config.customPalettes
      )
    ))
  ];
}
