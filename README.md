![Dynamic NixOS Module Importer](.assets/modulon.png)

<p align="center" style="font-size: 1.5em;">Introducing Modulon 🦾</p>

<p align="center" style="font-size: 1.5em;"><em>A plug-and-play module management framework for NixOS flakes</em></p>

<br>

## Quick Start

1.  **Add the flake input:**

    ```nix
    # flake.nix
    {
      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Or your preferred channel

        # Dynamic module importer
        modulon = {
          url = "github:cig0/modulon/v0.1.0";
          # Optional: Ensure it uses the same nixpkgs instance as your config
          inputs.nixpkgs.follows = "nixpkgs";
        };

        # ... other inputs
      };

      outputs = { modulon, nixpkgs, self, ... }:
        # ... rest of your flake
    }
    ```

2.  **Use the library function in your modules list:**

    ```nix
    # In your nixosConfigurations or homeConfigurations modules list:
    let
      system = "x86_64-linux"; # Adjust for your system
      # Get the importer function for your system
      moduleImporter = modulon.lib.${system};
    in {
      # Example for NixOS:
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Your regular modules
          ./configuration.nix

          # Dynamically loaded modules from ./modules directory
          (moduleImporter { dirs = [ ./modules ]; })

          # Dynamically loaded modules from multiple directories
          # (moduleImporter { dirs = [ ./modules ./profiles ]; })

          # Example with exclusions:
          # (moduleImporter {
          #   dirs = [ ./modules ];
          #   excludePaths = [ "/tests/" "/experimental/" ];
          # })
        ];
      };
    }
    ```

## Table of Contents

<!-- Keep as is, or regenerate if sections change significantly -->
- [Quick Start](#quick-start)
- [Table of Contents](#table-of-contents)
- [Overview](#overview)
- [How It Works](#how-it-works)
- [Configuration Options](#configuration-options)
- [Default Excluded Files](#default-excluded-files)
- [Excluding Specific Modules/Paths](#excluding-specific-modulespaths)
- [Including extra modules](#including-extra-modules)
- [Testing the Flake](#testing-the-flake)
- [Contributing](#contributing)
- [License](#license)


## Overview

This dynamic module importer solves a common problem in NixOS configurations: managing a growing number of module files without manually updating import lists. It automatically discovers and imports Nix modules by analyzing file content, not just file extensions.

Key benefits:

- **Automatic Discovery**: Add new modules without updating import lists.
- **Content-Based Detection**: Identifies real modules by analyzing content patterns, avoiding accidental imports of non-module `.nix` files.
- **Flexible Configuration**: Easily specify directories to scan and paths/patterns to exclude.
- **Works Everywhere**: Compatible with NixOS, Home Manager, and other Nix module systems.

## How It Works

The core of this flake is a library function available via `modulon.lib.<system>`. When called, this function:

1.  Recursively scans the directories specified in the `dirs` option for files ending in `.nix`.
2.  Excludes files matching patterns in `excludePaths` or default excluded filenames (see below).
3.  Reads the content of the remaining `.nix` files.
4.  Checks if the file content contains common module definition patterns like `config,`, `lib,`, `options.`, `imports = [`, `}:`, etc. The specific patterns used are:
    ```nix
    modulePatterns = [
      "}:"
      "... }:"
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
    ```
5.  Returns an attribute set `{ imports = [ ... ]; }` containing the paths to the files identified as modules, ready to be included in your NixOS or Home Manager `modules` list.

## Configuration Options

The module importer function accepts an attribute set with these parameters:

| Option         | Type          | Description                                                                                                | Default |
|----------------|---------------|------------------------------------------------------------------------------------------------------------|---------|
| `dirs`         | List of paths | **Required.** Directories to scan recursively for modules.                                                 | `[]`    |
| `excludePaths` | List of strings | Path fragments/patterns to exclude from scanning (e.g., `"/tests/"`, `".git/"`, `"experimental"`).         | `[]`    |
| `extraModules` | List of paths | Specific module files to include directly. Useful for including modules within an otherwise excluded path. | `[]`    |

## Default Excluded Files

Look for **excludeModules =** in `lib/default.nix`.

## Excluding Specific Modules/Paths

You have several ways to prevent files or directories from being imported:

- Use **excludePaths**: Provide path fragments or patterns when calling the module importer function (see examples above). This is the most flexible method. Using leading/trailing slashes like "/dirname/" is recommended for excluding directories reliably.
- Rename Files: Change a module's filename extension (e.g., **.nix.dis**) so it's no longer picked.
- Directory Structure: Place modules you don't want automatically imported outside the directories listed in the dirs option.

**excludePath examples:**

Exclude any module(s) with the name `test.nix`, and any path containing `/experimental/`:

```nix
  excludePaths = [ "tests.nix" "/experimental/" ];
```

If you have a bunch of modules or paths with the same name, and want to import some while excluding others:

```nix
  excludePaths = [ "path/to/tests.nix" "path/to/experimental/" ];
```

---

**Using the exclude tag @MODULON_SKIP** _Added in v0.1.1_

Until now, the only way to skip modules was by adding them to the excludePaths list. With this tag checker, you can now easily tell Modulon to skip specific modules without needing to modify the exclusion list. :)

This is especially useful when you have a module structure like this:

```shell
.
├── ...
├── packages
│   ├── baseline.nix
│   ├── cli.nix
│   ├── default.nix
│   ├── gui.nix
│   └── tryout.nix
├── ...
└── ...
```

Without this new functionality, you'd need to do something like this in your flake:

```nix
# Dynamically import NixOS modules
(libModulon {
  ...
  excludePaths = [
    "/applications/packages/"
  ];
  extraModules = [
    "${self}/configs/nixos/modules/applications/packages/default.nix"
  ];
})
```

Just add `@MODULON_SKIP` somewhere in your module (I recommend adding it at the top), and you're good to go!


## Including extra modules

Sometimes you might need to exclude certain directories, but still want to import select modules or module collections within it; you can achieve so with the `extraModules` option:

```nix
  extraModules = [
    .configs/home-manager/modules/applications/zsh/zsh.nix # Workaround for an issue I'm having when importing some helper modules within /zsh/ that should be parsed by the 'zsh.nix' module
  ];
```

```nix
  extraModules = [
    ./testing/atuin-new-config.nix # Only import this module from the otherwise excluded '/testing/' module collection directory
  ];
```

## Testing the Flake

You can run the checks defined in tests/default.nix using the standard flake command:

```shell
nix flake check
```

**Important Note on Output**: By default, Nix only shows detailed build logs (including output from echo commands within the check script) **if a check fails**. If nix flake check runs silently and exits with status code 0 (success), it means all checks passed, even though you won't see the specific "Check passed!" messages from the script. This is standard Nix behavior to keep output clean on success.

Run `echo @?` to get the exit code of the previous command. In our context, anything else than **0** means there was an error:

```shell
$ nix flake check
warning: Git tree '/home/cig0/workdir/cig0/modulon' is dirty
warning: The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin
Use '--all-systems' to check all.

$ echo $?
0
```

**Viewing Check Output for Debugging**:

If you need to see the detailed output from a specific check script even when it succeeds (e.g., for debugging the check itself), you can force Nix to rebuild that check derivation and print its logs using nix build:

```bash
# Replace <system> with your actual system (e.g., x86_64-linux)
$ nix build .#checks.<system>.collect-simple-modules --rebuild -L
```

- `nix build .#checks.<system>.collect-simple-modules`: Targets the specific check derivation.
- `--rebuild`: Tells Nix to ignore any cached results and run the build script again.
- `-L (or --print-build-logs)`: Tells Nix to print the full build logs (stdout/stderr) for the derivation.
 
**Example Output with `--rebuild -L`**:

Running the command above should produce output similar to this (store paths will differ):

```shell
warning: Git tree '/path/to/modulon' is dirty
verify-module-collection> Expected: ["/nix/store/...-create-test-files/test-dir/module1.nix","/nix/store/...-create-test-files/test-dir/subdir/module2.nix"]
verify-module-collection> Actual:   ["/nix/store/...-create-test-files/test-dir/module1.nix","/nix/store/...-create-test-files/test-dir/subdir/module2.nix"]
verify-module-collection> Check passed!
```

This confirms the check script ran and allows you to inspect the values it printed.

## Contributing

Contributions are warmly welcome! Whether it's reporting a bug, suggesting an improvement, or submitting code, your input is valuable.

As a newcomer to Nix and NixOS myself, this project was built as part of my learning journey. While I've aimed for correctness (with lots of help!), there might still be some rough edges or areas where things could be done more idiomatically. Your feedback and contributions are especially appreciated in helping refine the code and documentation!

**How to Contribute:**

1.  **Issues:** Please open an issue to discuss bugs, propose new features, or ask questions.
2.  **Pull Requests:** Feel free to submit pull requests for fixes or improvements.
    *   The core logic resides in `lib/default.nix`.
    *   Tests are defined in `tests/default.nix`.
    *   Please ensure `nix flake check` passes before submitting.

Thank you for considering contributing!

## License

Unless otherwise stated, everything in this repo is covered by the following copyright notice:

```plaintext
Automatic NixOS Module Importer.
Copyright (C) 2025  Martín Cigorraga <cig0.github@gmail.com>

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License v3 or later, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```
