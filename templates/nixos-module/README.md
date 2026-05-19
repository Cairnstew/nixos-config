# my.services.my-service

NixOS module for [service description].

## Usage

```nix
{
  my.services.my-service = {
    enable = true;
    port = 8080;
  };
}
```

## Options

- `enable` - Enable the service
- `package` - The package to use (default: `pkgs.hello`)
- `user` - User to run as (default: `"my-service"`)
- `port` - Port to listen on (default: `8080`)
