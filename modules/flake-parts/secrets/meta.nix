{
  name = "secrets";
  description = "Secrets management CLI tools: generate, edit, rekey, validate, set, new, add-host";
  category = "security";
  tags = [ "secrets" "agenix" "age" "encryption" ];
  provides = [
    "devShells.secrets"
    "apps.secrets-add-host"
    "apps.secrets-generate"
    "apps.secrets-edit"
    "apps.secrets-rekey"
    "apps.secrets-validate"
    "apps.secrets-new"
    "apps.secrets-set"
  ];
  complexity = "moderate";
  tested = false;
}
