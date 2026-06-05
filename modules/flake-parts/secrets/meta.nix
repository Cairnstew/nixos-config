{
  name = "secrets";
  description = "Secrets management CLI tools: validate, set, agenix-manager TUI";
  category = "security";
  tags = [ "secrets" "agenix" "age" "encryption" ];
  provides = [
    "devShells.secrets"
    "apps.secrets-validate"
    "apps.secrets-set"
  ];
  complexity = "low";
  tested = false;
}
