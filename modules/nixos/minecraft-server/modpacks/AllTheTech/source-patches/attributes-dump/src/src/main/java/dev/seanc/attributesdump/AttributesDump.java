package dev.seanc.attributesdump;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.loading.FMLPaths;
import net.neoforged.neoforge.common.CommonHooks;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Stream;

/**
 * Dumps all registered entity base attribute values into attributes-dump.json.
 *
 * Launches on FMLLoadCompleteEvent (all mods loaded, registries populated, server
 * not yet started — no level loading triggered). Writes JSON, logs a marker line
 * for log-tail detection, then exits the JVM.
 *
 * Output JSON shape:
 * {
 *   "mod_list_hash": "sha256-of-index-toml",
 *   "neoforge_version": "21.1.238",
 *   "mc_version": "1.21.1",
 *   "generated_at": "ISO-8601",
 *   "attributes": { <attr-id>: { "base_value": N, "entities": { <entity-id>: N } } },
 *   "default_attributes": { <entity-id>: { <attr-id>: N } }
 * }
 *
 * The "attributes" section is the active (potentially mod-modified) view, read
 * via CommonHooks.getAttributesView() which returns NeoForge's FORGE_ATTRIBUTES
 * map. The "default_attributes" section is the pristine vanilla default for each
 * *vanilla* entity type, read reflectively from DefaultAttributes.SUPPLIERS.
 * The vanilla defaults are the true per-entity values from Minecraft's own static
 * initializer (e.g. cow has 10 HP, not the attribute's generic 20 HP default).
 * Mod-added entity types are NOT present in default_attributes.
 */
@Mod("attributesdump")
public class AttributesDump {
    private static final Logger LOG = LoggerFactory.getLogger("attributesdump");
    private static final String MOD_ID = "attributesdump";

    public AttributesDump() {
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
            LOG.error("[attributes-dump] FAILED", e);
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
            // Try the game directory root (packwiz sometimes puts index.toml at root)
            indexPath = FMLPaths.GAMEDIR.get().resolve("index.toml");
        }
        if (!Files.exists(indexPath)) {
            LOG.warn("[attributes-dump] index.toml not found, hash = unavailable");
            return "unavailable";
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = Files.readAllBytes(indexPath);
            byte[] hash = digest.digest(bytes);
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException | IOException e) {
            LOG.warn("[attributes-dump] failed to hash index.toml: {}", e.getMessage());
            return "error:" + e.getMessage();
        }
    }

    /**
     * Get the string form of an EntityType registry key (e.g. "minecraft:zombie").
     */
    private static String entityTypeName(net.minecraft.world.entity.EntityType<?> entityType) {
        ResourceLocation key = BuiltInRegistries.ENTITY_TYPE.getKey(entityType);
        return key != null ? key.toString() : entityType.getDescriptionId();
    }

    /**
     * Get the string form of an Attribute registry key (e.g. "minecraft:generic.max_health").
     */
    private static String attributeTypeName(net.minecraft.world.entity.ai.attributes.Attribute attribute) {
        ResourceLocation key = BuiltInRegistries.ATTRIBUTE.getKey(attribute);
        return key != null ? key.toString() : attribute.getDescriptionId();
    }

    /**
     * Get the string form of an Attribute from a Holder.
     */
    private static String attributeTypeNameFromHolder(net.minecraft.core.Holder<net.minecraft.world.entity.ai.attributes.Attribute> holder) {
        if (holder.isBound()) {
            return attributeTypeName(holder.value());
        }
        // Fallback for unbound holders
        return holder.getRegisteredName();
    }

    private void dump() throws IOException {
        LOG.info("[attributes-dump] Starting attribute dump...");

        // --- Collect base values for vanilla attributes (for source classification) ---
        Map<String, Double> vanillaBaseValues = new TreeMap<>();
        try {
            // Vanilla server creates a temporary level to populate default attributes.
            // We can't do that here, but we can check the attribute's default value.
            // The vanilla base values are well-known; we'll hardcode the common ones
            // and flag anything that doesn't match a vanilla attribute as "modded_added".
            // Actually, the correct approach: compare against what vanilla would register.
            // Since we can't easily run vanilla attribute registration, we use the
            // attribute's built-in default value (which IS the vanilla base).
            BuiltInRegistries.ATTRIBUTE.holders().forEach(holder -> {
                if (holder.isBound()) {
                    vanillaBaseValues.put(
                        attributeTypeNameFromHolder(holder),
                        holder.value().getDefaultValue()
                    );
                }
            });
        } catch (Exception e) {
            LOG.warn("[attributes-dump] Failed to collect vanilla attribute defaults: {}", e.getMessage());
        }

        // --- Collect registered entity attribute suppliers ---
        Map<String, Map<String, Double>> entityAttributes = new TreeMap<>();
        // getAttributesView() returns Map<EntityType<? extends LivingEntity>, AttributeSupplier>
        Map<? extends net.minecraft.world.entity.EntityType<?>, net.minecraft.world.entity.ai.attributes.AttributeSupplier> forgeAttrs = CommonHooks.getAttributesView();

        for (var entry : forgeAttrs.entrySet()) {
            String entityName = entityTypeName(entry.getKey());
            net.minecraft.world.entity.ai.attributes.AttributeSupplier supplier = entry.getValue();
            Map<String, Double> attrs = new TreeMap<>();

            BuiltInRegistries.ATTRIBUTE.holders().forEach(holder -> {
                if (holder.isBound()) {
                    // hasAttribute() and getBaseValue() take Holder<Attribute>, not raw Attribute
                    if (supplier.hasAttribute(holder)) {
                        attrs.put(attributeTypeNameFromHolder(holder), supplier.getBaseValue(holder));
                    }
                }
            });

            if (!attrs.isEmpty()) {
                entityAttributes.put(entityName, attrs);
            }
        }

        // --- Build the transposed view: attribute -> { entities -> values } ---
        Map<String, JsonObject> attributeMap = new TreeMap<>();

        for (Map.Entry<String, Map<String, Double>> entityEntry : entityAttributes.entrySet()) {
            String entityName = entityEntry.getKey();
            for (Map.Entry<String, Double> attrEntry : entityEntry.getValue().entrySet()) {
                String attrName = attrEntry.getKey();
                double value = attrEntry.getValue();

                attributeMap.computeIfAbsent(attrName, k -> {
                    JsonObject obj = new JsonObject();
                    obj.addProperty("base_value", getVanillaDefault(vanillaBaseValues, k));
                    obj.add("entities", new JsonObject());
                    return obj;
                });

                attributeMap.get(attrName).getAsJsonObject("entities").addProperty(entityName, value);
            }
        }

        // --- Classify source field: vanilla / modded_added / modded_modified ---
        for (Map.Entry<String, JsonObject> attrEntry : attributeMap.entrySet()) {
            String attrName = attrEntry.getKey();
            JsonObject attrObj = attrEntry.getValue();
            JsonObject entities = attrObj.getAsJsonObject("entities");

            Double vanillaDefault = vanillaBaseValues.get(attrName);
            boolean existsInVanilla = vanillaDefault != null;

            if (!existsInVanilla) {
                // Attribute not in vanilla registry -> entirely mod-added
                attrObj.addProperty("source", "modded_added");
            } else {
                // Check if any entity has a different base value than vanilla default
                boolean anyModified = false;
                for (String entityName : entities.keySet()) {
                    double val = entities.get(entityName).getAsDouble();
                    if (Math.abs(val - vanillaDefault) > 1e-6) {
                        anyModified = true;
                        break;
                    }
                }
                if (anyModified) {
                    attrObj.addProperty("source", "modded_modified");
                } else {
                    attrObj.addProperty("source", "vanilla");
                }
            }
        }

        // --- Collect true vanilla defaults from DefaultAttributes.SUPPLIERS ---
        // NeoForge stores its attribute overrides in a SEPARATE map (CommonHooks.FORGE_ATTRIBUTES).
        // The original DefaultAttributes.SUPPLIERS field retains the pristine vanilla values.
        // We access it reflectively since it's private.
        Map<String, Map<String, Double>> defaultAttributesMap = collectDefaultAttributes();
        if (!defaultAttributesMap.isEmpty()) {
            LOG.info("[attributes-dump] Collected {} vanilla entity defaults from DefaultAttributes", defaultAttributesMap.size());
        }

        // --- Assemble final JSON ---
        JsonObject root = new JsonObject();
        root.addProperty("mod_list_hash", computeIndexHash());
        root.addProperty("neoforge_version", getNeoForgeVersion());
        root.addProperty("mc_version", getMinecraftVersion());
        root.addProperty("generated_at", java.time.Instant.now().toString());

        JsonObject attrsJson = new JsonObject();
        attributeMap.forEach(attrsJson::add);
        root.add("attributes", attrsJson);

        // Add the pristine vanilla defaults as a separate entity-centric section
        JsonObject defaultAttrsJson = new JsonObject();
        for (Map.Entry<String, Map<String, Double>> entityEntry : defaultAttributesMap.entrySet()) {
            JsonObject entityAttrs = new JsonObject();
            for (Map.Entry<String, Double> attrEntry : entityEntry.getValue().entrySet()) {
                entityAttrs.addProperty(attrEntry.getKey(), attrEntry.getValue());
            }
            defaultAttrsJson.add(entityEntry.getKey(), entityAttrs);
        }
        root.add("default_attributes", defaultAttrsJson);

        // --- Write output ---
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        String json = gson.toJson(root);

        Path outPath = FMLPaths.GAMEDIR.get().resolve("attributes-dump.json");
        Files.writeString(outPath, json, StandardCharsets.UTF_8);
        LOG.info("[attributes-dump] Wrote {} to {}", outPath, formatSize(json.length()));

        // Print a marker line for log-tail detection by the launch script
        System.out.println("[attributes-dump] COMPLETE: " + outPath);
    }

    private double getVanillaDefault(Map<String, Double> vanillaDefaults, String attrName) {
        Double d = vanillaDefaults.get(attrName);
        return d != null ? d : 0.0;
    }

    /**
     * Read DefaultAttributes.SUPPLIERS reflectively to get the pristine vanilla
     * per-entity attribute defaults. NeoForge stores mod overrides in a separate
     * map (CommonHooks.FORGE_ATTRIBUTES) and patches DefaultAttributes.getSupplier()
     * to check FORGE_ATTRIBUTES first, then fall back to SUPPLIERS — so the original
     * SUPPLIERS field retains true vanilla values for every vanilla LivingEntity type.
     *
     * Returns entity-centric: { "entity:id": { "attr:name": value, ... }, ... }
     * or an empty map if reflection fails.
     */
    @SuppressWarnings("unchecked")
    private static Map<String, Map<String, Double>> collectDefaultAttributes() {
        Map<String, Map<String, Double>> result = new TreeMap<>();
        try {
            // Find the SUPPLIERS field by name or by type fallback
            Field suppliersField = null;
            try {
                suppliersField = net.minecraft.world.entity.ai.attributes.DefaultAttributes.class.getDeclaredField("SUPPLIERS");
            } catch (NoSuchFieldException e) {
                // Fallback: scan all declared fields for one of type Map
                for (Field f : net.minecraft.world.entity.ai.attributes.DefaultAttributes.class.getDeclaredFields()) {
                    if (Map.class.isAssignableFrom(f.getType())) {
                        suppliersField = f;
                        break;
                    }
                }
            }
            if (suppliersField == null) {
                LOG.warn("[attributes-dump] Could not find SUPPLIERS field in DefaultAttributes");
                return result;
            }
            suppliersField.setAccessible(true);
            Map<? extends net.minecraft.world.entity.EntityType<?>, net.minecraft.world.entity.ai.attributes.AttributeSupplier> suppliers;
            suppliers = (Map<? extends net.minecraft.world.entity.EntityType<?>, net.minecraft.world.entity.ai.attributes.AttributeSupplier>) suppliersField.get(null);

            for (Map.Entry<? extends net.minecraft.world.entity.EntityType<?>, net.minecraft.world.entity.ai.attributes.AttributeSupplier> entry : suppliers.entrySet()) {
                String entityName = entityTypeName(entry.getKey());
                net.minecraft.world.entity.ai.attributes.AttributeSupplier supplier = entry.getValue();
                Map<String, Double> attrs = new TreeMap<>();

                BuiltInRegistries.ATTRIBUTE.holders().forEach(holder -> {
                    if (holder.isBound() && supplier.hasAttribute(holder)) {
                        attrs.put(attributeTypeNameFromHolder(holder), supplier.getBaseValue(holder));
                    }
                });

                if (!attrs.isEmpty()) {
                    result.put(entityName, attrs);
                }
            }
        } catch (Exception e) {
            LOG.warn("[attributes-dump] Failed to read DefaultAttributes.SUPPLIERS: {}", e.getMessage());
        }
        return result;
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        return String.format("%.1f MB", bytes / (1024.0 * 1024));
    }

    private String getNeoForgeVersion() {
        try {
            // NeoForge version is available from the runtime
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
// ### 2026-09-08 — true per-entity vanilla defaults via DefaultAttributes.SUPPLIERS reflection
// Added collectDefaultAttributes() which reflectively reads DefaultAttributes.SUPPLIERS
// (Mojang mapping, confirmed by NeoForge patch to patches/net/minecraft/world/entity/ai/
// attributes/DefaultAttributes.java.patch). NeoForge stores its attribute overrides in a
// SEPARATE HashMap (CommonHooks.FORGE_ATTRIBUTES, line 1164 of CommonHooks.java) and
// patches DefaultAttributes.getSupplier() to check FORGE_ATTRIBUTES first, then fall back
// to SUPPLIERS. The original SUPPLIERS field retains pristine vanilla values.
// Output goes into a new "default_attributes" section (entity-centric, entity→attribute→value).
// The field name fallback scans all declared fields by Map type if "SUPPLIERS" isn't found.
// 84 vanilla entity types found in the modded AllTheTech dump (vs 77 in mobs.py vanilla set).
