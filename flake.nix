{
  description = "inxm-local development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        runtimeLibs = with pkgs; [
          # Native libraries needed by GTK/tray icon and reqwest/native-tls.
          gtk3
          libayatana-appindicator
          openssl
          dbus

          # Linux windowing deps used by egui/winit (x11 path).
          libx11
          libxcursor
          libxi
          libxrandr
          libxext
          libxcb
          libxkbcommon

          # Common runtime dependency for GUI stacks.
          libGL
        ];

        build = pkgs.rustPlatform.buildRustPackage {
          pname = "inxm-local";
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          # Upstream tests require network/TLS system trust + python in-path; skip in
          # package builds so `nix build .#build` behaves like a release artifact build.
          doCheck = false;

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          buildInputs = runtimeLibs;
        };

        run = pkgs.writeShellScriptBin "inxm-local-run" ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"
          op account get --account my
          if [ $? -ne 0 ]; then
            eval $(op signin --account my)
          fi

          export AZURE_OPENAI_API_KEY=$(op item get "Azure OpenAI API Key" --vault Private --fields label=key --format json | jq -r '.value')

          exec ${build}/bin/inxm-local "$@"
        '';
      in
      {
        packages = {
          default = build;
          build = build;
          run = run;
        };

        apps = {
          default = flake-utils.lib.mkApp { drv = run; };
          run = flake-utils.lib.mkApp { drv = run; };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            rustToolchain
            pkg-config
          ] ++ runtimeLibs;

          env = {
            RUST_BACKTRACE = "1";
          };

          shellHook = ''
            echo "nix develop ready: $(rustc --version) / $(cargo --version)"
            echo "Build with: cargo build"
          '';
        };
      });
}
