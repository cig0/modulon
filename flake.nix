{
  description = "Modulon - A plug-and-play module management framework for your NixOS flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      flake-utils,
      nixpkgs,
      self,
    }:
    # Use flake-utils to generate outputs for standard systems
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib; # Get lib for the current system

        # Define the function that imports default.nix and passes arguments.
        # default.nix expects { lib } and then an attribute set { dirs, excludePaths, extraModules }
        # This function takes that attribute set as 'collectorArgs'.
        moduleCollector = collectorArgs: import ./lib { inherit lib; } collectorArgs;

      in
      {
        # Library function exposed to users.
        # Users will call: self.lib.x86_64-linux { dirs = ["/path"]; excludePaths = [...]; }
        # It returns an attribute set: { imports = [ ... ]; }
        lib = moduleCollector;

        # Checks are now imported from a separate file.
        # We pass 'pkgs', 'self', and 'system' so the checks file has access to necessary packages,
        # the system architecture, and the flake's own outputs (like self.lib).
        checks = import ./tests { inherit pkgs self system; };

        # Development shell
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.fx # Hnady CLI JSON visualizer
            pkgs.jq # Useful for inspecting JSON output in checks
            pkgs.nixpkgs-fmt # For formatting Nix code
          ];
        };

        # Formatter definition
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
