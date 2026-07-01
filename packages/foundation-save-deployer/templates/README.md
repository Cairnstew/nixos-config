# Foundation Save Templates

This directory contains save templates for the game Foundation (Steam App ID 690830).

## What are save templates?

Save templates are starter save files created once in-game and then distributed
so multiple players or deployments can start from the same foundation.

## How to create a template

1. Launch Foundation and create a new game
2. Build your initial settlement layout
3. Save the game with a descriptive name (e.g. `starter-city.foundation`)
4. Create a template from the save:

```bash
foundation-save-deployer template create starter-city
```

Or specify a particular save file:

```bash
foundation-save-deployer template create my-template ~/.steam/steam/steamapps/compatdata/690830/pfx/drive_c/users/steamuser/Documents/Polymorph Games/Foundation/Save Game/my_city.foundation
```

## How to deploy a template

```bash
foundation-save-deployer deploy starter-city
```

This copies the template to the game's save directory so it appears in-game.

## Template storage

Templates are stored at:
- `~/.local/share/foundation-save-deployer/templates/`

They are `.foundation` files (the native Foundation save format).
