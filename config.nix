# Configuration for this repo
# See ./modules/flake-parts/config.nix for module options.
{
  me = {
    username = "seanc";
    fullname = "Sean Cairns";
    email = "sean.cairnsst@gmail.com";
    sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPWrhAp1ZU9p7UvJ1x9ApM1pY9OK2S8crEKHeEAxX0z6 sean.cairnsst@gmail.com";
    github_username = "Cairnstew";

    
  };

  tailnet = {
    server = { ip = "100.119.248.77";  hostname = "server"; magicDnsName = "server.tail685690.ts.net"; };
    laptop     = { ip = "100.108.181.64"; hostname = "laptop";     magicDnsName = "laptop.tail685690.ts.net"; };
    wsl        = { ip = "100.70.224.82";  hostname = "wsl";        magicDnsName = "wsl.tail685690.ts.net"; };
  };

  ollamaModels = {
    "qwen3:8b" = { name = "Qwen 3 8B"; tools = true; numCtx = 16384; think = false; };
    "deepseek-r1:14b"    = { name = "DeepSeek R1 14B"; tools = true; };
    "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix" = {
      name = "Lewdiculous Qwen3 8B";
    };
    "deepseek-coder-v2:16b" = {
      name = "DeepSeek Coder 2 16B";
      tools = true;
      numCtx = 20000;
      temperature = 0.1;
    };
  };
}
