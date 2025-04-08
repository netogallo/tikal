{ lib, ... }:
let
  inherit (lib) types;
  nahual = types.submodule {
    options = {
      nixos = lib.mkOption {
        type = types.anything;
        default = {};
        description = "The nixos configuration to be used by the nahual";
      };
    };
  };
in
  {
  	options.nahuales = lib.mkOption {
  		type = types.attrsOf nahual;
  		default = {};
  		description = "The nahuales that will exist in your universe.";
  	};
  }
