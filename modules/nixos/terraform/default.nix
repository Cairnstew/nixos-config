# terraform/default.nix
{ ... }:

{
  terraform.required_providers.local = {
    source  = "hashicorp/local";
    version = "~> 2.0";
  };

  resource.local_file.example = {
    content  = "managed by terranix\n";
    filename = "/tmp/terranix-example.txt";
  };

  output.example_path = {
    value = "\${local_file.example.filename}";
  };
}