---
name: webapp-development
description: Web application development with Nix
---

## What I do

Guide development of web applications within a Nix flake environment.

## Project Structure

```
.
├── flake.nix           # Nix flake
├── src/                # Source code
├── public/             # Static assets (optional)
├── package.json        # Node.js dependencies (if applicable)
└── .envrc              # direnv integration
```

## Common Tasks

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Add frontend framework

Install in dev shell:
```bash
npm create vite@latest frontend -- --template react
# or
npm create vue@latest frontend
# or
npm create svelte@latest frontend
```

### Add backend framework

For Node.js:
```bash
npm install express
# or
npm install fastify
```

For Python:
```bash
uv add fastapi uvicorn
# or
uv add flask
```

### Build for production

```bash
nix build
```

## Frontend Integration

Add a frontend build to the flake:

```nix
packages.frontend = pkgs.buildNpmPackage {
  pname = "frontend";
  version = "0.1.0";
  src = ./frontend;
  npmDepsHash = ""; # Set after first build
  buildPhase = "npm run build";
  installPhase = ''
    mkdir -p $out/share
    cp -r dist/* $out/share/
  '';
};
```

## Backend Integration

Use process-compose or docker-compose for local development:

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    process-compose
    nodejs
  ];
};
```

Create `process-compose.yaml`:
```yaml
version: "0.5"
processes:
  backend:
    command: npm run dev
    working_dir: ./backend
  frontend:
    command: npm run dev
    working_dir: ./frontend
```

## Serving Static Files

Use a lightweight server:

```nix
packages.serve = pkgs.writeShellScriptBin "serve" ''
  ${pkgs.python3}/bin/python -m http.server 8080 -d ${self'.packages.frontend}/share
'';
```

## Deployment

### NixOS Module

Create a NixOS module for deployment:
```nix
services.my-webapp = {
  enable = true;
  package = self.packages.x86_64-linux.my-webapp;
  port = 8080;
};
```

### Container

Build a Docker image:
```nix
packages.container = pkgs.dockerTools.buildImage {
  name = "my-webapp";
  tag = "latest";
  copyToRoot = [ self'.packages.default ];
  config.Entrypoint = [ "${self'.packages.default}/bin/my-app" ];
};
```

## Tips

1. **Hot reload**: Use vite/webpack dev server in dev shell
2. **Proxy**: Configure API proxy in vite.config.js or webpack
3. **Env vars**: Use `.env` files (don't commit secrets)
4. **Database**: Add postgres/redis services to process-compose
5. **Testing**: Add playwright or cypress for E2E tests
