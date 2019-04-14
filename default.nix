{
  pkgs ? import (builtins.fetchGit {
    url = "https://github.com/zetavg/nix-packages.git";
    ref = "master";
    rev = "70e88a3635bf940089d6c59ad56359067a2ef60c";
  }) { },

  ruby ? pkgs.ruby_2_5,

  name ? "sample-rails-app",
  railsEnv ? null,
  masterKey ? "b8085db5c6b1fe5cb794bc199c7a4313",
  developmentSecret ? "0d996176af46ffd1894d328d703f2b37",
  actionCableConfig ? null,
  passengerForceMaxConcurrentRequestsPerProcess ? 0,

  packagePriority ? 100,

  buildRailsApp ? pkgs.buildRailsApp,

  ...
}:

buildRailsApp {
  srcs = [
    ./Gemfile
    ./Gemfile.lock
    ./config.ru
    ./Rakefile
    ./bin
    ./config
    ./app
    ./public
  ];
  gemfile = ./Gemfile;
  lockfile = ./Gemfile.lock;
  gemset = ./gemset.nix;
  inherit
    ruby
    name
    railsEnv
    masterKey
    developmentSecret
    actionCableConfig
    packagePriority;
  extraNginxPassengerConfig = ''
    location /cable {
      passenger_app_group_name ${name}-action-cable;
      passenger_force_max_concurrent_requests_per_process ${toString passengerForceMaxConcurrentRequestsPerProcess};
    }
  '';
}
