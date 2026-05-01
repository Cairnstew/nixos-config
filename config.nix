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
    desktop-dlstflt    = { ip = "100.111.231.84"; hostname = "desktop-dlstflt";    magicDnsName = "desktop-dlstflt.tail685690.ts.net"; };
  };

  ollamaModels = {
    "deepseek-coder-v2:16b" = {
      name = "deepseek-coder-v2:16b";
      tools = true;
      numCtx = 32768;
      temperature = 0.7;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default  = false;
    };
    "qwen2.5-coder:7b" = {
      name = "qwen2.5-coder:7b";
      tools = true;
      numCtx = 32768;
      temperature = 0.7;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default  = false;
    };
    "qwen2.5-coder:14b-instruct" = {
      name = "qwen2.5-coder:14b-instruct";
      tools = true;
      numCtx = 32768;
      temperature = 0.7;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default  = false;
      cline_default = false;
    };
    "hermes3:8b" = {
      name = "hermes3:8b";
      tools = true;
      numCtx = 32768;
      temperature = 0.1;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default  = false;
      cline_default = false;
    };
    "gemma4:e4b" = {
      name         = "gemma4:e4b";
      tools        = true;
      numCtx       = 32768;
      temperature  = 0.10;   # low temp for agentic tasks
      topP         = 0.95;  # higher topP to increase creativity
      topK         = 64;
      
      cline_default = true;
      aider_default = true;
      opencode_default = true;
    };
  };
}
