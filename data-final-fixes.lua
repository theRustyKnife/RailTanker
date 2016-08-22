if data.raw["pump"]["small-pump"] then
  data.raw["pump"]["small-pump"].collision_box = {{-0.29, -0.29}, {0.29, 0.29}}
end

for i, fluid in pairs(data.raw["fluid"]) do
  local fluid_item = {
    type = "item",
    name = fluid.name .. "-in-tanker",
    icons = {
      { icon = fluid.icon,
        tint = {r=1, g=1, b=1, a=1}
      },
      { icon = "__RailTanker__/graphics/rail-tanker.png",
        tint = {r=1, g=1, b=1, a=0.85}
      },
    },
    flags = {"goes-to-main-inventory"},
    subgroup = "contents",
    order = "z[rail-tanker]",
    stack_size = 2500,
    localised_name = {"item-name.liquid-in-tanker", {"fluid-name." .. fluid.name}, {"entity-name.rail-tanker"}}
  }
  data:extend({fluid_item})
end
