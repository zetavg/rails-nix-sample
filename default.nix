{
  name ? "sample-rails-app",
  railsEnv ? null,
  masterKey ? "b8085db5c6b1fe5cb794bc199c7a4313",
  developmentSecret ? "0d996176af46ffd1894d328d703f2b37",
  actionCableConfig ? null,
  packagePriority ? 100,
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "zetavg";
    repo = "nix-packages";
    rev = "a1078f6795ed3f5cd0ae29c86acbd6ca58107ee0";
    sha256 = "0r1khcrbfdlpgv8w710mr1rnzdw89177r8hp3x86dfx5wp5gdnbd";
  }) { },
  ruby ? pkgs.ruby_2_5,
  stdenv ? pkgs.stdenv,
  coreutils ? pkgs.coreutils,
  gnused ? pkgs.gnused,
  rsync ? pkgs.rsync,
  bundlerEnv ? pkgs.bundlerEnv,
  bundler ? pkgs.bundler,
  bundix ? pkgs.bundix,
  buildRailsApp ? pkgs.buildRailsApp,
  ...
}:

buildRailsApp {
  src = ./.;
  gemfile = ./Gemfile;
  lockfile = ./Gemfile.lock;
  gemset = ./gemset.nix;
  inherit
    name
    railsEnv
    masterKey
    developmentSecret
    actionCableConfig
    packagePriority
    ruby
    stdenv
    coreutils
    gnused
    rsync
    bundlerEnv
    bundler
    bundix;
}
