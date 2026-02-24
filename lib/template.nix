{ lib, tikal, pkgs, ... }:
let
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal.xonsh) xsh;
  log' = tikal.prelude.log.add-context { path = ./template.nix; };
  to-args-string = args:
    let
      args-def = lib.concatStringsSep "," args;
    in
      "{ ${args-def} }"
  ;
  default-get-call-context = { context, content }:
    {
      args = lib.attrNames context;
      call = file: import file;
    }
  ;
  template-overridable = { get-call-context }: path: context:
    let
      content = lib.readFile path;
      body = "''\n${content}\n''";
      call-context = get-call-context { inherit context content; };
      args = to-args-string call-context.args;
      target' = pkgs.writeTextFile {
        name = "${builtins.baseNameOf path}-template.nix";
        text = ''
        ${args}:
        ${body}
        '';
      };
      target = log'.log-info "Template path ${target'}" target';
    in
      call-context.call "${target}" context
  ;
  template =
    lib.makeOverridable
    template-overridable
    { get-call-context = default-get-call-context; }
  ;

  nix-post-validation =
    pkgs.writeScript
    "flake-validator" 
    ''
    export HOME=$(mktemp -d)
    
    # Redirect Nix state directories to the temporary build folder
    export NIX_STATE_DIR=$TMPDIR/nix/var/nix
    export NIX_CONF_DIR=$TMPDIR/nix/etc/nix
    export USER=nobody

    nix-instantiate --parse $1
    mv $1 $2
    ''
  ;

  with-python-template-overridable = { post-validation }: path: subs:
  let
    result = xsh.run-command {
      name = "template-xsh-builder";
      vars = { inherit subs path; };
      script = { vars, ... }:
      ''
      import re
      from string import Template

      class FlexibleERPTemplate(Template):
        delimiter = '<%'
        # Updated pattern to handle optional whitespace
        pattern = r''''
          <%\s*(?:(?P<escaped>%)|(?P<named>[_a-z][_a-z0-9]*)|{(?P<braced>[_a-z][_a-z0-9]*)}|(?P<invalid>))
          \s*%>  # Allow whitespace before closing %>
        ''''

      subs = ${vars.subs}

      with open(${vars.path}, 'r') as f:
        template_text = f.read()

      template = FlexibleERPTemplate(template_text)

      try:
        result = template.substitute(**subs)
      except KeyError as k:
        msg = str(k)
        raise Exception(f"Template substitution failed due to missing keys:\n\n{msg}")

      tmp_dir = $TMPDIR
      tmp = f"{ tmp_dir }/tmp"

      with open(tmp, 'w') as tmp_result:
        tmp_result.write(result)

      ${pkgs.bash}/bin/sh ${post-validation} @(tmp) $out
      '';
    };
  in
    log'.log-info "Template output for '${path}' is '${result}'" result
  ;

  template-nix =
    lib.makeOverridable
    with-python-template-overridable
    { post-validation = nix-post-validation; }
  ;
in
  with-tests
  {
    inherit template template-nix;
  }
  {
    tikal.template = {
      "It applies substitutions to nix expressions" = { _assert, ... }:
        let
          tpl =
            pkgs.writeText
            "test"
            ''hello, <% who %>''
          ;
          result = builtins.readFile (template-nix tpl { who = "me"; });
        in
          _assert.eq "hello, me" result
      ;
    };
  }
