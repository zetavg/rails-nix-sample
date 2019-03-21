{
  name ? "SampleRailsApp",
  masterKey ? "b8085db5c6b1fe5cb794bc199c7a4313",
  developmentSecret ? "0d996176af46ffd1894d328d703f2b37",
  fetchFromGitHub ? (import <nixpkgs> { }).fetchFromGitHub,
  ...
}:

let
  pkgs = fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "9b3e5a3aab728e7cea2da12b6db300136604be3a";
    sha256 = "17hxhyqzzlqcpd4mksnxcbq233s8q8ldxnp7n0g21v1dxy56wfhk";
  };
in with import pkgs { }; let
  ruby = ruby_2_5;
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
  bundleConfig = ''
    ---
    BUNDLE_GEMFILE: "${bundleGemfile}"
    BUNDLE_PATH: "${bundlePath}"
  '';
in stdenv.mkDerivation {
  inherit name;
  meta = {
    priority = 10;
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
    rsync -a "$src/." "$TMPDIR/" \
      --exclude='/.git' \
      --exclude='/.envrc' \
      --exclude='/.ruby-version' \
      --exclude='/.tool-versions' \
      --filter='dir-merge,- .gitignore'
    chmod -R +w $TMPDIR
  '';
  postPatch = ''
    patchShebangs .
  '';
  configurePhase = ''
    mkdir -p .bundle
    echo '${bundleConfig}' > .bundle/config

    echo "require 'etc'; ENV['BOOTSNAP_CACHE_DIR'] = \"/tmp/rails-bootsnap-cache-#{Etc.getlogin}-$(basename $out)\"" | cat - config/boot.rb > temp && mv temp config/boot.rb

    printf "${developmentSecret}" > tmp/development_secret.txt
    printf "${masterKey}" > config/master.key
  '';
  buildPhase = ''
    BUNDLE_GEMFILE=${bundleGemfile} BUNDLE_PATH=${bundlePath} bin/rails assets:precompile
  '';
  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';
  preFixup = ''
    cd $out
      awk -i inplace "NR==1 {print \"ENV['GEM_HOME'] = '${gemHome}'\"; print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; print \"Gem.clear_paths\"} NR!=0" "config.ru"
    cd -
    cd $out/bin
    for file in *; do
      awk -i inplace "NR==1 {print; print \"ENV['GEM_HOME'] = '${gemHome}'\"; print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; print \"Gem.clear_paths\"} NR!=1" "$file"
      mv "$file" "${name}-$file"
    done
    cd -
  '';
} // { inherit ruby gemHome bundleGemfile bundlePath; }
