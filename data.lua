--entity
require("prototypes.entity.entities")

--items
require("prototypes.item.items")

--recipies
require("prototypes.recipe.recipes")

--tech
require("prototypes.tech.tech")

if data.raw["pump"]["small-pump"] then
  data.raw["pump"]["small-pump"].collision_box = {{-0.29, -0.29}, {0.29, 0.29}}
end