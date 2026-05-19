---
name: nodejs-development
description: Node.js development with pnpm/npm and Nix
---

## What I do

Guide Node.js development within a Nix flake environment.

## Project Structure

```
.
├── package.json        # Node.js package manifest
├── package-lock.json   # npm lockfile (or pnpm-lock.yaml)
├── src/
│   └── index.js        # Entry point
├── flake.nix           # Nix flake
└── .envrc              # direnv integration
```

## Common Tasks

### Initialize project

```bash
npm init
# Or with pnpm
pnpm init
```

### Add dependencies

```bash
npm install <package>
# Or with pnpm
pnpm add <package>
```

### Add dev dependencies

```bash
npm install --save-dev <package>
# Or with pnpm
pnpm add --save-dev <package>
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Run scripts

```bash
npm run <script>
# Or with pnpm
pnpm <script>
```

### Build with Nix

```bash
nix build
```

Note: You'll need to set `npmDepsHash` in `flake.nix`. First build will
tell you the expected hash.

## Key Tools Available

- `nodejs` - Node.js runtime
- `pnpm` - Fast package manager (or `npm`, `yarn`)
- `typescript` - Add to devDependencies for TypeScript

## With TypeScript

Add to `package.json`:
```json
{
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
```

Then run:
```bash
npx tsc --init
```

## Nix Build Configuration

To update `npmDepsHash`:

1. Set `npmDepsHash = pkgs.lib.fakeSha256;`
2. Run `nix build`
3. Copy the expected hash from the error
4. Update `npmDepsHash`

Or use `prefetch-npm-deps`:
```bash
prefetch-npm-deps package-lock.json
```

## Tips

1. **Lockfile**: Always commit `package-lock.json` or `pnpm-lock.yaml`
2. **Node version**: Pin specific version in flake if needed
3. **Native deps**: Some packages need native build tools in `nativeBuildInputs`
4. **ESM**: For ES modules, add `"type": "module"` to package.json
