# Active-Frame-Hitbox
# Godot Combat Components

A lightweight, modular combat component toolkit for Godot 4, developed by BearBuild Studio.

Build reusable combat systems using independent Hitbox, Hurtbox, and Health components without writing the same combat logic for every character.

## Features

### Active Frame Hitbox
- Animation-based active frames
- Configurable damage
- Collision shape generation
- Inspector-exposed settings
- Designed for attacks with specific damage windows

### Hurtbox
- Receives damage from attacks
- Forwards damage to a HealthComponent
- Supports damage signals
- Configurable collision shapes

### HealthComponent
- Reusable health management
- Handles damage
- Supports character death logic
- Can be attached to different characters and enemies

## Installation

1. Download the plugin from the Godot Asset Library or GitHub.
2. Copy `addons/active-frame-hitbox/` into your Godot project's `addons/` folder.
3. Open Godot and navigate to **Project > Project Settings > Plugins**.
4. Enable **Godot Combat Components**.
5. Add the desired components through Godot's Create Node dialog.

## Basic Usage

### HealthComponent
Add a HealthComponent node to a character and configure its health settings in the Inspector.

### Hurtbox
Add a Hurtbox to the character, configure its collision shape, and assign its HealthComponent reference.

### Hitbox
Add a Hitbox to an attacking character or weapon, configure its damage and collision shape, and set its active frames to match the attack animation.

## Requirements

- Godot 4.x (specific minimum version to be confirmed through testing)
- GDScript

## License

MIT License. See the LICENSE file for details.

## Credits

Created by BearBuild Studio.
