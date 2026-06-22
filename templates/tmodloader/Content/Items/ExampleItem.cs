using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace YourMod.Content.Items;

public class ExampleItem : ModItem
{
    public override void SetDefaults()
    {
        Item.width = 20;
        Item.height = 20;
        Item.maxStack = Item.CommonMaxStack;
        Item.value = Item.buyPrice(silver: 1);
        Item.rare = ItemRarityID.Blue;
    }

    public override void AddRecipes()
    {
        CreateRecipe()
            .AddIngredient(ItemID.Wood, 5)
            .AddTile(TileID.WorkBenches)
            .Register();
    }
}
