{
  description = "Expert Listing assessment development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.android_sdk.accept_license = true;
          };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # android-tools
              deno
              direnv
              docker
              # flutter
              gh
              jdk21
              postgresql
              pngcrush
              resvg
              supabase-cli
            ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
              # macOS container runtime required by `supabase start`.
              orbstack
            ];
          };
        });
    };
}
