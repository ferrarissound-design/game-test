-- Geometry only. NightDelivery.server.lua remains the sole owner of jobs and prompts.
local HouseTypes = {}

HouseTypes.Definitions = {
	Normal = {label = "通常住宅", extraSeconds = 0},
	Construction = {label = "工事中住宅・裏口", extraSeconds = 38},
	HighRise = {label = "高所配達・屋上", extraSeconds = 46},
}

local function part(model, name, size, center, color, material)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Position = center
	item.Anchored = true
	item.Color = color
	item.Material = material or Enum.Material.Concrete
	item.Parent = model
	return item
end

local function sign(model, center, label)
	local post = part(model, "RouteSign", Vector3.new(0.3, 4, 0.3), center + Vector3.new(0, 2, 0), Color3.fromRGB(220, 188, 83), Enum.Material.Metal)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = post
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(27, 32, 38)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Color3.fromRGB(255, 228, 145)
	text.TextScaled = true
	text.TextWrapped = true
	text.Text = label
	text.Parent = gui
end

local function construction(model, origin, frontZ)
	local orange = Color3.fromRGB(224, 150, 61)
	local wood = Color3.fromRGB(136, 98, 62)
	-- The fence crosses the porch. The open side corridor is the safe route.
	local fenceZ = frontZ - 8
	part(model, "FrontFence", Vector3.new(21, 7, 0.7), origin + Vector3.new(0, 3.5, fenceZ), orange, Enum.Material.Metal)
	for _, x in ipairs({-8, -3, 3, 8}) do
		part(model, "FenceStripe", Vector3.new(1.2, 0.15, 0.78), origin + Vector3.new(x, 4, fenceZ - 0.02), Color3.fromRGB(37, 38, 39), Enum.Material.Metal)
	end
	-- Clear, broad stepping stones along the right side, then around the rear wall.
	for index, z in ipairs({fenceZ - 3, fenceZ + 4, -3, 4, 12}) do
		part(model, "SafeWalk_" .. index, Vector3.new(6, 0.3, 5), origin + Vector3.new(17, 0.2, z), Color3.fromRGB(157, 157, 146))
	end
	part(model, "RearWalk", Vector3.new(22, 0.3, 5), origin + Vector3.new(7, 0.2, 14), Color3.fromRGB(157, 157, 146))
	-- Optional faster crossing: crate, scaffold, then a broad landing over the fence.
	part(model, "ShortcutCrate", Vector3.new(5, 2, 5), origin + Vector3.new(-4, 1, fenceZ - 8), wood, Enum.Material.WoodPlanks)
	part(model, "ShortcutScaffold", Vector3.new(6, 4, 5), origin + Vector3.new(-4, 2, fenceZ - 3), wood, Enum.Material.WoodPlanks)
	part(model, "ShortcutFenceLanding", Vector3.new(8, 0.5, 5), origin + Vector3.new(-4, 6.3, fenceZ), orange, Enum.Material.Metal)
	part(model, "ShortcutInsideLanding", Vector3.new(7, 4, 5), origin + Vector3.new(-4, 2, fenceZ + 5), wood, Enum.Material.WoodPlanks)
	local back = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(0, 0.25, 14), Color3.fromRGB(91, 155, 124))
	sign(model, origin + Vector3.new(12, 0, fenceZ - 5), "工事中：右側を回って裏口へ\n木箱から柵越えもできる")
	return back
end

local function highRise(model, origin)
	local concrete = Color3.fromRGB(141, 151, 158)
	local metal = Color3.fromRGB(97, 116, 129)
	local body = part(model, "Body", Vector3.new(22, 18, 18), origin + Vector3.new(0, 9, 0), concrete)
	part(model, "RoofDeck", Vector3.new(24, 0.5, 20), origin + Vector3.new(0, 18.25, 0), metal, Enum.Material.Metal)
	-- Twelve forgiving steps, 1.5 studs high, with a continuous landing at the roof.
	for i = 1, 12 do
		local z = -17 + (i - 1) * 2.2
		part(model, "FireStair_" .. i, Vector3.new(6, i * 1.5, 2.4), origin + Vector3.new(-14, i * 0.75, z), metal, Enum.Material.Metal)
	end
	part(model, "RoofLanding", Vector3.new(8, 0.5, 6), origin + Vector3.new(-11, 18.25, 7), metal, Enum.Material.Metal)
	-- Optional short climb to the middle landing. Broad jumps with no lethal fall.
	for i, step in ipairs({{-4, -17, 2.5}, {-7, -17, 5}, {-10, -17, 7.5}, {-13, -14, 9}}) do
		part(model, "RoofShortcut_" .. i, Vector3.new(5, step[3], 5), origin + Vector3.new(step[1], step[3] / 2, step[2]), Color3.fromRGB(166, 127, 78), Enum.Material.WoodPlanks)
	end
	part(model, "RoofShortcutBridge", Vector3.new(5, 0.5, 5), origin + Vector3.new(-14, 9.25, -9), metal, Enum.Material.Metal)
	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(-4, 18.75, 1), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-16, 0, -20), "屋上配達：左の非常階段へ\n足場の近道もある")
	return body, target
end

function HouseTypes.build(model, houseType, origin, frontZ)
	if houseType == "Construction" then
		return nil, construction(model, origin, frontZ)
	elseif houseType == "HighRise" then
		return highRise(model, origin)
	end
	return nil, nil
end

return HouseTypes
