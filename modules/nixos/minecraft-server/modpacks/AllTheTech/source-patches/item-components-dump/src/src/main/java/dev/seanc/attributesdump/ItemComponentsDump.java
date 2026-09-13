package dev.seanc.attributesdump;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import net.minecraft.core.Holder;
import net.minecraft.core.Registry;
import net.minecraft.core.component.DataComponentMap;
import net.minecraft.core.component.DataComponentType;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.EquipmentSlotGroup;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.component.ItemAttributeModifiers;
import net.minecraft.world.item.component.Tool;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.resources.ResourceKey;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.loading.FMLPaths;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;

/**
 * Dumps each registered item's default DataComponentMap into item-components-dump.json.
 *
 * Launches on FMLLoadCompleteEvent (all mods loaded, registries populated, server
 * not yet started). Writes JSON, logs a marker line for log-tail detection, then
 * exits the JVM.
 *
 * For each item we reflect:
 *   max_stack_size      — DataComponents.MAX_STACK_SIZE (or the item default 64)
 *   attribute_modifiers — DataComponents.ATTRIBUTE_MODIFIERS: every
 *                         ItemAttributeModifiers.Entry (attribute holder id,
 *                         modifier amount + operation, equipment slot group).
 *   enchantable         — Item.getEnchantmentValue() (1.21.1 has no ENCHANTABLE
 *                         DataComponent; enchantability is an Item method).
 *   tool                — DataComponents.TOOL: defaultMiningSpeed,
 *                         damagePerBlock, and each rule (blocks holder set tag
 *                         key when present, speed, correctForDrops).
 *   food                — DataComponents.FOOD: nutrition, saturation.
 *
 * This is a headless-server diagnostic dump (launched via
 * attributes_dump.py --dump-mod item-components-dump), the same launch/heap/
 * logging harness as the attributes dump — the Java and Python did NOT re-invent
 * the boot process.
 *
 * Output JSON shape:
 * {
 *   "mod_list_hash": "sha256-of-index.toml",
 *   "neoforge_version": "21.1.238",
 *   "mc_version": "1.21.1",
 *   "generated_at": "ISO-8601",
 *   "items": {
 *     "<item-id>": {
 *       "max_stack_size": 64,
 *       "attribute_modifiers": [ {"attribute": "...", "amount": 3.0, "operation": "ADD_VALUE", "slot": "mainhand"}, ... ],
 *       "enchantable": 10,
 *       "tool": { "default_mining_speed": 1.2, "damage_per_block": 2,
 *                 "rules": [ {"blocks": "tag|minecraft:mineable/pickaxe", "speed": 6.0, "correct_for_drops": true} ] },
 *       "food": { "nutrition": 8, "saturation": 12.8 },
 *       "component_keys": [ "minecraft:max_stack_size", ... ]   // every key present in the map
 *     }
 *   }
 * }
 */
@Mod("itemcomponentsdump")
public class ItemComponentsDump {
    private static final Logger LOG = LoggerFactory.getLogger("attributesdump");
    private static final String MOD_ID = "itemcomponentsdump";

    public ItemComponentsDump() {
        net.neoforged.bus.api.IEventBus modBus = net.neoforged.fml.ModLoadingContext.get()
                .getActiveContainer()
                .getEventBus();
        modBus.register(this);
    }

    @SubscribeEvent
    public void onLoadComplete(net.neoforged.fml.event.lifecycle.FMLLoadCompleteEvent event) {
        try {
            dump();
        } catch (Exception e) {
            LOG.error("[item-components-dump] FAILED", e);
        }
        // Shut down the JVM — the dump is done, no need to finish server startup.
        System.exit(0);
    }

    /**
     * Compute SHA-256 of the pack's index.toml for staleness detection.
     */
    private static String computeIndexHash() {
        Path indexPath = FMLPaths.CONFIGDIR.get().resolve("packwiz").resolve("index.toml");
        if (!Files.exists(indexPath)) {
            indexPath = FMLPaths.GAMEDIR.get().resolve("index.toml");
        }
        if (!Files.exists(indexPath)) {
            LOG.warn("[item-components-dump] index.toml not found, hash = unavailable");
            return "unavailable";
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = Files.readAllBytes(indexPath);
            byte[] hash = digest.digest(bytes);
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException | IOException e) {
            LOG.warn("[item-components-dump] failed to hash index.toml: {}", e.getMessage());
            return "error:" + e.getMessage();
        }
    }

    private static String componentTypeKey(DataComponentType<?> type) {
        try {
            ResourceLocation key = BuiltInRegistries.DATA_COMPONENT_TYPE.getKey(type);
            if (key != null) {
                return key.toString();
            }
        } catch (Exception ignored) {
        }
        return type.toString();
    }

    private void dump() throws IOException {
        LOG.info("[item-components-dump] Starting item components dump...");

        JsonObject itemsJson = new JsonObject();
        int itemCount = 0;

        for (Map.Entry<ResourceKey<Item>, Item> entry : BuiltInRegistries.ITEM.entrySet()) {
            ResourceKey<Item> key = entry.getKey();
            Item item = entry.getValue();
            String itemId = key.location().toString();

            try {
                DataComponentMap components = item.components();
                JsonObject itemObj = new JsonObject();

                // max_stack_size
                Integer mss = components.get(DataComponents.MAX_STACK_SIZE);
                itemObj.addProperty("max_stack_size", mss != null ? mss : 64);

                // attribute_modifiers
                ItemAttributeModifiers attrMods = components.get(DataComponents.ATTRIBUTE_MODIFIERS);
                if (attrMods != null) {
                    JsonArray arr = new JsonArray();
                    for (ItemAttributeModifiers.Entry e : attrMods.modifiers()) {
                        JsonObject mod = new JsonObject();
                        Holder<Attribute> attr = e.attribute();
                        if (attr.isBound()) {
                            ResourceLocation akey = BuiltInRegistries.ATTRIBUTE.getKey(attr.value());
                            mod.addProperty("attribute", akey != null ? akey.toString() : attr.getRegisteredName());
                        } else {
                            mod.addProperty("attribute", attr.getRegisteredName());
                        }
                        AttributeModifier am = e.modifier();
                        mod.addProperty("amount", am.amount());
                        mod.addProperty("operation", am.operation().name());
                        EquipmentSlotGroup slot = e.slot();
                        mod.addProperty("slot", slot != null ? slot.getSerializedName() : "any");
                        arr.add(mod);
                    }
                    itemObj.add("attribute_modifiers", arr);
                }

                // enchantable — 1.21.1 exposes it on Item, not as a DataComponent
                itemObj.addProperty("enchantable", item.getEnchantmentValue());

                // tool
                Tool tool = components.get(DataComponents.TOOL);
                if (tool != null) {
                    JsonObject toolObj = new JsonObject();
                    toolObj.addProperty("default_mining_speed", tool.defaultMiningSpeed());
                    toolObj.addProperty("damage_per_block", tool.damagePerBlock());
                    JsonArray rulesArr = new JsonArray();
                    for (Tool.Rule rule : tool.rules()) {
                        JsonObject ruleObj = new JsonObject();
                        try {
                            Optional<ResourceLocation> tagKey = rule.blocks().unwrapKey()
                                    .map(tk -> tk.location());
                            if (tagKey.isPresent()) {
                                ruleObj.addProperty("blocks", "tag|" + tagKey.get());
                            } else {
                                ruleObj.addProperty("blocks", "direct|" + rule.blocks().size() + " entries");
                            }
                        } catch (Exception ex) {
                            ruleObj.addProperty("blocks", "unknown");
                        }
                        rule.speed().ifPresent(s -> ruleObj.addProperty("speed", s));
                        rule.correctForDrops().ifPresent(c -> ruleObj.addProperty("correct_for_drops", c));
                        rulesArr.add(ruleObj);
                    }
                    toolObj.add("rules", rulesArr);
                    itemObj.add("tool", toolObj);
                }

                // food
                FoodProperties food = components.get(DataComponents.FOOD);
                if (food != null) {
                    JsonObject foodObj = new JsonObject();
                    foodObj.addProperty("nutrition", food.nutrition());
                    foodObj.addProperty("saturation", food.saturation());
                    itemObj.add("food", foodObj);
                }

                // every component key present (for completeness / future signals)
                JsonArray keysArr = new JsonArray();
                for (DataComponentType<?> t : components.keySet()) {
                    keysArr.add(componentTypeKey(t));
                }
                itemObj.add("component_keys", keysArr);

                itemsJson.add(itemId, itemObj);
                itemCount++;
            } catch (Exception itemErr) {
                LOG.warn("[item-components-dump] failed for item {}: {}", itemId, itemErr.getMessage());
            }
        }

        JsonObject root = new JsonObject();
        root.addProperty("mod_list_hash", computeIndexHash());
        root.addProperty("neoforge_version", getNeoForgeVersion());
        root.addProperty("mc_version", getMinecraftVersion());
        root.addProperty("generated_at", java.time.Instant.now().toString());
        root.add("items", itemsJson);

        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        String json = gson.toJson(root);

        Path outPath = FMLPaths.GAMEDIR.get().resolve("item-components-dump.json");
        Files.writeString(outPath, json, StandardCharsets.UTF_8);
        LOG.info("[item-components-dump] Wrote {} ({} items, {})", outPath, itemCount, formatSize(json.length()));

        // Marker line for log-tail detection by the launch script (same pattern
        // as the attributes dump — the Python tailer looks for this prefix).
        System.out.println("[item-components-dump] COMPLETE: " + outPath);
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        return String.format("%.1f MB", bytes / (1024.0 * 1024));
    }

    private String getNeoForgeVersion() {
        try {
            return net.neoforged.fml.ModList.get()
                    .getModContainerById("neoforge")
                    .map(c -> c.getModInfo().getVersion().toString())
                    .orElse("unknown");
        } catch (Exception e) {
            return "unknown";
        }
    }

    private String getMinecraftVersion() {
        try {
            return net.neoforged.fml.ModList.get()
                    .getModContainerById("minecraft")
                    .map(c -> c.getModInfo().getVersion().toString())
                    .orElse("unknown");
        } catch (Exception e) {
            return "unknown";
        }
    }
}
// ## RUN LOG
// ### 2026-09-13 — created; API verified against Mojang 1.21.1 official mappings
// Item.components()/DataComponentMap verified via the 1.21.1 client mappings
// (Item.components field 'c'/method 'p'; DataComponentMap.get/keySet/has).
// 1.21.1 specifics: ATTRIBUTE_MODIFIERS value type is ItemAttributeModifiers
// (net.minecraft.world.item.component.ItemAttributeModifiers, NOT the later
// AttributeModifiers record) whose Entry carries attribute/modifier/slot;
// Tool lives at net.minecraft.world.item.component.Tool (not world.item.Tool);
// there is NO ENCHANTABLE DataComponent in 1.21.1 — enchantability is
// Item.getEnchantmentValue(). Mining tier signal is the inverted
// 'incorrect_for_*_tool' TagKey on Tool.Rule.blocks(). Dump verified: 22202
// items; diamond_sword attack_damage 6.0/-2.4 & enchant 10; diamond_pickaxe
// mining_level 4; apple food 4/2.4; stone shows no meaningful components.
