{
  name ? "sample-rails-app",
  masterKey ? "b8085db5c6b1fe5cb794bc199c7a4313",
  developmentSecret ? "0d996176af46ffd1894d328d703f2b37",
  actionCableConfig ? { adapter = "async"; },
  packagePriority ? 100,
  nixpkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "9b3e5a3aab728e7cea2da12b6db300136604be3a";
    sha256 = "17hxhyqzzlqcpd4mksnxcbq233s8q8ldxnp7n0g21v1dxy56wfhk";
  }) { },
  stdenv ? nixpkgs.stdenv,
  lib ? nixpkgs.lib,
  writeText ? nixpkgs.writeText,
  ruby ? nixpkgs.ruby_2_5,
  bundlerEnv ? nixpkgs.bundlerEnv,
  coreutils ? nixpkgs.coreutils,
  rsync ? nixpkgs.rsync,
  bundler ? nixpkgs.bundler,
  bundix ? nixpkgs.bundix,
  ...
}:

let
  functions = import ./functions.nix { inherit lib; };
  bundleEnv = bundlerEnv {
    name = "${name}-bundlerEnv";
    inherit ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
  gemHome = "${bundleEnv.outPath}/${bundleEnv.ruby.gemPath}";
  bundleGemfile = "${bundleEnv.confFiles.outPath}/Gemfile";
  bundlePath = gemHome;
  bundleConfig = writeText "config" ''
    ---
    BUNDLE_GEMFILE: "${bundleGemfile}"
    BUNDLE_PATH: "${bundlePath}"
  '';
  actionCableConfigFile = if actionCableConfig != null then
    writeText "cable.yml" (functions.toYaml {
      development = actionCableConfig;
      test = actionCableConfig;
      production = actionCableConfig;
    })
  else null;
in with lib; stdenv.mkDerivation {
  inherit name;
  meta = {
    priority = packagePriority;
  };
  buildInputs = [
    coreutils
    rsync
    ruby
    bundler
    bundix
    bundleEnv
  ];
  src = ./.;
  shellHook = ''
    export BUNDLE_GEMFILE=${bundleGemfile}
    export BUNDLE_PATH=${bundlePath}
  '';
  unpackPhase = ''
    # Copy the source code
    rsync -a "$src/." "$TMPDIR/" \
      --exclude='/.git' \
      --exclude='/.envrc' \
      --exclude='/.ruby-version' \
      --exclude='/.tool-versions' \
      --filter='dir-merge,- .gitignore'
    # Add read permission to the unpacked source, which is read-only by default
    chmod -R +w $TMPDIR
  '';
  postPatch = ''
    patchShebangs .
  '';
  configurePhase = ''
    # Write bundle config
    mkdir -p .bundle
    cp -f ${bundleConfig} .bundle/config
    # Let Bootsnap place it's cache dir under /tmp rather then [app-dir]/tmp which
    # will not be writeable
    echo "require 'etc'; ENV['BOOTSNAP_CACHE_DIR'] = \"/tmp/rails-bootsnap-cache-#{Etc.getlogin}-$(basename $out)\"" | cat - config/boot.rb > temp && mv temp config/boot.rb
    '' + optionalString (developmentSecret != null) ''
      printf ${developmentSecret} > tmp/development_secret.txt
    '' + optionalString (masterKey != null) ''
      printf ${masterKey} > config/master.key
    '' + optionalString (actionCableConfigFile != null) ''
      cp -f ${actionCableConfigFile} config/cable.yml
    '';
  buildPhase = ''
    # Compile static assets
    BUNDLE_GEMFILE=${bundleGemfile} BUNDLE_PATH=${bundlePath} RAILS_ENV=production bin/rails assets:precompile
  '';
  installPhase = ''
    # Copy all the stuff to the out directory
    mkdir -p $out
    cp -r . $out
    # Pre-create the directories that Rails may attempt to create on every startup
    mkdir -p $out/tmp/cache
    mkdir -p $out/tmp/pids
    mkdir -p $out/tmp/sockets
  '';
  preFixup = ''
    # Explicity set RubyGems and Bundler config in config.ru
    cd $out
      awk -i inplace "NR==1 {print \"ENV['GEM_HOME'] = '${gemHome}'\"; print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; print \"Gem.clear_paths\"} NR!=0" "config.ru"
    cd -
    # Explicity set RubyGems and Bundler config in every binstub and Ruby scripts
    cd $out/bin
    for file in *; do
      awk -i inplace "NR==1 {print; print \"ENV['GEM_HOME'] = '${gemHome}'\"; print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; print \"Gem.clear_paths\"} NR!=1" "$file"
    done
    cd -
    # Prefix every executable in bin/ so there're not going to conflict with other packages
    cd $out/bin
    for file in *; do
      mv "$file" "${name}-$file"
    done
    cd -
  '';
} // { inherit ruby gemHome bundleGemfile bundlePath; }
