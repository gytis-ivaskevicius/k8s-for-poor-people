{
  description = "virtual environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, flake-parts, devshell, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, system, ... }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          devshells.default = {
            packages = with pkgs; [
              k9s
              kubectl
              kubernetes-helm
              cilium-cli
              opentofu
              packer
              hcloud
              talosctl
              nixpkgs-fmt
              tflint
            ];

            commands = [
              {
                package = pkgs.writeShellScriptBin "tf-example" ''
                  cd $PRJ_ROOT/tf-example ; tofu $@
                '';
                name = "tf-example";
                help = "Run Terraform example";
              }
            ];
          };
        };

    };
}
