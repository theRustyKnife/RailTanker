if data.raw["pump"]["small-pump"] then
  data.raw["pump"]["small-pump"].collision_box = {{-0.29, -0.29}, {0.29, 0.29}}
end

for i, fluid in pairs(data.raw["fluid"]) do
	local fluid_item = {
		type = "item",
		name = fluid.name .. "-in-tanker",
		icon = fluid.icon,
		flags = {"goes-to-main-inventory", "hidden"},
		subgroup = "transport",
		order = "z[rail-tanker]",
		stack_size = 2500
	}
	data:extend({fluid_item})
end