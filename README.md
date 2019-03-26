# Sample Rails App with Nix

This is a sample Rails application packaged with [Nix, The Purely Functional Package Manager](https://nixos.org/nix/).

## Development

You can enter the development environment by either running `nix-shell` at the project root (where there's the `default.nix`), or with [direnv](https://direnv.net/) installed then just `cd` into the project.

### Update Dependencies

If you add or removed some dependency, say after editing `Gemfile`, run `bin/update-dependencies` to get them updated.

## Install in Nix Environment

To install the application into your Nix Environment, `cd` into the project directory then run:

```bash
nix-env --install -f default.nix
```

Afterwards, you can start the application server by running `sample-rails-app-rails server`, or get into the console with `sample-rails-app-rails console`. Other executables such as `sample-rails-app-setup` are available as well.

## Use as a Package

You can also use this application as a dependent package, living under a system service such as Nginx + Passenger:

```nix
# NixOS Configuration
{ ... }:

let
  mkTheSampleRailsApp = import path/to/the/project/directory;
  app = mkTheSampleRailsApp {
    actionCable = {
      adapter = "redis";
      url = "redis://localhost:6379/0";
      channel_prefix = "sample-app-cable";
    };
  };
in {
  services.nginx = {
    virtualHosts."sample.rails.app" = {
      root = "${app}/public";
      extraConfig = ''
        passenger_enabled on;
        passenger_sticky_sessions on;
        passenger_ruby ${app.ruby}/bin/ruby;
        passenger_env_var GEM_HOME ${app.gemHome};
        passenger_env_var BUNDLE_GEMFILE ${app.bundleGemfile};
        passenger_env_var BUNDLE_PATH ${app.bundlePath};
        location /cable {
          passenger_app_group_name ${app.name}_action_cable;
          passenger_force_max_concurrent_requests_per_process 0;
        }
      '';
    };
  };
}
```
