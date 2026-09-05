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
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            rustToolchain
            pkg-config

            # Native libraries needed by GTK/tray icon and reqwest/native-tls.
            gtk3
            libayatana-appindicator
            openssl
            dbus

            # Linux windowing deps used by egui/winit (x11 path).
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
            xorg.libXext
            xorg.libxcb
            libxkbcommon

            # Common runtime dependency for GUI stacks.
            libGL
          ];

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
