
data:extend(
  {
    { type = "item-group",
      name = "railtanker",
      icon = "__RailTanker__/graphics/rail-tanker-icon.png",
      order = "z"
    },

    {
      type = "item-subgroup",
      name = "contents",
      group = "railtanker",
      order = "a",
    },
  }
)
log("done")
--entity
require("prototypes.entity.entities")

--items
require("prototypes.item.items")

--recipies
require("prototypes.recipe.recipes")

--tech
require("prototypes.tech.tech")
