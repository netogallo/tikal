{ tikal, lib, ... }:
let
  inherit (tikal.prelude) do store-path-to-key;
  inherit (tikal.prelude.python) is-valid-python-identifier store-path-to-python-identifier;
  inherit (tikal.xonsh) xsh;
in
  {
    nahual-sync-script =
      {
        name
      , description
      , each-nahual
      }:
      let
        valid-name =
          if is-valid-python-identifier name
          then name
          else throw "The script name must be a valid python module name. Got '${name}'"
        ;
        each-nahual-script = xsh.write-script {
          name = "${valid-name}.xsh";
          vars = {};
          script = { vars, ... }: ''
            all_nahuales = universe.nahuales
            for nahual_name, nahual_spec in all_nahuales.items():
              for client, client_spec in nahual_spec.items():
                #public_spec = client_spec.public[quine_uid]
                #private_spec = client_spec.private[quine_uid]
                #msg = f"private dir {private_spec.root}, public dir {public_spec.root}"
                #print(msg)
                print(f"done {quine_uid}")
          '';
        };
        uid = store-path-to-key "${each-nahual-script}";
        text = { universe, ...}:
          let
            fn-name = store-path-to-python-identifier uid;
            wrapper-script = xsh.write-script {
              name = "${name}-wrapper.xsh";
              vars = { inherit universe; };
              script = { vars, ... }: ''
                def ${fn-name}(universe):
                  global quine_uid
                  quine_uid = "${uid}"
                  # todo:
                  # Check if tikal folder already exits. Skip if so.
                  # Otherwise, create the folder
                  source ${each-nahual-script}

                ${fn-name}(${vars.universe})
              '';
            };
          in
            ''
              def __main__(tikal):
                tikal.log_info(f"Running sync hook '${valid-name}'")
                source ${wrapper-script}
            ''
        ;
      in
        {
          name = valid-name;
          inherit text;
        }
    ;
  }
