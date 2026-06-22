// ============================================================================
// Dialogue Panel Rework  —  by Cyrilly
//
// Advanced dialogue/UI system for NPC conversations. Supports branching
// dialogue, portraits, and typed text effects.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class DialoguePanelIntegration
{
    private static Mod _dp;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("DialoguePanelRework", out _dp))
            return;
    }

    public static void ShowDialogue(string text, string npcName = "", string portraitPath = "")
    {
        _dp?.Call("ShowDialogue", text, npcName, portraitPath);
    }

    public static void ShowDialogueWithChoices(string text, string[] choices, System.Action<int> onChosen)
    {
        _dp?.Call("ShowDialogueChoices", text, choices, onChosen);
    }
}
*/

// ============================================================================
// Shop Expander  —  by Exterminator
//
// Extends the vanilla shop UI. Register custom shop pages, categories,
// and items with advanced filtering.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ShopExpanderIntegration
{
    private static Mod _shop;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("ShopExpander", out _shop))
            return;
    }

    public static void RegisterShopPage(string pageName, string category)
    {
        _shop?.Call("RegisterPage", pageName, category);
    }

    public static void AddItemToPage(int itemType, string pageName, int price = -1)
    {
        _shop?.Call("AddItem", itemType, pageName, price);
    }
}
*/

// ============================================================================
// ModLiquid Library  —  by Lion8cake
//
// Framework for adding custom liquid types (e.g., honey, lava variants,
// or entirely new liquids).
//
// Integration pattern: direct reference (ModLiquid.Base)
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ModLiquidIntegration
{
    public static void Load()
    {
        if (!ModLoader.HasMod("ModLiquidLibrary"))
            return;

        // ModLiquid.ModLiquidBase provides the base class for custom liquids.
        // Create a class inheriting from ModLiquid.ModLiquidBase and override
        // properties like Name, TileColor, LightColor, etc.
    }
}
*/
