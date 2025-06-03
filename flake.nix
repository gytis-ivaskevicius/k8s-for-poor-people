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
              terraform-docs
            ];

            commands = [
              {
                package = pkgs.writeShellScriptBin "tf-example" ''
                  cd $PRJ_ROOT/example && tofu $@
                '';
                name = "tf-example";
                help = "Run Terraform example";
              }
              {
                package = pkgs.writeShellScriptBin "before-commit" ''
                  tofu fmt -recursive $PRJ_ROOT
                  tflint --recursive --fix --chdir $PRJ_ROOT
                  terraform-docs markdown table $PRJ_ROOT --output-file $PRJ_ROOT/README.md --output-mode inject
                  terraform-docs markdown table $PRJ_ROOT/batteries/cloudflare-ingress --output-file $PRJ_ROOT/batteries/cloudflare-ingress/README.md --output-mode inject
                  terraform-docs markdown table $PRJ_ROOT/batteries/traefik --output-file $PRJ_ROOT/batteries/traefik/README.md --output-mode inject
                '';
                name = "before-commit";
                help = "Check code and generate docs";
              }
            ];
          };
        };

    };
}
