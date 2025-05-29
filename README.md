[<img src="https://github.com/user-attachments/assets/0e1a77ac-6739-4153-bd24-abd3a5e143f5" width="200px" alt="logo" />](https://github.com/nix-darwin/nix-darwin)

# nix-darwin

[![Test](https://github.com/nix-darwin/nix-darwin/actions/workflows/test.yml/badge.svg)](https://github.com/nix-darwin/nix-darwin/actions/workflows/test.yml)

Nix modules for darwin, `/etc/nixos/configuration.nix` for macOS.

This project aims to bring the convenience of a declarative system approach to macOS.
nix-darwin is built up around [Nixpkgs](https://github.com/NixOS/nixpkgs), quite similar to [NixOS](https://nixos.org/).

## Prerequisites

The only prerequisite is a Nix implementation; both Nix and Lix are supported.

As the official Nix installer does not include an automated uninstaller, and manual uninstallation on macOS is a complex process, we recommend using one of the following installers instead:

* The [Nix installer from Determinate Systems](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#determinate-nix-installer) is only recommended for use with flake-based setups.
  It can install one of two distributions of Nix:

  * To install the **recommended** vanilla upstream [Nix](https://nixos.org), you will need to explicitly say `no` when prompted to install `Determinate Nix`.

  * When run with the `--determinate` flag, it will install the [Determinate](https://docs.determinate.systems/) distribution.
    As Determinate manages the Nix installation itself, you will need to set `nix.enable = false;` in your configuration to disable nix-darwin’s own Nix management.
    Some nix-darwin functionality that relies on managing the Nix installation, like the `nix.*` options to adjust Nix settings or configure a Linux builder, will be unavailable.

* The [Lix installer](https://lix.systems/install/#on-any-other-linuxmacos-system) supports both flake-based and channel-based setups.



## Getting started

Despite being an experimental feature in Nix currently, nix-darwin recommends that beginners use flakes to manage their nix-darwin configurations.

<details>
<summary>Flakes (Recommended for beginners)</summary>

### Step 1. Creating `flake.nix`

<details>
<summary>Getting started from scratch</summary>
<p></p>

If you don't have an existing `configuration.nix`, you can run the following commands to generate a basic `flake.nix` inside `/etc/nix-darwin`:

```bash
sudo mkdir -p /etc/nix-darwin
sudo chown $(id -nu):$(id -ng) /etc/nix-darwin
cd /etc/nix-darwin

# To use Nixpkgs unstable:
nix flake init -t nix-darwin/master
# To use Nixpkgs 24.11:
nix flake init -t nix-darwin/nix-darwin-24.11

sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix
```

Make sure to change `nixpkgs.hostPlatform` to `aarch64-darwin` if you are using Apple Silicon.

</details>

<details>
<summary>Migrating from an existing configuration.nix</summary>
<p></p>

Add the following to `flake.nix` in the same folder as `configuration.nix`:

```nix
{
  description = "John's darwin system";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-24.11-darwin` to use Nixpkgs 24.11.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-24.11` to use Nixpkgs 24.11.
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }: {
    darwinConfigurations."Johns-MacBook" = nix-darwin.lib.darwinSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
```

Make sure to replace `Johns-MacBook` with your hostname which you can find by running `scutil --get LocalHostName`.

Make sure to set `nixpkgs.hostPlatform` in your `configuration.nix` to either `x86_64-darwin` (Intel) or `aarch64-darwin` (Apple Silicon).

</details>

### Step 2. Installing `nix-darwin`

Unlike NixOS, `nix-darwin` does not have an installer, you can just run `darwin-rebuild switch` to install nix-darwin. As `darwin-rebuild` won't be installed in your `PATH` yet, you can use the following command:

```bash
# To use Nixpkgs unstable:
sudo nix run nix-darwin/master#darwin-rebuild -- switch
# To use Nixpkgs 24.11:
sudo nix run nix-darwin/nix-darwin-24.11#darwin-rebuild -- switch
```

### Step 3. Using `nix-darwin`

After installing, you can run `darwin-rebuild` to apply changes to your system:

```bash
sudo darwin-rebuild switch
```

#### Using flake inputs

Inputs from the flake can also be passed into `darwinSystem`. These inputs are then
accessible as an argument `inputs`, similar to `pkgs` and `lib`, inside the configuration.

```nix
# in flake.nix
nix-darwin.lib.darwinSystem {
  modules = [ ./configuration.nix ];
  specialArgs = { inherit inputs; };
}
```

```nix
# in configuration.nix
{ pkgs, lib, inputs }:
# inputs.self, inputs.nix-darwin, and inputs.nixpkgs can be accessed here
```
</details>

<details>
<summary>Channels</summary>

### Step 1. Creating `configuration.nix`

Copy the [simple](./modules/examples/simple.nix) example to `/etc/nix-darwin/configuration.nix`.

### Step 2. Adding `nix-darwin` channel

```bash
# If you use Nixpkgs unstable (the default):
sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/master.tar.gz darwin
# If you use Nixpkgs 24.11:
sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/nix-darwin-24.11.tar.gz darwin

sudo nix-channel --update
```

### Step 3. Installing `nix-darwin`

To install `nix-darwin`, you can just run `darwin-rebuild switch` to install nix-darwin. As `darwin-rebuild` won't be installed in your `PATH` yet, you can use the following command:

```bash
nix-build '<darwin>' -A darwin-rebuild
sudo ./result/bin/darwin-rebuild switch -I darwin-config=/etc/nix-darwin/configuration.nix
```

### Step 4. Using `nix-darwin`

After installing, you can run `darwin-rebuild` to apply changes to your system:

```bash
sudo darwin-rebuild switch
```

### Step 5. Updating `nix-darwin`

You can update Nixpkgs and `nix-darwin` using the following command:

```bash
sudo nix-channel --update
```
</details>

## Documentation

`darwin-help` will open up a local copy of the reference documentation, it can also be found online [here](https://nix-darwin.github.io/nix-darwin/manual/index.html).

The documentation is also available as manpages by running `man 5 configuration.nix`.

## Uninstalling

To run the latest version of the uninstaller, you can run the following command:

```
sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
```

If that command doesn't work for you, you can try the locally installed uninstaller:

```
sudo darwin-uninstaller
```

## Tests

There are basic tests that run sanity checks for some of the modules,
you can run them like this:

```bash
# run all tests
nix-build release.nix -A tests
# or just a subset
nix-build release.nix -A tests.environment-path
```

## Contributing

Let's make Nix on macOS awesome!

Don't hesitate to contribute modules or open an issue.

To build your configuration with local changes you can run this. This
flag can also be used to override darwin-config or nixpkgs, for more
information on the `-I` flag look at the nix-build [manpage](https://nixos.org/manual/nix/stable/command-ref/nix-build.html).

```bash
sudo darwin-rebuild switch -I darwin=.
```

If you're adding a module, please add yourself to `meta.maintainers`, for example

```nix
  meta.maintainers = [
    lib.maintainers.alice or "alice"
  ];

  options.services.alicebot = # ...
```

The `or` operator takes care of graceful degradation when `lib` from Nixpkgs
goes out of sync.

Feel free to contact us on Matrix if you have questions:
* **User support:** [#macos:nixos.org](https://matrix.to/#/#macos:nixos.org)
* **Development discussion:** [#nix-darwin-dev:nixos.org](https://matrix.to/#/#nix-darwin-dev:nixos.org)
