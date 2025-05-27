{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chunkwm;
  plugins = [ "border" "ffm" "tiling" ];
in

{
  options = {
    services.chunkwm.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the chunkwm window manager.";
    };

    services.chunkwm.package = mkOption {
      type = types.package;
      example = literalExpression "pkgs.chunkwm";
      description = "This option specifies the chunkwm package to use.";
    };

    services.chunkwm.hotload = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable hotload.";
    };

    services.chunkwm.extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''chunkc tiling::rule --owner Emacs --state tile'';
      description = "Additional commands for {file}`chunkwmrc`.";
    };

    services.chunkwm.plugins.dir = mkOption {
      type = types.path;
      default = "/run/current-system/sw/lib/chunkwm/plugins";
      description = "Chunkwm Plugins directory.";
    };

    services.chunkwm.plugins.list = mkOption {
      type = types.listOf (types.enum plugins);
      default = plugins;
      example = ["tiling"];
      description = "Chunkwm Plugins to enable.";
    };

    services.chunkwm.plugins."border".config = mkOption {
      type = types.lines;
      default = ''chunkc set focused_border_color   0xffc0b18b'';
      description = "Optional border plugin configuration.";
    };

    services.chunkwm.plugins."tiling".config = mkOption {
      type = types.lines;
      example = ''chunkc set global_desktop_mode   bsp'';
      description = "Optional tiling plugin configuration.";
    };
  };

  config = mkIf cfg.enable {

    services.chunkwm.plugins."border".config = mkDefault ''
      chunkc set focused_border_color          0xffc0b18b
      chunkc set focused_border_width          4
      chunkc set focused_border_radius         0
      chunkc set focused_border_skip_floating  0
    '';

    services.chunkwm.plugins."tiling".config = mkDefault ''
      chunkc set global_desktop_mode           bsp
      chunkc set 2_desktop_mode                monocle
      chunkc set 5_desktop_mode                float

      chunkc set 1_desktop_tree                ~/.chunkwm_layouts/dev_1

      chunkc set global_desktop_offset_top     25
      chunkc set global_desktop_offset_bottom  15
      chunkc set global_desktop_offset_left    15
      chunkc set global_desktop_offset_right   15
      chunkc set global_desktop_offset_gap     15

      chunkc set 1_desktop_offset_top          25
      chunkc set 1_desktop_offset_bottom       15
      chunkc set 1_desktop_offset_left         15
      chunkc set 1_desktop_offset_right        15
      chunkc set 1_desktop_offset_gap          15

      chunkc set 3_desktop_offset_top          15
      chunkc set 3_desktop_offset_bottom       15
      chunkc set 3_desktop_offset_left         15
      chunkc set 3_desktop_offset_right        15

      chunkc set desktop_padding_step_size     10.0
      chunkc set desktop_gap_step_size         5.0

      chunkc set bsp_spawn_left                1
      chunkc set bsp_optimal_ratio             1.618
      chunkc set bsp_split_mode                optimal
      chunkc set bsp_split_ratio               0.66

      chunkc set window_focus_cycle            monitor
      chunkc set mouse_follows_focus           1
      chunkc set window_float_next             0
      chunkc set window_float_center           1
      chunkc set window_region_locked          1
    '';

    environment.etc."chunkwmrc".source = pkgs.writeScript "etc-chunkwmrc" (
      ''
        #!/bin/bash
        chunkc core::plugin_dir ${toString cfg.plugins.dir}
        chunkc core::hotload ${if cfg.hotload then "1" else "0"}
      ''
        + concatMapStringsSep "\n" (p: "# Config for chunkwm-${p} plugin\n"+cfg.plugins.${p}.config or "# Nothing to configure") cfg.plugins.list
        + concatMapStringsSep "\n" (p: "chunkc core::load "+p+".so") cfg.plugins.list
        + "\n" + cfg.extraConfig
    );

    launchd.user.agents.chunkwm = {
      path = [ cfg.package config.environment.systemPath ];
      serviceConfig.ProgramArguments = [ "${getOutput "out" cfg.package}/bin/chunkwm" ]
        ++ [ "-c" "/etc/chunkwmrc" ];
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive = true;
      serviceConfig.ProcessType = "Interactive";
      managedBy = "services.chunkwm.enable";
    };

  };
}
