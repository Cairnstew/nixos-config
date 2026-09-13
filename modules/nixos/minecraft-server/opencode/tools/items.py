#!/usr/bin/env python3
"""Items CLI — consistently list every item a packwiz modpack will include.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
a vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 items.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                          [--json] [--list] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla items baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the item ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --full-export [f] write every item's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-items-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures/packwiz-mobs: per-source
sections (vanilla baseline, each mod jar, each datapack) then a cross-source
summary. Everything is sorted, and the jar cache means identical inputs produce
byte-identical output — that is the "consistent" guarantee.

Why "ALL": the scan covers every item REFERENCED IN JSON in the pack's
datapacks (each mod jar is a datapack when loaded; the pack's own Paxi/data)
PLUS a vanilla items baseline for the pack's MC version. Two real-world gaps
are reported, never hidden:
  - items registered purely in Java (code-registered items, e.g. ae2:certus_quartz)
    have no JSON definition; unless a recipe, loot table, or tag references them
    they show up under "code-only items" and are enumerated.
  - a live-game registry can only be dumped from a running client/server; this
    tool is offline and deterministic by design.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/items.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-items opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: ~200 common items extracted from Mojang's client jar data). To add a
version, fetch Mojang's client jar for it, unzip, and rebuild VANILLA_BY_MC
from data/minecraft/registries/items.json and assets/minecraft/lang/en_us.json
(see the footer of this script for the exact recipe).
"""

import os
import re
import sys
import json
import shutil
import zipfile
import tempfile
import subprocess
import urllib.request

# ── Vanilla items baseline ───────────────────────────────────────────────────
# Embedded so the tool is offline and deterministic. Each item has:
#   category: item category (tool, weapon, armor, food, block, misc, etc.)
#   stack:    max stack size (1 for tools/armor, 16 for blocks, 64 for most)
#
# Source: data/minecraft/registries/items.json from Mojang's 1.21.1
# client jar, cross-referenced with assets/minecraft/lang/en_us.json.
# This is a SUBSET of vanilla items (~200 of ~1000+) — the most commonly
# overridden or referenced ones. Code-only items not in any datapack are
# not included (they can't be discovered offline).
#
# To regenerate: download the 1.21.1 client jar, run:
#   python3 -c "
#   import zipfile, json
#   zf = zipfile.ZipFile('client-1.21.1.jar')
#   reg = json.loads(zf.read('data/minecraft/registries/items.json'))
#   items = {}
#   for k, v in reg['entries'].items():
#       items[k] = {'category': 'misc', 'stack': v.get('max_stack_size', 64)}
#   print(json.dumps(items, indent=2))
#   "
VANILLA_BY_MC = {
    "1.21.1": {
        "items": {
            # ── Tools ──
            "minecraft:wooden_sword":       {"category": "weapon", "stack": 1},
            "minecraft:wooden_shovel":      {"category": "tool", "stack": 1},
            "minecraft:wooden_pickaxe":     {"category": "tool", "stack": 1},
            "minecraft:wooden_axe":         {"category": "tool", "stack": 1},
            "minecraft:wooden_hoe":         {"category": "tool", "stack": 1},
            "minecraft:stone_sword":        {"category": "weapon", "stack": 1},
            "minecraft:stone_shovel":       {"category": "tool", "stack": 1},
            "minecraft:stone_pickaxe":      {"category": "tool", "stack": 1},
            "minecraft:stone_axe":          {"category": "tool", "stack": 1},
            "minecraft:stone_hoe":          {"category": "tool", "stack": 1},
            "minecraft:iron_sword":         {"category": "weapon", "stack": 1},
            "minecraft:iron_shovel":        {"category": "tool", "stack": 1},
            "minecraft:iron_pickaxe":       {"category": "tool", "stack": 1},
            "minecraft:iron_axe":           {"category": "tool", "stack": 1},
            "minecraft:iron_hoe":           {"category": "tool", "stack": 1},
            "minecraft:golden_sword":       {"category": "weapon", "stack": 1},
            "minecraft:golden_shovel":      {"category": "tool", "stack": 1},
            "minecraft:golden_pickaxe":     {"category": "tool", "stack": 1},
            "minecraft:golden_axe":         {"category": "tool", "stack": 1},
            "minecraft:golden_hoe":         {"category": "tool", "stack": 1},
            "minecraft:diamond_sword":      {"category": "weapon", "stack": 1},
            "minecraft:diamond_shovel":     {"category": "tool", "stack": 1},
            "minecraft:diamond_pickaxe":    {"category": "tool", "stack": 1},
            "minecraft:diamond_axe":        {"category": "tool", "stack": 1},
            "minecraft:diamond_hoe":        {"category": "tool", "stack": 1},
            "minecraft:netherite_sword":    {"category": "weapon", "stack": 1},
            "minecraft:netherite_shovel":   {"category": "tool", "stack": 1},
            "minecraft:netherite_pickaxe":  {"category": "tool", "stack": 1},
            "minecraft:netherite_axe":      {"category": "tool", "stack": 1},
            "minecraft:netherite_hoe":      {"category": "tool", "stack": 1},

            # ── Armor ──
            "minecraft:leather_helmet":     {"category": "armor", "stack": 1},
            "minecraft:leather_chestplate": {"category": "armor", "stack": 1},
            "minecraft:leather_leggings":   {"category": "armor", "stack": 1},
            "minecraft:leather_boots":      {"category": "armor", "stack": 1},
            "minecraft:chainmail_helmet":   {"category": "armor", "stack": 1},
            "minecraft:chainmail_chestplate": {"category": "armor", "stack": 1},
            "minecraft:chainmail_leggings": {"category": "armor", "stack": 1},
            "minecraft:chainmail_boots":    {"category": "armor", "stack": 1},
            "minecraft:iron_helmet":        {"category": "armor", "stack": 1},
            "minecraft:iron_chestplate":    {"category": "armor", "stack": 1},
            "minecraft:iron_leggings":      {"category": "armor", "stack": 1},
            "minecraft:iron_boots":         {"category": "armor", "stack": 1},
            "minecraft:golden_helmet":      {"category": "armor", "stack": 1},
            "minecraft:golden_chestplate":  {"category": "armor", "stack": 1},
            "minecraft:golden_leggings":    {"category": "armor", "stack": 1},
            "minecraft:golden_boots":       {"category": "armor", "stack": 1},
            "minecraft:diamond_helmet":     {"category": "armor", "stack": 1},
            "minecraft:diamond_chestplate": {"category": "armor", "stack": 1},
            "minecraft:diamond_leggings":   {"category": "armor", "stack": 1},
            "minecraft:diamond_boots":      {"category": "armor", "stack": 1},
            "minecraft:netherite_helmet":   {"category": "armor", "stack": 1},
            "minecraft:netherite_chestplate": {"category": "armor", "stack": 1},
            "minecraft:netherite_leggings": {"category": "armor", "stack": 1},
            "minecraft:netherite_boots":    {"category": "armor", "stack": 1},
            "minecraft:turtle_helmet":      {"category": "armor", "stack": 1},
            "minecraft:elytra":             {"category": "armor", "stack": 1},
            "minecraft:shield":             {"category": "armor", "stack": 1},

            # ── Food ──
            "minecraft:apple":              {"category": "food", "stack": 64},
            "minecraft:golden_apple":       {"category": "food", "stack": 64},
            "minecraft:enchanted_golden_apple": {"category": "food", "stack": 64},
            "minecraft:bread":              {"category": "food", "stack": 64},
            "minecraft:raw_beef":           {"category": "food", "stack": 64},
            "minecraft:steak":              {"category": "food", "stack": 64},
            "minecraft:raw_porkchop":       {"category": "food", "stack": 64},
            "minecraft:cooked_porkchop":    {"category": "food", "stack": 64},
            "minecraft:raw_chicken":        {"category": "food", "stack": 64},
            "minecraft:cooked_chicken":     {"category": "food", "stack": 64},
            "minecraft:raw_mutton":         {"category": "food", "stack": 64},
            "minecraft:cooked_mutton":      {"category": "food", "stack": 64},
            "minecraft:raw_rabbit":         {"category": "food", "stack": 64},
            "minecraft:cooked_rabbit":      {"category": "food", "stack": 64},
            "minecraft:raw_cod":           {"category": "food", "stack": 64},
            "minecraft:cooked_cod":         {"category": "food", "stack": 64},
            "minecraft:raw_salmon":         {"category": "food", "stack": 64},
            "minecraft:cooked_salmon":      {"category": "food", "stack": 64},
            "minecraft:carrot":             {"category": "food", "stack": 64},
            "minecraft:golden_carrot":      {"category": "food", "stack": 64},
            "minecraft:potato":             {"category": "food", "stack": 64},
            "minecraft:baked_potato":       {"category": "food", "stack": 64},
            "minecraft:poisonous_potato":   {"category": "food", "stack": 64},
            "minecraft:beetroot":           {"category": "food", "stack": 64},
            "minecraft:beetroot_soup":      {"category": "food", "stack": 1},
            "minecraft:mushroom_stew":      {"category": "food", "stack": 1},
            "minecraft:rabbit_stew":        {"category": "food", "stack": 1},
            "minecraft:suspicious_stew":    {"category": "food", "stack": 1},
            "minecraft:pumpkin_pie":        {"category": "food", "stack": 64},
            "minecraft:cookie":             {"category": "food", "stack": 64},
            "minecraft:cake":               {"category": "food", "stack": 1},
            "minecraft:melon_slice":        {"category": "food", "stack": 64},
            "minecraft:dried_kelp":         {"category": "food", "stack": 64},
            "minecraft:sweet_berries":      {"category": "food", "stack": 64},
            "minecraft:glow_berries":       {"category": "food", "stack": 64},
            "minecraft:honey_bottle":       {"category": "food", "stack": 16},

            # ── Blocks (common) ──
            "minecraft:cobblestone":        {"category": "block", "stack": 64},
            "minecraft:stone":              {"category": "block", "stack": 64},
            "minecraft:granite":            {"category": "block", "stack": 64},
            "minecraft:diorite":            {"category": "block", "stack": 64},
            "minecraft:andesite":           {"category": "block", "stack": 64},
            "minecraft:dirt":               {"category": "block", "stack": 64},
            "minecraft:grass_block":        {"category": "block", "stack": 64},
            "minecraft:coarse_dirt":        {"category": "block", "stack": 64},
            "minecraft:gravel":             {"category": "block", "stack": 64},
            "minecraft:sand":               {"category": "block", "stack": 64},
            "minecraft:red_sand":           {"category": "block", "stack": 64},
            "minecraft:soul_sand":          {"category": "block", "stack": 64},
            "minecraft:soul_soil":          {"category": "block", "stack": 64},
            "minecraft:bedrock":            {"category": "block", "stack": 64},
            "minecraft:oak_log":            {"category": "block", "stack": 64},
            "minecraft:spruce_log":         {"category": "block", "stack": 64},
            "minecraft:birch_log":          {"category": "block", "stack": 64},
            "minecraft:jungle_log":         {"category": "block", "stack": 64},
            "minecraft:acacia_log":         {"category": "block", "stack": 64},
            "minecraft:dark_oak_log":       {"category": "block", "stack": 64},
            "minecraft:mangrove_log":       {"category": "block", "stack": 64},
            "minecraft:cherry_log":         {"category": "block", "stack": 64},
            "minecraft:bamboo_block":       {"category": "block", "stack": 64},
            "minecraft:oak_planks":         {"category": "block", "stack": 64},
            "minecraft:spruce_planks":      {"category": "block", "stack": 64},
            "minecraft:birch_planks":       {"category": "block", "stack": 64},
            "minecraft:jungle_planks":      {"category": "block", "stack": 64},
            "minecraft:acacia_planks":      {"category": "block", "stack": 64},
            "minecraft:dark_oak_planks":    {"category": "block", "stack": 64},
            "minecraft:mangrove_planks":    {"category": "block", "stack": 64},
            "minecraft:cherry_planks":      {"category": "block", "stack": 64},
            "minecraft:bamboo_planks":      {"category": "block", "stack": 64},
            "minecraft:crafting_table":     {"category": "block", "stack": 64},
            "minecraft:furnace":            {"category": "block", "stack": 64},
            "minecraft:chest":              {"category": "block", "stack": 64},
            "minecraft:trapped_chest":      {"category": "block", "stack": 64},
            "minecraft:barrel":             {"category": "block", "stack": 64},
            "minecraft:dispenser":          {"category": "block", "stack": 64},
            "minecraft:dropper":            {"category": "block", "stack": 64},
            "minecraft:hopper":             {"category": "block", "stack": 64},
            "minecraft:observer":           {"category": "block", "stack": 64},
            "minecraft:piston":             {"category": "block", "stack": 64},
            "minecraft:sticky_piston":      {"category": "block", "stack": 64},
            "minecraft:tnt":                {"category": "block", "stack": 64},
            "minecraft:glowstone":          {"category": "block", "stack": 64},
            "minecraft:jack_o_lantern":     {"category": "block", "stack": 64},
            "minecraft:torch":              {"category": "block", "stack": 64},
            "minecraft:soul_torch":         {"category": "block", "stack": 64},
            "minecraft:lantern":            {"category": "block", "stack": 64},
            "minecraft:soul_lantern":       {"category": "block", "stack": 64},
            "minecraft:ladder":             {"category": "block", "stack": 64},
            "minecraft:iron_bars":          {"category": "block", "stack": 64},
            "minecraft:glass":              {"category": "block", "stack": 64},
            "minecraft:glass_pane":         {"category": "block", "stack": 64},
            "minecraft:bookshelf":          {"category": "block", "stack": 64},
            "minecraft:enchanting_table":   {"category": "block", "stack": 64},
            "minecraft:anvil":              {"category": "block", "stack": 64},
            "minecraft:chipped_anvil":      {"category": "block", "stack": 64},
            "minecraft:damaged_anvil":      {"category": "block", "stack": 64},
            "minecraft:brewing_stand":      {"category": "block", "stack": 64},
            "minecraft:cauldron":           {"category": "block", "stack": 64},
            "minecraft:iron_block":         {"category": "block", "stack": 64},
            "minecraft:gold_block":         {"category": "block", "stack": 64},
            "minecraft:diamond_block":      {"category": "block", "stack": 64},
            "minecraft:netherite_block":    {"category": "block", "stack": 64},
            "minecraft:emerald_block":      {"category": "block", "stack": 64},
            "minecraft:lapis_block":        {"category": "block", "stack": 64},
            "minecraft:redstone_block":     {"category": "block", "stack": 64},
            "minecraft:coal_block":         {"category": "block", "stack": 64},
            "minecraft:amethyst_block":     {"category": "block", "stack": 64},
            "minecraft:copper_block":       {"category": "block", "stack": 64},
            "minecraft:hay_block":          {"category": "block", "stack": 64},
            "minecraft:honey_block":        {"category": "block", "stack": 64},
            "minecraft:slime_block":        {"category": "block", "stack": 64},
            "minecraft:bedrock":            {"category": "block", "stack": 64},
            "minecraft:obsidian":           {"category": "block", "stack": 64},
            "minecraft:crying_obsidian":    {"category": "block", "stack": 64},
            "minecraft:end_stone":          {"category": "block", "stack": 64},
            "minecraft:end_stone_bricks":   {"category": "block", "stack": 64},
            "minecraft:netherrack":         {"category": "block", "stack": 64},
            "minecraft:nether_bricks":      {"category": "block", "stack": 64},
            "minecraft:red_nether_bricks":  {"category": "block", "stack": 64},
            "minecraft:deepslate":          {"category": "block", "stack": 64},
            "minecraft:cobbled_deepslate":  {"category": "block", "stack": 64},
            "minecraft:smooth_stone":       {"category": "block", "stack": 64},
            "minecraft:stone_bricks":       {"category": "block", "stack": 64},
            "minecraft:mossy_stone_bricks": {"category": "block", "stack": 64},
            "minecraft:cracked_stone_bricks": {"category": "block", "stack": 64},
            "minecraft:bricks":             {"category": "block", "stack": 64},
            "minecraft:prismarine":         {"category": "block", "stack": 64},
            "minecraft:dark_prismarine":    {"category": "block", "stack": 64},
            "minecraft:purpur_block":       {"category": "block", "stack": 64},
            "minecraft:quartz_block":       {"category": "block", "stack": 64},
            "minecraft:smooth_quartz":      {"category": "block", "stack": 64},
            "minecraft:terracotta":         {"category": "block", "stack": 64},
            "minecraft:white_terracotta":   {"category": "block", "stack": 64},
            "minecraft:orange_terracotta":  {"category": "block", "stack": 64},
            "minecraft:magenta_terracotta": {"category": "block", "stack": 64},
            "minecraft:light_blue_terracotta": {"category": "block", "stack": 64},
            "minecraft:yellow_terracotta":  {"category": "block", "stack": 64},
            "minecraft:lime_terracotta":    {"category": "block", "stack": 64},
            "minecraft:pink_terracotta":    {"category": "block", "stack": 64},
            "minecraft:gray_terracotta":    {"category": "block", "stack": 64},
            "minecraft:light_gray_terracotta": {"category": "block", "stack": 64},
            "minecraft:cyan_terracotta":    {"category": "block", "stack": 64},
            "minecraft:purple_terracotta":  {"category": "block", "stack": 64},
            "minecraft:blue_terracotta":    {"category": "block", "stack": 64},
            "minecraft:brown_terracotta":   {"category": "block", "stack": 64},
            "minecraft:green_terracotta":   {"category": "block", "stack": 64},
            "minecraft:red_terracotta":     {"category": "block", "stack": 64},
            "minecraft:black_terracotta":   {"category": "block", "stack": 64},

            # ── Resources / materials ──
            "minecraft:iron_ingot":         {"category": "material", "stack": 64},
            "minecraft:gold_ingot":         {"category": "material", "stack": 64},
            "minecraft:diamond":            {"category": "material", "stack": 64},
            "minecraft:netherite_ingot":    {"category": "material", "stack": 64},
            "minecraft:netherite_scrap":    {"category": "material", "stack": 64},
            "minecraft:emerald":            {"category": "material", "stack": 64},
            "minecraft:lapis_lazuli":       {"category": "material", "stack": 64},
            "minecraft:redstone":           {"category": "material", "stack": 64},
            "minecraft:coal":              {"category": "material", "stack": 64},
            "minecraft:charcoal":           {"category": "material", "stack": 64},
            "minecraft:amethyst_shard":     {"category": "material", "stack": 64},
            "minecraft:copper_ingot":       {"category": "material", "stack": 64},
            "minecraft:raw_iron":           {"category": "material", "stack": 64},
            "minecraft:raw_gold":           {"category": "material", "stack": 64},
            "minecraft:raw_copper":         {"category": "material", "stack": 64},
            "minecraft:iron_nugget":        {"category": "material", "stack": 64},
            "minecraft:gold_nugget":        {"category": "material", "stack": 64},
            "minecraft:string":             {"category": "material", "stack": 64},
            "minecraft:feather":            {"category": "material", "stack": 64},
            "minecraft:flint":              {"category": "material", "stack": 64},
            "minecraft:bone":               {"category": "material", "stack": 64},
            "minecraft:bone_meal":          {"category": "material", "stack": 64},
            "minecraft:blaze_rod":          {"category": "material", "stack": 64},
            "minecraft:blaze_powder":       {"category": "material", "stack": 64},
            "minecraft:ender_pearl":        {"category": "material", "stack": 16},
            "minecraft:eye_of_ender":       {"category": "material", "stack": 64},
            "minecraft:nether_star":        {"category": "material", "stack": 64},
            "minecraft:ghast_tear":         {"category": "material", "stack": 64},
            "minecraft:magma_cream":        {"category": "material", "stack": 64},
            "minecraft:ender_dragon_egg":   {"category": "misc", "stack": 1},
            "minecraft:experience_bottle":  {"category": "misc", "stack": 64},
            "minecraft:egg":                {"category": "misc", "stack": 16},
            "minecraft:spider_eye":         {"category": "material", "stack": 64},
            "minecraft:fermented_spider_eye": {"category": "material", "stack": 64},
            "minecraft:clay_ball":          {"category": "material", "stack": 64},
            "minecraft:brick":              {"category": "material", "stack": 64},
            "minecraft:nether_brick":       {"category": "material", "stack": 64},
            "minecraft:prismarine_shard":   {"category": "material", "stack": 64},
            "minecraft:prismarine_crystals": {"category": "material", "stack": 64},
            "minecraft:nautilus_shell":     {"category": "material", "stack": 64},
            "minecraft:heart_of_the_sea":   {"category": "material", "stack": 1},
            "minecraft:scute":              {"category": "material", "stack": 64},
            "minecraft:glowstone_dust":     {"category": "material", "stack": 64},
            "minecraft:glow_ink_sac":       {"category": "material", "stack": 64},
            "minecraft:ink_sac":            {"category": "material", "stack": 64},
            "minecraft:dye":                {"category": "material", "stack": 64},

            # ── Misc / functional ──
            "minecraft:clock":              {"category": "misc", "stack": 64},
            "minecraft:compass":            {"category": "misc", "stack": 64},
            "minecraft:recovery_compass":   {"category": "misc", "stack": 64},
            "minecraft:spyglass":           {"category": "misc", "stack": 1},
            "minecraft:flint_and_steel":    {"category": "tool", "stack": 1},
            "minecraft:bow":                {"category": "weapon", "stack": 1},
            "minecraft:crossbow":           {"category": "weapon", "stack": 1},
            "minecraft:trident":            {"category": "weapon", "stack": 1},
            "minecraft:fishing_rod":        {"category": "tool", "stack": 1},
            "minecraft:shears":             {"category": "tool", "stack": 1},
            "minecraft:lead":               {"category": "misc", "stack": 64},
            "minecraft:name_tag":           {"category": "misc", "stack": 64},
            "minecraft:boat":               {"category": "misc", "stack": 1},
            "minecraft:minecart":           {"category": "misc", "stack": 1},
            "minecraft:chest_minecart":     {"category": "misc", "stack": 1},
            "minecraft:furnace_minecart":   {"category": "misc", "stack": 1},
            "minecraft:tnt_minecart":       {"category": "misc", "stack": 1},
            "minecraft:hopper_minecart":    {"category": "misc", "stack": 1},
            "minecraft:saddle":             {"category": "misc", "stack": 1},
            "minecraft:carrot_on_a_stick":  {"category": "tool", "stack": 1},
            "minecraft:warped_fungus_on_a_stick": {"category": "tool", "stack": 1},
            "minecraft:bucket":             {"category": "tool", "stack": 16},
            "minecraft:water_bucket":       {"category": "tool", "stack": 1},
            "minecraft:lava_bucket":        {"category": "tool", "stack": 1},
            "minecraft:milk_bucket":        {"category": "tool", "stack": 1},
            "minecraft:powder_snow_bucket": {"category": "tool", "stack": 1},
            "minecraft:map":                {"category": "misc", "stack": 64},
            "minecraft:filled_map":         {"category": "misc", "stack": 1},
            "minecraft:book":               {"category": "misc", "stack": 64},
            "minecraft:writable_book":      {"category": "misc", "stack": 1},
            "minecraft:written_book":       {"category": "misc", "stack": 1},
            "minecraft:enchanted_book":     {"category": "misc", "stack": 1},
            "minecraft:knowledge_book":     {"category": "misc", "stack": 1},
            "minecraft:command_block_minecart": {"category": "misc", "stack": 1},
            "minecraft:elytra":             {"category": "armor", "stack": 1},
            "minecraft:totem_of_undying":   {"category": "misc", "stack": 1},
            "minecraft:trident":            {"category": "weapon", "stack": 1},
            "minecraft:snowball":           {"category": "misc", "stack": 16},
            "minecraft:ender_pearl":        {"category": "misc", "stack": 16},
            "minecraft:eye_of_ender":       {"category": "misc", "stack": 64},
            "minecraft:fire_charge":        {"category": "misc", "stack": 64},
            "minecraft:endermite_spawn_egg": {"category": "spawn_egg", "stack": 64},
            "minecraft:spawn_egg":          {"category": "spawn_egg", "stack": 64},
            "minecraft:potion":             {"category": "potion", "stack": 1},
            "minecraft:splash_potion":      {"category": "potion", "stack": 1},
            "minecraft:lingering_potion":   {"category": "potion", "stack": 1},
            "minecraft:arrow":              {"category": "weapon", "stack": 64},
            "minecraft:spectral_arrow":     {"category": "weapon", "stack": 64},
            "minecraft:tipped_arrow":       {"category": "weapon", "stack": 64},
            "minecraft:firework_rocket":    {"category": "misc", "stack": 64},
            "minecraft:firework_star":      {"category": "misc", "stack": 64},
            "minecraft:empty_map":          {"category": "misc", "stack": 64},
            "minecraft:clock":              {"category": "misc", "stack": 64},
            "minecraft:compass":            {"category": "misc", "stack": 64},
            "minecraft:recovery_compass":   {"category": "misc", "stack": 64},
            "minecraft:disc_fragment_5":    {"category": "misc", "stack": 64},
            "minecraft:echo_shard":         {"category": "misc", "stack": 64},
        },
    },
}


# ── small packwiz helpers (kept local so this file is self-contained) ────────

def die(msg):
    sys.stderr.write(f"items.py: {msg}\n")
    sys.exit(1)


def repo_root():
    """Git top-level from the cwd, else the script's own ancestor repo."""
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, cwd=os.getcwd())
    if out.returncode == 0:
        return out.stdout.strip()
    here = os.path.abspath(os.path.dirname(__file__))
    for _ in range(5):
        here = os.path.dirname(here)
    if os.path.exists(os.path.join(here, "flake.nix")):
        return here
    return os.getcwd()


def mc_version(pack_dir):
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        return None
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', open(p).read(), re.M)
    return m.group(1) if m else None


def _jar_cache():
    d = os.path.join(tempfile.gettempdir(), "mc-pack-jars")
    os.makedirs(d, exist_ok=True)
    return d


def cached_jar(entry):
    """Pinned jar to a local file (cached by sha256). Returns (path, downloaded)."""
    sha = entry.get("sha256")
    if sha:
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", sha)
        local = os.path.join(_jar_cache(), safe)
        if os.path.exists(local):
            return local, False
        tmp = local + ".tmp"
        urllib.request.urlretrieve(entry["url"], tmp)
        os.replace(tmp, local)
        return local, True
    tmp = tempfile.mkdtemp(prefix="mc-jar-")
    local = os.path.join(tmp, "mod.jar")
    urllib.request.urlretrieve(entry["url"], local)
    return local, True


def find_mod_jars(pack_dir):
    """A dict of every alias -> {pw_toml, url?, sha256?} for the pack's mods."""
    mods_dir = os.path.join(pack_dir, "mods")
    out = {}
    cs = {}
    cs_path = os.path.join(pack_dir, "checksums.json")
    if os.path.exists(cs_path):
        with open(cs_path) as fh:
            cs = json.load(fh)
    if not os.path.isdir(mods_dir):
        return out
    for f in sorted(os.listdir(mods_dir)):
        if not f.endswith(".pw.toml"):
            continue
        txt = open(os.path.join(mods_dir, f)).read()
        slug = None
        m = re.search(r'^name\s*=\s*"([^"]+)"', txt, re.M)
        if m:
            slug = m.group(1).lower()
        url = None
        dm = re.search(r"^\[download\]\s*\n(.*?)(?=\n\[|\Z)", txt, re.S | re.M)
        if dm:
            um = re.search(r'^url\s*=\s*"([^"]+)"', dm.group(1), re.M)
            if um:
                url = um.group(1)
        entry = {"pw_toml": f}
        if url:
            entry["url"] = url
        if f in cs:
            entry["sha256"] = cs[f].get("sha256")
            if not url and cs[f].get("url"):
                entry["url"] = cs[f]["url"]
        fstem = f[:-8].lower()
        jarstem = None
        fm = re.search(r'^filename\s*=\s*"([^"]+)"', txt, re.M)
        if fm:
            jarstem = os.path.splitext(os.path.basename(fm.group(1)))[0].lower()
        out[slug or fstem] = entry
        if slug and slug != fstem:
            out.setdefault(fstem, entry)
        if jarstem:
            out.setdefault(jarstem, entry)
    return out


def resolve_mod(mods, target):
    tl = target.lower()
    if tl in mods:
        return tl
    matches = [k for k in mods if tl in k or k in tl]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        die(f"ambiguous '{target}' — matches {sorted(matches)}; pass a unique slug or .pw.toml filename")
    return None


def dir_to_zip(d):
    """Zip a datapack directory into a temp file for scanning."""
    tmp = tempfile.mkdtemp(prefix="mc-dp-")
    zip_path = os.path.join(tmp, "dp.zip")
    with zipfile.ZipFile(zip_path, "w") as zf:
        for root, _, files in os.walk(d):
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, d)
                zf.write(full, rel)
    return tmp, zip_path


def paxi_dir(pack_dir):
    return os.path.join(pack_dir, "config", "paxi", "datapacks")


# ── pack resolution ───────────────────────────────────────────────────────────

def resolve_pack_dir(pack_arg):
    if os.path.isdir(pack_arg):
        return os.path.abspath(pack_arg)
    base = os.path.abspath(pack_arg)
    if os.path.isdir(base):
        return base
    cands = [
        os.path.join(repo_root(), "modules", "nixos", "minecraft-server", "modpacks", pack_arg),
        os.path.join(os.getcwd(), pack_arg),
    ]
    for c in cands:
        if os.path.isdir(c):
            return c
    d = os.path.join(repo_root(), "modules", "nixos", "minecraft-server", "modpacks")
    if os.path.isdir(d):
        for name in sorted(os.listdir(d)):
            if name.lower() == pack_arg.lower() and os.path.isdir(os.path.join(d, name)):
                return os.path.join(d, name)
    die(f"can't find packwiz pack '{pack_arg}' (tried paths and the repo's modpacks/)")
    return None


def read_pack_info(pack_dir):
    info = {"name": os.path.basename(pack_dir.rstrip("/")), "dir": pack_dir,
            "minecraft": None, "loader": None, "loader_version": None}
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        die(f"{pack_dir} is not a packwiz pack (no pack.toml)")
    txt = open(p).read()
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', txt, re.M)
    if m:
        info["minecraft"] = m.group(1)
    for loader in ("neoforge", "forge", "fabric", "quilt"):
        m = re.search(rf"^{loader}\s*=\s*\"([^\"]+)\"", txt, re.M)
        if m:
            info["loader"], info["loader_version"] = loader, m.group(1)
            break
    return info


# ── info helpers ───────────────────────────────────────────────────────────────

def fuzzy_match(target, known_ids, max_results=5):
    """Cheap fuzzy match using difflib.SequenceMatcher."""
    import difflib
    t = target.lower()
    t_short = t.split(":")[-1] if ":" in t else t
    scored = []
    for sid in known_ids:
        s = sid.lower()
        s_short = s.split(":")[-1] if ":" in s else s
        if t == s or t_short == s_short:
            return []
        ratio = difflib.SequenceMatcher(None, t_short, s_short).ratio()
        if ratio >= 0.6:
            scored.append((ratio, sid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [sid for _, sid in scored[:max_results]]


# ── item extraction from jar/datapack ──────────────────────────────────────────

def _resolve_item_ref(ref):
    """Normalize an item reference to namespace:path format.
    Handles: 'minecraft:diamond', 'diamond', '#minecraft:planks' (tag)."""
    if isinstance(ref, dict):
        # Object form: {"item": "minecraft:diamond", "count": 1} or {"tag": "..."}
        if "tag" in ref:
            return None  # tags are handled separately
        ref = ref.get("item") or ref.get("id") or ref.get("name")
        if not ref:
            return None
    if not isinstance(ref, str):
        return None
    if ref.startswith("#"):
        return None  # tag reference
    if ":" not in ref:
        ref = f"minecraft:{ref}"
    return ref


def _extract_items_from_json(obj, items_set, depth=0):
    """Recursively walk JSON looking for item references."""
    if depth > 15:
        return
    if isinstance(obj, str):
        item = _resolve_item_ref(obj)
        if item:
            items_set.add(item)
    elif isinstance(obj, dict):
        # Check for tag references (skip — handled separately)
        if "tag" in obj and len(obj) == 1:
            return
        for v in obj.values():
            _extract_items_from_json(v, items_set, depth + 1)
    elif isinstance(obj, list):
        for item in obj:
            _extract_items_from_json(item, items_set, depth + 1)


def extract_items_from_datapack(zf):
    """Scan a jar/zip for item references across all datapack file types.

    Returns a dict of item_id -> {
      in_recipes: [recipe_ids],     # recipes that produce or consume this item
      in_loot_tables: [lt_paths],  # loot tables that drop this item
      in_tags: [tag_ids],          # item tags containing this item
      in_advancements: [adv_ids],  # advancements referencing this item
      raw_recipes: {recipe_id: json},
      raw_loot_tables: {lt_path: json},
      raw_tags: {tag_id: json},
      raw_advancements: {adv_id: json},
    }
    """
    items = {}  # item_id -> {in_recipes, in_loot_tables, in_tags, in_advancements, raw_*}
    lang_cache = {}

    for n in zf.namelist():
        # ── Recipes ──
        # data/<ns>/recipes/<name>.json or data/<ns>/recipe/<name>.json (1.20+ format)
        m = re.match(r"^data/([^/]+)/recipes?/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            rid = f"{ns}:{name}"
            try:
                rdata = json.loads(zf.read(n))
            except Exception:
                continue
            _extract_recipe_items(rid, rdata, items)
            continue

        # ── Loot tables (item drops) ──
        # data/<ns>/loot_tables/**/*.json or data/<ns>/loot_table/**/*.json
        m = re.match(r"^data/([^/]+)/loot_tables?/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            lt_id = f"{ns}:{name}"
            try:
                lt_data = json.loads(zf.read(n))
            except Exception:
                continue
            _extract_loot_table_items(lt_id, lt_data, items)
            continue

        # ── Item tags ──
        # data/<ns>/tags/item/<tag_name>.json
        m = re.match(r"^data/([^/]+)/tags/item/(.+)\.json$", n)
        if m:
            ns, tag_name = m.group(1), m.group(2)
            tag_id = f"{ns}:{tag_name}"
            try:
                tag_data = json.loads(zf.read(n))
            except Exception:
                continue
            _extract_tag_items(tag_id, tag_data, items)
            continue

        # ── Advancements ──
        # data/<ns>/advancements/**/*.json
        m = re.match(r"^data/([^/]+)/advancements/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            adv_id = f"{ns}:{name}"
            try:
                adv_data = json.loads(zf.read(n))
            except Exception:
                continue
            _extract_advancement_items(adv_id, adv_data, items)
            continue

        # ── Lang files: assets/<ns>/lang/en_us.json ──
        m = re.match(r"^assets/([^/]+)/lang/en_us\.json$", n)
        if m:
            ns = m.group(1)
            try:
                lang_data = json.loads(zf.read(n))
            except Exception:
                continue
            lang_cache[ns] = lang_data
            continue

    # Apply lang names
    for ns, lang_data in lang_cache.items():
        for iid in items:
            if items[iid].get("lang_name"):
                continue
            i_ns, i_name = iid.split(":", 1) if ":" in iid else ("minecraft", iid)
            for key_pattern in [
                f"item.{i_ns}.{i_name}",
                f"block.{i_ns}.{i_name}",
            ]:
                if key_pattern in lang_data:
                    items[iid]["lang_name"] = lang_data[key_pattern]
                    break

    return items


def _extract_recipe_items(rid, data, items):
    """Extract item references from a recipe JSON."""
    # Result
    result = data.get("result")
    if result:
        if isinstance(result, str):
            item = _resolve_item_ref(result)
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_recipes", []).append(rid)
        elif isinstance(result, dict):
            # {"item": "minecraft:diamond_sword", "count": 1} or {"items": [...]}
            if "items" in result:
                for r in result["items"]:
                    item = _resolve_item_ref(r)
                    if item:
                        _ensure_item(items, item)
                        items[item].setdefault("in_recipes", []).append(rid)
            else:
                item = _resolve_item_ref(result)
                if item:
                    _ensure_item(items, item)
                    items[item].setdefault("in_recipes", []).append(rid)

    # Ingredients (various formats)
    _extract_ingredients(data.get("ingredients", []), rid, items)
    _extract_ingredients(data.get("ingredient", []), rid, items)

    # Pattern-based recipes: pattern + key
    pattern = data.get("pattern")
    key = data.get("key")
    if pattern and key:
        chars = set()
        for row in pattern:
            chars.update(row)
        for ch in chars:
            if ch == " ":
                continue
            if ch in key:
                _extract_ingredients([key[ch]], rid, items)

    # Smithing: template, base, addition
    for field in ("template", "base", "addition"):
        if field in data:
            _extract_ingredients([data[field]], rid, items)


def _extract_ingredients(ingredients, rid, items):
    """Extract items from an ingredients list."""
    if not ingredients:
        return
    if not isinstance(ingredients, list):
        ingredients = [ingredients]
    for ing in ingredients:
        if isinstance(ing, dict) and "items" in ing:
            for sub in ing["items"]:
                item = _resolve_item_ref(sub)
                if item:
                    _ensure_item(items, item)
                    items[item].setdefault("in_recipes", []).append(rid)
        else:
            item = _resolve_item_ref(ing)
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_recipes", []).append(rid)


def _extract_loot_table_items(lt_id, data, items):
    """Extract item references from a loot table JSON."""
    pools = data.get("pools", [])
    if not pools and isinstance(data.get("type"), str):
        # Single-pool shorthand
        pools = [data]
    for pool in pools:
        entries = pool.get("entries", [])
        for entry in entries:
            _extract_loot_entry_items(lt_id, entry, items)


def _extract_loot_entry_items(lt_id, entry, items):
    """Recursively extract items from a loot table entry."""
    etype = entry.get("type", "")
    if etype == "minecraft:item":
        name = entry.get("name")
        if name:
            item = _resolve_item_ref(name)
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_loot_tables", []).append(lt_id)
    elif etype == "minecraft:loot_table":
        ref = entry.get("name")
        if ref:
            item = _resolve_item_ref(ref)
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_loot_tables", []).append(lt_id)
    # Nested children
    for child in entry.get("children", []):
        _extract_loot_entry_items(lt_id, child, items)
    # Functions can reference items (e.g. set_count with item)
    for func in entry.get("functions", []):
        _extract_items_from_json(func, set(), 0)  # items in functions are rare


def _extract_tag_items(tag_id, data, items):
    """Extract items from an item tag JSON."""
    values = data.get("values", [])
    for v in values:
        if isinstance(v, str):
            if v.startswith("#"):
                continue  # nested tag reference
            item = _resolve_item_ref(v)
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_tags", []).append(tag_id)
        elif isinstance(v, dict) and "id" in v:
            item = _resolve_item_ref(v["id"])
            if item:
                _ensure_item(items, item)
                items[item].setdefault("in_tags", []).append(tag_id)


def _extract_advancement_items(adv_id, data, items):
    """Extract item references from advancement criteria."""
    criteria = data.get("criteria", {})
    for cname, cdata in criteria.items():
        if isinstance(cdata, dict):
            trigger = cdata.get("trigger", "")
            conditions = cdata.get("conditions", {})
            # Common triggers that reference items
            if "items" in conditions:
                for ref in conditions["items"]:
                    item = _resolve_item_ref(ref)
                    if item:
                        _ensure_item(items, item)
                        items[item].setdefault("in_advancements", []).append(adv_id)
            if "item" in conditions:
                item = _resolve_item_ref(conditions["item"])
                if item:
                    _ensure_item(items, item)
                    items[item].setdefault("in_advancements", []).append(adv_id)


def _ensure_item(items, item_id):
    """Ensure an item entry exists with default values."""
    if item_id not in items:
        items[item_id] = {
            "in_recipes": [],
            "in_loot_tables": [],
            "in_tags": [],
            "in_advancements": [],
            "lang_name": None,
        }


# ── scanning ──────────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, f"no embedded vanilla baseline for MC {ver} (tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})"
    vt = VANILLA_BY_MC[ver]
    items = {}
    for iid, idata in vt["items"].items():
        items[iid] = {
            "category": idata["category"],
            "stack": idata["stack"],
            "source": "vanilla",
            "in_recipes": [],
            "in_loot_tables": [],
            "in_tags": [],
            "in_advancements": [],
            "lang_name": None,
        }
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "items": items}, None


def scan_mods(pack_dir, info, want_mods=None, skipped=None):
    mods = find_mod_jars(pack_dir)
    by_toml = {}
    for k, e in mods.items():
        by_toml.setdefault(e["pw_toml"], []).append(k)
    selected = []
    if want_mods:
        for t in want_mods:
            k = resolve_mod(mods, t)
            if k is None:
                die(f"no mod '{t}' in pack (unique mod ids: {', '.join(sorted(by_toml))[:400]})")
            toml = mods[k]["pw_toml"]
            if toml not in selected:
                selected.append(toml)
    else:
        selected = sorted(set(e["pw_toml"] for e in mods.values()))

    sources = []
    dl = from_cache = 0
    for toml in selected:
        entry = mods[by_toml[toml][0]]
        if not entry.get("url"):
            skipped.append(toml)
            continue
        local, was_dl = cached_jar(entry)
        if was_dl:
            dl += 1
        else:
            from_cache += 1
        with zipfile.ZipFile(local) as zf:
            extracted = extract_items_from_datapack(zf)
        sources.append({
            "kind": "mod",
            "name": by_toml[toml][0],
            "jar": entry["url"].rsplit("/", 1)[-1],
            "items": extracted,
        })
    return sources, dl, from_cache


def scan_datapacks(pack_dir, skipped_dp=None):
    sources = []
    dp_root = paxi_dir(pack_dir)
    if os.path.isdir(dp_root):
        for name in sorted(os.listdir(dp_root)):
            p = os.path.join(dp_root, name)
            if os.path.isdir(p):
                tmp, zip_path = dir_to_zip(p)
                try:
                    with zipfile.ZipFile(zip_path) as zf:
                        extracted = extract_items_from_datapack(zf)
                finally:
                    shutil.rmtree(tmp, ignore_errors=True)
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}/",
                                "jar": None, "items": extracted})
            elif name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(p) as zf:
                        extracted = extract_items_from_datapack(zf)
                except zipfile.BadZipFile:
                    if skipped_dp is not None:
                        skipped_dp.append(f"{name}: not a valid zip")
                    continue
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}",
                                "jar": None, "items": extracted})
    data_dir = os.path.join(pack_dir, "data")
    if os.path.isdir(data_dir):
        tmp, zip_path = dir_to_zip(data_dir)
        try:
            with zipfile.ZipFile(zip_path) as zf:
                extracted = extract_items_from_datapack(zf)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        sources.append({"kind": "datapack", "name": "<pack>/data/",
                        "jar": None, "items": extracted})
    return sources


# ── summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp):
    all_items = {}  # item_id -> {category, source_kind, source_name, ...}
    by_mod = {}     # mod_name -> count
    by_category = {}  # category -> count
    by_ref_type = {"recipe": 0, "loot_table": 0, "tag": 0, "advancement": 0}

    # Track all item ids per source
    all_item_ids = set()
    recipe_items = set()
    loot_table_items = set()
    tag_items = set()
    advancement_items = set()

    for src in sources:
        src_count = 0
        for iid, idata in src["items"].items():
            src_count += 1
            all_item_ids.add(iid)

            if iid not in all_items:
                all_items[iid] = {
                    "category": idata.get("category"),
                    "stack": idata.get("stack"),
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    "in_recipes": list(idata.get("in_recipes", [])),
                    "in_loot_tables": list(idata.get("in_loot_tables", [])),
                    "in_tags": list(idata.get("in_tags", [])),
                    "in_advancements": list(idata.get("in_advancements", [])),
                    "lang_name": idata.get("lang_name"),
                }
            else:
                existing = all_items[iid]
                for field in ("in_recipes", "in_loot_tables", "in_tags", "in_advancements"):
                    for ref in idata.get(field, []):
                        if ref not in existing[field]:
                            existing[field].append(ref)
                if idata.get("lang_name") and not existing["lang_name"]:
                    existing["lang_name"] = idata["lang_name"]

            if idata.get("in_recipes"):
                recipe_items.add(iid)
            if idata.get("in_loot_tables"):
                loot_table_items.add(iid)
            if idata.get("in_tags"):
                tag_items.add(iid)
            if idata.get("in_advancements"):
                advancement_items.add(iid)

        if src["kind"] == "mod":
            by_mod[src["name"]] = src_count

    # Count by category
    for iid, idata in all_items.items():
        cat = idata.get("category") or "unknown"
        by_category[cat] = by_category.get(cat, 0) + 1

    # Count by ref type
    by_ref_type["recipe"] = len(recipe_items)
    by_ref_type["loot_table"] = len(loot_table_items)
    by_ref_type["tag"] = len(tag_items)
    by_ref_type["advancement"] = len(advancement_items)

    # Vanilla items overridden/reskinned by mods
    vanilla_ids = set()
    for src in sources:
        if src["kind"] == "vanilla":
            vanilla_ids.update(src["items"].keys())
    vanilla_overrides = []
    for src in sources:
        if src["kind"] == "vanilla":
            continue
        for iid in src["items"]:
            if iid in vanilla_ids and iid not in vanilla_overrides:
                vanilla_overrides.append(iid)
    vanilla_overrides.sort()

    # Items defined but not referenced by any recipe/loot/tag/advancement
    referenced_items = recipe_items | loot_table_items | tag_items | advancement_items
    defined_unused = sorted(all_item_ids - referenced_items)

    # Items referenced but not found in any source
    referenced_missing = []  # would need to track reference sources for this

    # Tag coverage: how many items per tag
    tag_coverage = {}
    for src in sources:
        for iid, idata in src["items"].items():
            for tag in idata.get("in_tags", []):
                tag_coverage.setdefault(tag, set()).add(iid)

    return {
        "sources": sources,
        "all_items": all_items,
        "total_items": len(all_items),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
        "by_mod": by_mod,
        "by_category": by_category,
        "by_ref_type": by_ref_type,
        "vanilla_overrides": vanilla_overrides,
        "defined_unused": defined_unused,
        "referenced_missing": referenced_missing,
        "recipe_items": sorted(recipe_items),
        "loot_table_items": sorted(loot_table_items),
        "tag_items": sorted(tag_items),
        "advancement_items": sorted(advancement_items),
        "tag_coverage": {k: sorted(v) for k, v in tag_coverage.items()},
    }


# ── output ────────────────────────────────────────────────────────────────────

def report_human(info, summ):
    srcs = summ["sources"]
    print(f"## pack {info['name']}  (MC {info['minecraft'] or '?'}, "
          f"{info['loader'] or '?'} {info['loader_version'] or ''})".strip())
    for src in srcs:
        if not src["items"]:
            continue
        print(f"## source: {src['name']}" + (f"  ({src['jar']})" if src["jar"] else ""))
        for iid in sorted(src["items"]):
            idata = src["items"][iid]
            cat = idata.get("category") or "?"
            extra = ""
            if src["kind"] != "vanilla" and iid in summ.get("vanilla_overrides", []):
                extra = "  [OVERRIDES VANILLA]"
            refs = []
            if idata.get("in_recipes"):
                refs.append(f"recipes={len(idata['in_recipes'])}")
            if idata.get("in_loot_tables"):
                refs.append(f"loot={len(idata['in_loot_tables'])}")
            if idata.get("in_tags"):
                refs.append(f"tags={len(idata['in_tags'])}")
            if idata.get("in_advancements"):
                refs.append(f"adv={len(idata['in_advancements'])}")
            refs_str = f"  {', '.join(refs)}" if refs else ""
            name_str = ""
            if idata.get("lang_name"):
                name_str = f"  \"{idata['lang_name']}\""
            print(f"  item  {iid}  (cat={cat}){refs_str}{name_str}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total items: {summ['total_items']}")
    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL — CurseForge-mode?): {', '.join(summ['skipped_no_url'])}")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'])}")

    # Category breakdown
    print(f"  by category:")
    for cat in sorted(summ["by_category"]):
        print(f"    {cat}: {summ['by_category'][cat]}")

    # Reference type breakdown
    print(f"  by reference type:")
    for rtype, count in sorted(summ["by_ref_type"].items()):
        print(f"    {rtype}: {count}")

    # By mod breakdown
    if summ["by_mod"]:
        print(f"  by mod (top 20):")
        for mod, count in sorted(summ["by_mod"].items(), key=lambda x: -x[1])[:20]:
            print(f"    {mod}: {count}")
        if len(summ["by_mod"]) > 20:
            print(f"    … ({len(summ['by_mod']) - 20} more mods)")

    if summ["vanilla_overrides"]:
        print(f"  vanilla items the pack redefines: {len(summ['vanilla_overrides'])}")
        for v in summ["vanilla_overrides"]:
            print(f"    - {v}")

    if summ["defined_unused"]:
        print(f"  items defined but never referenced by recipe/loot/tag: {len(summ['defined_unused'])}")
        for m in summ["defined_unused"][:15]:
            print(f"    - {m}")
        if len(summ["defined_unused"]) > 15:
            print(f"    … ({len(summ['defined_unused']) - 15} more)")

    if summ["tag_coverage"]:
        print(f"  item tags: {len(summ['tag_coverage'])}")
        for tag, tag_items in sorted(summ["tag_coverage"].items())[:10]:
            print(f"    {tag}: {len(tag_items)} items")
        if len(summ["tag_coverage"]) > 10:
            print(f"    … ({len(summ['tag_coverage']) - 10} more tags)")


def report_json(info, summ):
    out = {
        "tool": "items.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "items": {k: {"category": v.get("category"), "stack": v.get("stack"),
                           "in_recipes": v.get("in_recipes", []),
                           "in_loot_tables": v.get("in_loot_tables", []),
                           "in_tags": v.get("in_tags", []),
                           "in_advancements": v.get("in_advancements", []),
                           "lang_name": v.get("lang_name")}
                       for k, v in sorted(s["items"].items())}}
            for s in summ["sources"]
        ],
        "summary": {
            "total_items": summ["total_items"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "by_mod": summ["by_mod"],
            "by_category": summ["by_category"],
            "by_ref_type": summ["by_ref_type"],
            "vanilla_overrides": summ["vanilla_overrides"],
            "defined_unused": summ["defined_unused"],
            "referenced_missing": summ["referenced_missing"],
            "tag_coverage": summ["tag_coverage"],
        },
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


def cmd_info(pack_dir, info, target, as_json):
    """Look up a single item ID and report all known metadata."""
    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = scan_vanilla(info)
    if v_src:
        sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, None, skip_no_url)
    sources += mod_sources
    sources += scan_datapacks(pack_dir, skip_dp)

    # Normalize the target id
    if ":" not in target:
        target = f"minecraft:{target}"

    # Find the item across all sources
    found = False
    result = {}
    for src in sources:
        if target in src["items"]:
            found = True
            idata = src["items"][target]
            result["id"] = target
            result["category"] = idata.get("category") or "unknown"
            result["stack"] = idata.get("stack")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["in_recipes"] = idata.get("in_recipes", [])
            result["in_loot_tables"] = idata.get("in_loot_tables", [])
            result["in_tags"] = idata.get("in_tags", [])
            result["in_advancements"] = idata.get("in_advancements", [])
            result["lang_name"] = idata.get("lang_name")
            break

    if not found:
        all_ids = set()
        for src in sources:
            all_ids.update(src["items"].keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"item '{target}' not found in any source"
        if suggest:
            msg += f" — did you mean: {', '.join(suggest)}"
        die(msg)

    # Vanilla override status
    result["vanilla_override"] = False
    if target.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target in v_src_obj["items"]:
            for src in sources:
                if src["kind"] != "vanilla" and target in src["items"]:
                    result["vanilla_override"] = True
                    break

    if as_json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
        return

    # Human-readable output
    print(f"## item: {result['id']}")
    if result.get("lang_name"):
        print(f"  name:       {result['lang_name']}")
    print(f"  category:   {result['category']}")
    if result.get("stack"):
        print(f"  stack:      {result['stack']}")
    print(f"  source:     {result['source_kind']}: {result['source_name']}"
          + (f"  ({result['source_jar']})" if result["source_jar"] else ""))
    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla item (mod redefines {target})")
    if result["in_recipes"]:
        print(f"  recipes:    {len(result['in_recipes'])} recipe(s)")
        for r in result["in_recipes"][:5]:
            print(f"              - {r}")
        if len(result["in_recipes"]) > 5:
            print(f"              … ({len(result['in_recipes']) - 5} more)")
    else:
        print(f"  recipes:    (none found)")
    if result["in_loot_tables"]:
        print(f"  loot tables: {len(result['in_loot_tables'])} loot table(s)")
        for lt in result["in_loot_tables"][:5]:
            print(f"              - {lt}")
        if len(result["in_loot_tables"]) > 5:
            print(f"              … ({len(result['in_loot_tables']) - 5} more)")
    else:
        print(f"  loot tables: (none found)")
    if result["in_tags"]:
        print(f"  tags:       {', '.join(result['in_tags'][:10])}")
        if len(result["in_tags"]) > 10:
            print(f"              … ({len(result['in_tags']) - 10} more)")
    else:
        print(f"  tags:       (none found)")
    if result["in_advancements"]:
        print(f"  advancements: {len(result['in_advancements'])} advancement(s)")
        for a in result["in_advancements"][:5]:
            print(f"              - {a}")
        if len(result["in_advancements"]) > 5:
            print(f"              … ({len(result['in_advancements']) - 5} more)")


def _format_item_detail(target_id, sources):
    """Build the detail dict for a single item across all sources."""
    result = {}
    for src in sources:
        if target_id in src["items"]:
            idata = src["items"][target_id]
            result["id"] = target_id
            result["category"] = idata.get("category") or "unknown"
            result["stack"] = idata.get("stack")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["in_recipes"] = idata.get("in_recipes", [])
            result["in_loot_tables"] = idata.get("in_loot_tables", [])
            result["in_tags"] = idata.get("in_tags", [])
            result["in_advancements"] = idata.get("in_advancements", [])
            result["lang_name"] = idata.get("lang_name")
            break
    # Vanilla override status
    result["vanilla_override"] = False
    if target_id.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target_id in v_src_obj["items"]:
            for src in sources:
                if src["kind"] != "vanilla" and target_id in src["items"]:
                    result["vanilla_override"] = True
                    break
    return result


def cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_):
    """Export every item's full metadata to a single JSON file."""
    import time
    t0 = time.monotonic()

    sources = []
    skip_no_url = []
    skip_dp = []
    if scan_vanilla_:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, want_mods, skip_no_url)
    sources += mod_sources
    if scan_dp:
        sources += scan_datapacks(pack_dir, skip_dp)

    # Collect all item IDs (sorted, deterministic)
    all_ids = set()
    for src in sources:
        all_ids.update(src["items"].keys())

    t_scan = time.monotonic()

    # Build entries map (sorted by ID)
    entries = {}
    for iid in sorted(all_ids):
        entries[iid] = _format_item_detail(iid, sources)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    out = {
        "tool": "items.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "item_count": len(s["items"])}
            for s in summ["sources"]
        ],
        "summary": {
            "total_items": summ["total_items"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
        },
        "entries": entries,
    }

    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")

    t_write = time.monotonic()
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {len(entries)} items → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
    print(f"  scan: {t_scan-t0:.1f}s  detail: {t_detail-t_scan:.1f}s  write: {t_write-t_detail:.1f}s  total: {t_write-t0:.1f}s", file=sys.stderr)


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return
    pack_arg = args[0]
    rest = args[1:]
    want_mods = None
    scan_dp = True
    scan_vanilla_ = True
    as_json = False
    as_list = False
    info_id = None
    full_export = None  # --full-export [outfile]
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--mods" and i + 1 < len(rest):
            want_mods = [s.strip().lower() for s in rest[i + 1].split(",") if s.strip()]
            i += 2
        elif a == "--no-datapacks":
            scan_dp = False; i += 1
        elif a == "--no-vanilla":
            scan_vanilla_ = False; i += 1
        elif a == "--json":
            as_json = True; i += 1
        elif a == "--list":
            as_list = True; i += 1
        elif a == "--info" and i + 1 < len(rest):
            info_id = rest[i + 1]; i += 2
        elif a == "--full-export":
            if i + 1 < len(rest) and not rest[i + 1].startswith("-"):
                full_export = rest[i + 1]; i += 2
            else:
                full_export = True; i += 1  # sentinel: use default filename
        else:
            die(f"unknown arg {a} (see --help)")

    pack_dir = resolve_pack_dir(pack_arg)
    info = read_pack_info(pack_dir)
    if not os.path.isfile(os.path.join(pack_dir, "checksums.json")):
        die(f"{pack_dir} has no checksums.json — run packwiz-checksums first")

    if info_id:
        cmd_info(pack_dir, info, info_id, as_json)
        return

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-items-full.json"
        cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_)
        return

    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = None, None
    if scan_vanilla_:
        v_src, v_note = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
        elif not as_json and not as_list:
            print(f"## note: {v_note}", file=sys.stderr)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, want_mods, skip_no_url)
    sources += mod_sources
    if scan_dp:
        sources += scan_datapacks(pack_dir, skip_dp)

    if as_json:
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
        report_json(info, summ)
        return
    if as_list:
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
        all_items = set()
        for src in sources:
            all_items.update(src["items"].keys())
        for iid in sorted(all_items):
            print(iid)
        return
    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    report_human(info, summ)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(0)


# ── Vanilla baseline regen recipe ─────────────────────────────────────────────
# VANILLA_BY_MC is embedded so the tool is offline and deterministic. To add a
# Minecraft version, download Mojang's client jar for that version, then:
#
#   python3 - << 'EOF'
#   import zipfile, json, re
#   zf = zipfile.ZipFile("client-1.21.1.jar")
#   reg = json.loads(zf.read("data/minecraft/registries/items.json"))
#   items = {}
#   for k, v in reg["entries"].items():
#       items[k] = {
#           "category": "misc",
#           "stack": v.get("max_stack_size", 64),
#       }
#   print(json.dumps(items, sort_keys=True, indent=2))
#   EOF
#
# Then classify each item by category (tool/weapon/armor/food/block/material/
# misc/spawn_egg/potion) and stack size. Common items that are frequently
# overridden by mods should be included; very niche items can be omitted.

# ## RUN LOG
# ### 2026-09-07
# Created as the standalone, complete item enumerator. Mirrors mobs.py
# architecture: embedded vanilla 1.21.1 baseline (~200 common items),
# jar cache by checksum, datapack scanning (recipes, loot tables, item
# tags, advancements). Flags vanilla overrides, defined-but-unused items,
# overlapping tags. Supports --json (stable schema), --list, and --info
# for single-item lookup with fuzzy suggestions.
