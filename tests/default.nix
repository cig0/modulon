{
  pkgs,
  self,
  system,
}:
let
  lib = pkgs.lib; # This is nixpkgs.lib

  # Derivation to create the test directory structure
  testFilesDrv = pkgs.runCommand "create-test-files" { } ''
    mkdir -p $out/test-dir/subdir
    echo '{ config, pkgs, ... }: { services.dummy.enable = true; }' > $out/test-dir/module1.nix
    echo '{ options.myOpt = lib.mkOption { }; }' > $out/test-dir/subdir/module2.nix
    echo 'pkgs.hello' > $out/test-dir/not-a-module.nix
    echo '{ config, ... }: { environment.systemPackages = [ pkgs.git ]; }' > $out/test-dir/configuration.nix

    mkdir -p $out/skip-this/subdir
    echo '{ lib, ... }: { networking.firewall.enable = false; }' > $out/skip-this/subdir/module3.nix
  '';

  # Get the actual library function for the current system
  moduleCollectorFunc = self.lib.${system};

  # Call the function with the test directory path
  actualResult = moduleCollectorFunc {
    dirs = [ "${testFilesDrv}/test-dir" ];
    excludePaths = [ "/skip-this/" ];
  };

  # Define the expected list of import paths relative to the testFilesDrv output
  expectedRelativeImports = [
    "test-dir/module1.nix"
    "test-dir/subdir/module2.nix"
  ];

  # Construct the full expected paths
  expectedImports = map (p: "${testFilesDrv}/${p}") expectedRelativeImports;

  # Sort both lists using the correct function: lib.lists.sort
  sortedActualImports = lib.lists.sort builtins.lessThan actualResult.imports;
  sortedExpectedImports = lib.lists.sort builtins.lessThan expectedImports;

in
{
  # The actual check derivation: compares the results
  collect-simple-modules =
    pkgs.runCommand "verify-module-collection"
      {
        nativeBuildInputs = [ pkgs.diffutils ];
        expectedJson = builtins.toJSON sortedExpectedImports;
        actualJson = builtins.toJSON sortedActualImports;
      }
      ''
        echo "Expected: $expectedJson"
        echo "Actual:   $actualJson"

        if [ "$actualJson" = "$expectedJson" ]; then
          echo "Check passed!"
          touch $out # Signal success
        else
          echo "Check failed! Lists differ."
          echo "$expectedJson" > expected.json
          echo "$actualJson" > actual.json
          diff --color=always expected.json actual.json || true
          exit 1
        fi
      '';

  # --- Add more checks here following a similar pattern ---
}
