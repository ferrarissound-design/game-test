-- Geometry only. NightDelivery.server.lua remains the sole owner of jobs and prompts.
local HouseTypes = {}

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
	gui.Size = UDim2.fromOffset(145, 42)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 22
	gui.Parent = post
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(27, 32, 38)
	text.BackgroundTransparency = 0.3
	text.TextColor3 = Color3.fromRGB(255, 228, 145)
	text.TextSize = 11
	text.TextTruncate = Enum.TextTruncate.AtEnd
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

local function blockedAlley(model, origin, frontZ)
	local metal = Color3.fromRGB(86, 98, 107)
	local bin = Color3.fromRGB(69, 112, 103)
	local alleyZ = frontZ - 13
	-- A walled, cluttered shortcut. The left outside edge stays open for a walk around the house.
	for _, x in ipairs({-10, 10}) do
		part(model, "AlleyWall_" .. x, Vector3.new(0.7, 6, 17), origin + Vector3.new(x, 3, alleyZ - 2), metal, Enum.Material.Brick)
	end
	part(model, "RoadworkBarrier", Vector3.new(18, 5, 0.8), origin + Vector3.new(0, 2.5, alleyZ), Color3.fromRGB(215, 143, 70), Enum.Material.Metal)
	part(model, "Dumpster", Vector3.new(6, 2.5, 5), origin + Vector3.new(-2, 1.25, alleyZ - 9), bin, Enum.Material.Metal)
	part(model, "ParcelStack", Vector3.new(3, 2.5, 4), origin + Vector3.new(5, 1.25, alleyZ - 8), Color3.fromRGB(149, 119, 82), Enum.Material.WoodPlanks)
	part(model, "SmallPlatform", Vector3.new(7, 3.5, 5), origin + Vector3.new(-2, 1.75, alleyZ - 4), metal, Enum.Material.Metal)
	part(model, "PipeWalk", Vector3.new(8, 4.5, 5), origin + Vector3.new(-2, 2.25, alleyZ), Color3.fromRGB(99, 116, 125), Enum.Material.Metal)
	part(model, "WallCrossing", Vector3.new(8, 5.5, 5), origin + Vector3.new(-2, 2.75, alleyZ + 4), metal, Enum.Material.Brick)
	part(model, "AlleyLanding", Vector3.new(9, 2.5, 5), origin + Vector3.new(-2, 1.25, alleyZ + 9), metal, Enum.Material.Metal)
	-- The rear path joins either approach; it stays beyond the existing solid house body.
	part(model, "BackPassage", Vector3.new(29, 0.3, 6), origin + Vector3.new(-4, 0.2, 15), metal)
	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(0, 0.25, 15), Color3.fromRGB(93, 176, 147), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-14, 0, alleyZ - 10), "路地裏：左を大回り\nゴミ箱から柵を越えて近道")
	return nil, target
end

local function warehouseRoute(model, origin)
	local steel = Color3.fromRGB(78, 106, 120)
	local wood = Color3.fromRGB(137, 102, 66)
	local rust = Color3.fromRGB(178, 92, 65)
	-- A loading-yard ascent around the warehouse's right wall, ending at a rear upper dock.
	part(model, "LoadingCrate", Vector3.new(6, 2.5, 6), origin + Vector3.new(16, 1.25, -21), wood, Enum.Material.WoodPlanks)
	part(model, "PalletStack", Vector3.new(7, 4.5, 6), origin + Vector3.new(16, 2.25, -15), wood, Enum.Material.WoodPlanks)
	part(model, "FreightContainer", Vector3.new(7, 7.5, 8), origin + Vector3.new(16, 3.75, -8), rust, Enum.Material.Metal)
	part(model, "StorageShelf", Vector3.new(7, 10.5, 7), origin + Vector3.new(16, 5.25, 0), steel, Enum.Material.Metal)
	part(model, "MetalCatwalk", Vector3.new(8, 0.6, 8), origin + Vector3.new(16, 13.2, 8), steel, Enum.Material.DiamondPlate)
	part(model, "CatwalkSupport", Vector3.new(0.7, 12.9, 0.7), origin + Vector3.new(19, 6.45, 8), steel, Enum.Material.Metal)
	part(model, "UpperLoadingDock", Vector3.new(12, 0.6, 11), origin + Vector3.new(12, 16.2, 15), steel, Enum.Material.DiamondPlate)
	for _, x in ipairs({7, 17}) do
		part(model, "DockSupport_" .. x, Vector3.new(0.8, 15.9, 0.8), origin + Vector3.new(x, 7.95, 18), steel, Enum.Material.Metal)
	end
	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(9, 16.75, 16), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(17, 0, -27), "倉庫奥の上階へ\n木箱→パレット→コンテナ→金属足場")
	return nil, target
end

local function rooftopGap(model, origin)
	local brick = Color3.fromRGB(142, 128, 119)
	local roof = Color3.fromRGB(90, 105, 117)
	local body = part(model, "Body", Vector3.new(18, 9, 16), origin + Vector3.new(0, 4.5, 0), brick, Enum.Material.Brick)
	part(model, "StartingRoof", Vector3.new(19, 0.6, 17), origin + Vector3.new(0, 9.3, 0), roof, Enum.Material.Slate)
	part(model, "NeighborBuilding", Vector3.new(18, 9, 16), origin + Vector3.new(26, 4.5, 0), brick, Enum.Material.Brick)
	part(model, "NeighborRoof", Vector3.new(19, 0.6, 17), origin + Vector3.new(26, 9.3, 0), roof, Enum.Material.Slate)
	-- A broad exterior stair on the first building. The short horizontal gaps are each 1-2 studs.
	for i = 1, 6 do
		part(model, "FirstRoofStair_" .. i, Vector3.new(6, i * 1.5, 3.2), origin + Vector3.new(-12, i * 0.75, -18 + (i - 1) * 2.1), roof, Enum.Material.Metal)
	end
	part(model, "FirstRoofLanding", Vector3.new(7, 0.6, 7), origin + Vector3.new(-9, 9.3, -6), roof, Enum.Material.Metal)
	part(model, "BillboardBridge", Vector3.new(5, 0.6, 7), origin + Vector3.new(13, 9.3, 0), Color3.fromRGB(180, 136, 77), Enum.Material.Metal)
	-- Falling between roofs lands on a catch deck, with steps back to the far roof.
	part(model, "RecoveryDeck", Vector3.new(10, 0.6, 12), origin + Vector3.new(13, 4.8, 0), roof, Enum.Material.Metal)
	part(model, "RecoveryStep1", Vector3.new(6, 6, 5), origin + Vector3.new(14, 3, 7), roof, Enum.Material.Metal)
	part(model, "RecoveryStep2", Vector3.new(6, 8, 5), origin + Vector3.new(17, 4, 11), roof, Enum.Material.Metal)
	part(model, "RecoveryStep3", Vector3.new(6, 9, 5), origin + Vector3.new(20, 4.5, 11), roof, Enum.Material.Metal)
	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(29, 9.85, 1), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-13, 0, -23), "屋根を横へ渡って配達\n落ちても中央から登り直せる")
	return body, target, -8.3
end


local function apartmentStairs(model, origin)
	local concrete = Color3.fromRGB(145, 150, 147)
	local rail = Color3.fromRGB(82, 96, 104)
	local shortcut = Color3.fromRGB(160, 117, 73)
	local body = part(model, "Body", Vector3.new(22, 14, 18), origin + Vector3.new(0, 7, 0), concrete, Enum.Material.Concrete)

	-- Broad exterior stairs are the safe route. Each rise is forgiving on mobile.
	for i = 1, 8 do
		local height = i * 1.5
		part(
			model,
			"ApartmentStair_" .. i,
			Vector3.new(6, height, 3.2),
			origin + Vector3.new(-14, height / 2, -23 + (i - 1) * 2),
			rail,
			Enum.Material.Metal
		)
	end
	part(model, "ApartmentTopLanding", Vector3.new(8, 0.6, 7), origin + Vector3.new(-10, 12.3, -9.5), rail, Enum.Material.DiamondPlate)
	part(model, "ApartmentBalcony", Vector3.new(24, 0.6, 5), origin + Vector3.new(0, 12.3, -10.5), rail, Enum.Material.Metal)

	-- The right-side parcel stacks are shorter but require confident jumps.
	for i, step in ipairs({
		{13, -20, 3.0},
		{13, -16.5, 6.0},
		{13, -13.0, 9.0},
		{11, -10.5, 12.0},
	}) do
		part(
			model,
			"ApartmentShortcut_" .. i,
			Vector3.new(5, step[3], 4.5),
			origin + Vector3.new(step[1], step[3] / 2, step[2]),
			shortcut,
			Enum.Material.WoodPlanks
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 4), origin + Vector3.new(3, 12.85, -10.5), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-16, 0, -24), "アパート2階へ\n外階段は安全、荷物足場は近道")
	return body, target, -9.5
end

local function parkingDeck(model, origin)
	local concrete = Color3.fromRGB(126, 134, 137)
	local metal = Color3.fromRGB(77, 91, 101)
	local warning = Color3.fromRGB(211, 157, 70)
	local body = part(model, "Body", Vector3.new(25, 0.7, 22), origin + Vector3.new(0, 0.35, 0), concrete, Enum.Material.Concrete)

	for _, x in ipairs({-10, 10}) do
		for _, z in ipairs({-8, 8}) do
			part(model, "ParkingColumn", Vector3.new(1, 9, 1), origin + Vector3.new(x, 4.5, z), metal, Enum.Material.Metal)
		end
	end
	part(model, "ParkingUpperDeck", Vector3.new(25, 0.7, 22), origin + Vector3.new(0, 9.35, 0), concrete, Enum.Material.Concrete)

	-- A broad stepped ramp is the low-risk route to the upper deck.
	for i = 1, 6 do
		local height = i * 1.5
		part(
			model,
			"ParkingRamp_" .. i,
			Vector3.new(7, height, 4),
			origin + Vector3.new(-13, height / 2, -22 + (i - 1) * 3),
			concrete,
			Enum.Material.Concrete
		)
	end
	part(model, "ParkingRampLanding", Vector3.new(9, 0.6, 7), origin + Vector3.new(-9, 9.7, -6), metal, Enum.Material.DiamondPlate)

	-- A stack of maintenance crates cuts the corner for faster players.
	for i, height in ipairs({3, 6, 9}) do
		part(
			model,
			"ParkingShortcut_" .. i,
			Vector3.new(5, height, 5),
			origin + Vector3.new(9, height / 2, -16 + (i - 1) * 4),
			warning,
			Enum.Material.Metal
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(4, 9.9, 4), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-17, 0, -24), "立体駐車場の上階へ\n左のランプは安全、右の箱は近道")
	return body, target, -10.8
end

local function factoryCatwalk(model, origin)
	local steel = Color3.fromRGB(73, 96, 108)
	local crate = Color3.fromRGB(147, 103, 65)
	local hazard = Color3.fromRGB(195, 112, 62)

	-- The warehouse body is supplied by NightDelivery.server.lua. Build two routes around it.
	for i = 1, 8 do
		local height = i * 1.5
		part(
			model,
			"FactorySafeStep_" .. i,
			Vector3.new(6, height, 3.2),
			origin + Vector3.new(16, height / 2, -24 + (i - 1) * 2.2),
			steel,
			Enum.Material.Metal
		)
	end
	part(model, "FactorySideCatwalk", Vector3.new(6, 0.6, 24), origin + Vector3.new(16, 12.3, 2), steel, Enum.Material.DiamondPlate)
	part(model, "FactoryRearBridge", Vector3.new(16, 0.6, 6), origin + Vector3.new(10, 12.3, 14), steel, Enum.Material.DiamondPlate)

	-- Conveyor-side shortcut: fewer platforms, larger jumps.
	for i, step in ipairs({
		{7, -19, 3.0},
		{9, -15, 6.0},
		{11, -11, 9.0},
		{14, -7, 12.0},
	}) do
		part(
			model,
			"FactoryShortcut_" .. i,
			Vector3.new(5, step[3], 5),
			origin + Vector3.new(step[1], step[3] / 2, step[2]),
			i % 2 == 0 and hazard or crate,
			i % 2 == 0 and Enum.Material.Metal or Enum.Material.WoodPlanks
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(6, 12.85, 14), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(17, 0, -27), "工場上部の搬入口へ\n外階段は安全、資材足場は近道")
	return nil, target
end

HouseTypes.Definitions = {
	Normal = {label = "通常住宅", challengeTier = "normal", extraSeconds = 0, build = function() return nil, nil end},
	Construction = {label = "工事中住宅・裏口", challengeTier = "light", extraSeconds = 38, build = function(model, origin, frontZ)
		return nil, construction(model, origin, frontZ)
	end},
	HighRise = {label = "高所配達・屋上", challengeTier = "heavy", extraSeconds = 46, promptDistance = 8, verticalCheck = true, standalone = true, build = function(model, origin)
		local body, target = highRise(model, origin)
		return body, target, -9.3
	end},
	BlockedAlley = {label = "路地裏・裏口", challengeTier = "light", extraSeconds = 32, build = blockedAlley},
	WarehouseRoute = {label = "倉庫・上階搬入口", challengeTier = "heavy", extraSeconds = 45, promptDistance = 8, verticalCheck = true, build = warehouseRoute},
	RooftopGap = {label = "屋根渡り・配達", challengeTier = "heavy", extraSeconds = 42, promptDistance = 6, verticalCheck = true, standalone = true, build = rooftopGap},
	ApartmentStairs = {label = "アパート・外階段", challengeTier = "light", extraSeconds = 28, promptDistance = 8, verticalCheck = true, standalone = true, build = apartmentStairs},
	ParkingDeck = {label = "立体駐車場・上階", challengeTier = "light", extraSeconds = 30, promptDistance = 8, verticalCheck = true, standalone = true, build = parkingDeck},
	FactoryCatwalk = {label = "工場・上部搬入口", challengeTier = "heavy", extraSeconds = 44, promptDistance = 8, verticalCheck = true, build = factoryCatwalk},
}

function HouseTypes.build(model, houseType, origin, frontZ)
	local definition = HouseTypes.Definitions[houseType]
	assert(definition, "Unknown HouseType: " .. tostring(houseType))
	return definition.build(model, origin, frontZ)
end

return HouseTypes
