# https://flake.parts/dogfood-a-reusable-module
# The importApply argument. Use this to reference things defined locally,
# as opposed to the flake where this is imported.
# localFlake:
_localFlake:
# Regular module arguments; self, inputs, etc all reference the final user flake,
# where this module was imported.
{ config, lib, flake-parts-lib, ... }: {
  options = let inherit (lib) types;
  in {

    flake = flake-parts-lib.mkSubmoduleOptions {
      actions-nix = lib.mkOption {
        type = types.submoduleWith { modules = [ ./ci.nix ]; };
        description = ''
          Configuration of actions.
        '';
      };
    };

  };
  config = {
    perSystem = { pkgs, self', ... }: {
      # TODO: Should definition not be automatic on flake-module import?
      pre-commit.settings.hooks = {
        render-actions = {
          inherit (config.flake.actions-nix.pre-commit) enable;
          name = "render-workflows";
          pass_filenames = false;
          always_run = true;
          description =
            "Render nix-configured workflow to respective yaml file";
          entry = let renderCI = self'.packages.render-workflows;
          in "${renderCI}/bin/render-workflows";
        };
      };

      actions-nix = let
        evaluated-ci.json = pkgs.writeTextFile {
          name = "evaluated-ci.json";
          text = builtins.toJSON config.flake.actions-nix.workflows;
        };
        evaluated-ci.cmdLine = lib.cli.toGNUCommandLineShell { } {
          evaluated-ci-path = evaluated-ci.json;
        };
        evaluated-ci.generic-renderer = pkgs.writers.writePython3 "make-workflows-with" { libraries = [ pkgs.python3Packages.pyyaml ]; } ./render.py ;
        evaluated-ci.render = pkgs.writeShellScript "render-workflows" ''
          ${evaluated-ci.generic-renderer} ${evaluated-ci.cmdLine}
        '';
      in {
        inherit evaluated-ci;
      };

      # TODO: Should definition not be automatic on flake-module import?
      packages.render-workflows = config.actions-nix.evaluated-ci.render;
    };

  };
}
