{ config, lib, pkgs, ... }:

let
  cfg = config.myOptions.configMerge;
in
{
  options.myOptions.configMerge = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = { };
    description = ''
      Attribute set where keys are file paths and values are settings to merge.
      Example:
      myOptions.configMerge."/etc/some.json" = {
        "key1" = "value1";
        "key2.subkey" = true;
      };
    '';
  };

  config = lib.mkIf (cfg != { }) {
    system.activationScripts.configMerge = {
      supportsDryActivation = true;
      text =
        let
          dasel = "${pkgs.dasel}/bin/dasel";

          # Function to generate dasel commands for a single file
          genCmds = path: settings:
            let
              # Infer format from extension
              inferFormat = p:
                let
                  ext = lib.last (lib.splitString "." p);
                in
                  if ext == "json" then "json"
                  else if ext == "yaml" || ext == "yml" then "yaml"
                  else if ext == "toml" then "toml"
                  else if ext == "xml" then "xml"
                  else if ext == "ini" || ext == "conf" then "ini"
                  else "plain";

              actualFormat = inferFormat path;

              # Map Nix types to dasel types
              mkPut = selector: value:
                let
                  type = builtins.typeOf value;
                  daselType =
                    if type == "int" then "int"
                    else if type == "string" then "string"
                    else if type == "bool" then "bool"
                    else if type == "float" then "float"
                    else if type == "list" then "json"
                    else if type == "set" then "json"
                    else "string";

                  valStr = if type == "list" || type == "set" then builtins.toJSON value else toString value;
                in
                  "${dasel} put -f ${path} -r ${actualFormat} -s '${selector}' -t ${daselType} -v '${valStr}'";

              # Recursively flatten the attribute set into dot-notated selectors
              flatten = prefix: attrs:
                lib.concatLists (lib.mapAttrsToList (name: value:
                  let
                    selector = if prefix == "" then name else "${prefix}.${name}";
                  in
                    if builtins.isAttrs value && !(lib.isDerivation value) then
                      flatten selector value
                    else
                      [ (mkPut selector value) ]
                ) attrs);

            in
              lib.concatStringsSep "\n" (flatten "" settings);

        in
        ''
          echo "Merging Nix-managed configurations with dasel..."
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (path: settings: ''
            if [ -f "${path}" ]; then
              echo "Merging into ${path}..."
              ${genCmds path settings}
            else
              echo "Skipping ${path}: File not found."
            fi
          '') cfg)}
        '';
    };
  };
}
