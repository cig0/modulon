{ lib }:
{
  dirs ? [ ],
  excludePaths ? [ ],
  extraModules ? [ ],
  ...
}:
let
  # List of common configuration filenames to exclude automatically
  excludeModules = [
    "configuration.nix"
    "flake.nix"
    "hardware-configuration.nix"
    "home.nix"
    ".git/"
    "/tests/"
  ];

  # Heuristic patterns to identify potential Nix modules based on content.
  # This is not foolproof but helps filter out non-module .nix files.
  modulePatterns = [
    "... }:"
    "}:"
    "config,"
    "lib,"
    "inputs,"
    "nixosConfig,"
    "pkgs,"
    "config = {"
    "home = {"
    "imports = ["
    "options."
  ];

  # Function to collect modules from a directory
  collectModules =
    {
      dir,
      excludePaths ? [ ],
      moduleDetection ? modulePatterns,
    }:
    let
      # Check if a path contains any of the special paths that should be excluded
      isExcludedPath =
        path:
        let
          strPath = toString path;
        in
        builtins.any (excludePath: lib.strings.hasInfix excludePath strPath) excludePaths;

      # Check if a file is likely a Nix module based on content patterns
      isNixModule =
        file:
        let
          # Read file content once for efficiency
          content = builtins.readFile file;
        in
        # Check if any pattern exists in the content
        !(lib.strings.hasInfix "# @MODULON_SKIP" content)
        && builtins.any (pattern: lib.strings.hasInfix pattern content) moduleDetection;

      # Recursively collect .nix files from a directory
      collectModulesRec =
        path:
        let
          items = builtins.readDir path; # Read the directory contents

          processItem =
            name: type:
            let
              fullPath = path + "/${name}";
            in
            if type == "regular" && lib.hasSuffix ".nix" name && !(lib.elem name excludeModules) then
              # It's a potentially relevant .nix file
              if isExcludedPath fullPath then
                [ ] # Skip files in excluded paths
              else
                # Return path only if content matches module patterns
                lib.optional (isNixModule fullPath) fullPath
            else if type == "directory" then
              # Recurse into subdirectories
              collectModulesRec fullPath
            else
              [ ]; # Ignore other file types

          # Map over all items and flatten the resulting list of lists
          itemLists = lib.mapAttrsToList processItem items;
        in
        lib.flatten itemLists; # Flatten happens here now
    in
    collectModulesRec dir;
in
{
  # The final list of module paths to be imported
  imports =
    lib.flatten (
      # Map over each directory and collect modules
      builtins.map (
        dir:
        collectModules {
          inherit dir excludePaths;
        }
      ) dirs
    )
    # Append any explicitly provided extra modules
    ++ extraModules;
}
