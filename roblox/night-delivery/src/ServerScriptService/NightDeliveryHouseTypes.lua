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


local function japaneseRoofRun(model, origin)
	local wall = Color3.fromRGB(181, 171, 151)
	local roof = Color3.fromRGB(54, 59, 65)
	local wood = Color3.fromRGB(103, 76, 52)
	local body = part(model, "Body", Vector3.new(20, 9, 18), origin + Vector3.new(0, 4.5, 0), wall, Enum.Material.WoodPlanks)
	part(model, "TileRoof", Vector3.new(24, 0.7, 21), origin + Vector3.new(0, 9.35, 0), roof, Enum.Material.Slate)
	part(model, "Engawa", Vector3.new(18, 0.4, 3), origin + Vector3.new(0, 0.45, -10.5), wood, Enum.Material.WoodPlanks)

	for i = 1, 6 do
		local height = i * 1.5
		part(
			model,
			"RoofSafeStep_" .. i,
			Vector3.new(6, height, 3.2),
			origin + Vector3.new(-14, height / 2, -20 + (i - 1) * 2.4),
			wood,
			Enum.Material.WoodPlanks
		)
	end
	part(model, "RoofSafeLanding", Vector3.new(8, 0.6, 7), origin + Vector3.new(-9, 9.7, -7), roof, Enum.Material.Metal)

	for i, step in ipairs({
		{11, -18, 3.0},
		{10, -14, 6.0},
		{8, -10, 9.0},
	}) do
		part(
			model,
			"RoofShortcut_" .. i,
			Vector3.new(5, step[3], 5),
			origin + Vector3.new(step[1], step[3] / 2, step[2]),
			i == 1 and Color3.fromRGB(95, 110, 116) or wood,
			i == 1 and Enum.Material.Metal or Enum.Material.WoodPlanks
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(3, 9.9, 1), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-15, 0, -23), "日本家屋の屋根口へ\n外階段は安全、物置足場は近道")
	return body, target, -9.4
end

local function westernBalcony(model, origin)
	local wall = Color3.fromRGB(205, 196, 181)
	local roof = Color3.fromRGB(76, 61, 58)
	local wood = Color3.fromRGB(117, 84, 58)
	local body = part(model, "Body", Vector3.new(22, 11, 18), origin + Vector3.new(0, 5.5, 0), wall, Enum.Material.Brick)
	part(model, "PorchRoof", Vector3.new(14, 0.6, 5), origin + Vector3.new(0, 6.4, -11), roof, Enum.Material.Slate)
	part(model, "UpperBalcony", Vector3.new(18, 0.6, 5), origin + Vector3.new(0, 11.35, -10.5), wood, Enum.Material.WoodPlanks)

	for i = 1, 7 do
		local height = i * 1.55
		part(
			model,
			"BalconySafeStep_" .. i,
			Vector3.new(6, height, 3.2),
			origin + Vector3.new(-15, height / 2, -22 + (i - 1) * 2.25),
			wood,
			Enum.Material.WoodPlanks
		)
	end
	part(model, "BalconySafeLanding", Vector3.new(8, 0.6, 7), origin + Vector3.new(-10, 11.4, -8), wood, Enum.Material.WoodPlanks)

	part(model, "GardenBench", Vector3.new(5, 2.8, 4), origin + Vector3.new(11, 1.4, -17), wood, Enum.Material.WoodPlanks)
	part(model, "PorchAwningShortcut", Vector3.new(6, 5.8, 5), origin + Vector3.new(10, 2.9, -12), roof, Enum.Material.Slate)
	part(model, "BalconyCrateShortcut", Vector3.new(5, 9, 5), origin + Vector3.new(8, 4.5, -8), Color3.fromRGB(160, 119, 74), Enum.Material.WoodPlanks)

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 4), origin + Vector3.new(2, 11.9, -10.5), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-16, 0, -24), "洋館2階バルコニーへ\n左の階段か右の庇を使おう")
	return body, target, -9.2
end

local function showaFireEscape(model, origin)
	local wall = Color3.fromRGB(134, 132, 121)
	local metal = Color3.fromRGB(77, 85, 89)
	local signColor = Color3.fromRGB(182, 114, 67)
	local body = part(model, "Body", Vector3.new(20, 16, 17), origin + Vector3.new(0, 8, 0), wall, Enum.Material.Concrete)

	for floor = 1, 3 do
		part(
			model,
			"ShowaLanding_" .. floor,
			Vector3.new(8, 0.6, 6),
			origin + Vector3.new(-12, floor * 5.0 + 0.3, -7 + ((floor - 1) % 2) * 13),
			metal,
			Enum.Material.DiamondPlate
		)
	end
	for i = 1, 10 do
		local height = i * 1.5
		local z = -19 + (i - 1) * 2.2
		part(
			model,
			"ShowaSafeStep_" .. i,
			Vector3.new(5.5, height, 2.8),
			origin + Vector3.new(-14, height / 2, z),
			metal,
			Enum.Material.Metal
		)
	end
	part(model, "ShowaTopWalk", Vector3.new(16, 0.6, 5), origin + Vector3.new(-5, 15.5, 8), metal, Enum.Material.DiamondPlate)

	for i, step in ipairs({
		{8, -17, 3.5},
		{9, -12, 7.0},
		{10, -7, 10.5},
		{9, -2, 14.0},
	}) do
		part(
			model,
			"ShowaShortcut_" .. i,
			Vector3.new(4.5, step[3], 4.5),
			origin + Vector3.new(step[1], step[3] / 2, step[2]),
			i % 2 == 0 and signColor or metal,
			Enum.Material.Metal
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(1, 16.05, 8), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-16, 0, -23), "昭和ビル最上階へ\n非常階段は安全、看板足場は近道")
	return body, target, -8.8
end

local function luxuryGardenWall(model, origin, frontZ)
	local stone = Color3.fromRGB(157, 157, 148)
	local hedge = Color3.fromRGB(55, 98, 64)
	local gold = Color3.fromRGB(187, 154, 81)
	local wallZ = frontZ - 8

	part(model, "EstateWall", Vector3.new(24, 4.5, 0.8), origin + Vector3.new(0, 2.25, wallZ), stone, Enum.Material.Marble)
	part(model, "GateLeft", Vector3.new(8, 4.5, 0.8), origin + Vector3.new(-8, 2.25, wallZ), gold, Enum.Material.Metal)
	part(model, "GateRight", Vector3.new(8, 4.5, 0.8), origin + Vector3.new(8, 2.25, wallZ), gold, Enum.Material.Metal)

	for _, x in ipairs({-15, 15}) do
		part(model, "Hedge", Vector3.new(6, 3.2, 12), origin + Vector3.new(x, 1.6, wallZ + 4), hedge, Enum.Material.Grass)
	end

	part(model, "SafeGardenWalk1", Vector3.new(7, 0.3, 12), origin + Vector3.new(-18, 0.2, wallZ - 1), stone, Enum.Material.Concrete)
	part(model, "SafeGardenWalk2", Vector3.new(18, 0.3, 6), origin + Vector3.new(-10, 0.2, 14), stone, Enum.Material.Concrete)

	part(model, "FountainBase", Vector3.new(6, 2.5, 6), origin + Vector3.new(1, 1.25, wallZ - 6), stone, Enum.Material.Marble)
	part(model, "HedgeShortcut", Vector3.new(6, 4.5, 5), origin + Vector3.new(1, 2.25, wallZ), hedge, Enum.Material.Grass)
	part(model, "GardenLanding", Vector3.new(7, 2.5, 6), origin + Vector3.new(1, 1.25, wallZ + 6), stone, Enum.Material.Marble)

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(0, 0.25, 14), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-17, 0, wallZ - 9), "邸宅の裏口へ\n左の庭園路か噴水越えの近道")
	return nil, target
end

local function harborContainerRun(model, origin)
	local steel = Color3.fromRGB(67, 91, 104)
	local blue = Color3.fromRGB(60, 104, 126)
	local rust = Color3.fromRGB(151, 78, 61)
	local yellow = Color3.fromRGB(197, 151, 67)

	part(model, "HarborSafe1", Vector3.new(7, 3, 7), origin + Vector3.new(15, 1.5, -22), blue, Enum.Material.Metal)
	part(model, "HarborSafe2", Vector3.new(7, 6, 7), origin + Vector3.new(15, 3, -14), rust, Enum.Material.Metal)
	part(model, "HarborSafe3", Vector3.new(7, 9, 7), origin + Vector3.new(15, 4.5, -6), blue, Enum.Material.Metal)
	part(model, "HarborSafe4", Vector3.new(7, 12, 7), origin + Vector3.new(15, 6, 2), rust, Enum.Material.Metal)
	part(model, "HarborCatwalk", Vector3.new(10, 0.6, 14), origin + Vector3.new(12, 12.3, 11), steel, Enum.Material.DiamondPlate)

	part(model, "HarborShortcut1", Vector3.new(5, 4, 5), origin + Vector3.new(5, 2, -18), yellow, Enum.Material.Metal)
	part(model, "HarborShortcut2", Vector3.new(5, 8, 5), origin + Vector3.new(7, 4, -10), yellow, Enum.Material.Metal)
	part(model, "HarborShortcut3", Vector3.new(5, 12, 5), origin + Vector3.new(9, 6, -2), yellow, Enum.Material.Metal)

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 6), origin + Vector3.new(8, 12.85, 15), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(18, 0, -27), "港の上部コンテナへ\n外周は安全、黄色コンテナは近道")
	return nil, target
end

local function mountainBridge(model, origin)
	local rock = Color3.fromRGB(92, 91, 83)
	local wood = Color3.fromRGB(117, 85, 58)
	local moss = Color3.fromRGB(68, 94, 64)
	local body = part(model, "MountainHut", Vector3.new(15, 8, 14), origin + Vector3.new(22, 11, 8), Color3.fromRGB(128, 111, 88), Enum.Material.WoodPlanks)

	for i = 1, 6 do
		local height = i * 1.5
		part(
			model,
			"MountainSafeStep_" .. i,
			Vector3.new(7, height, 5),
			origin + Vector3.new(-12, height / 2, -20 + (i - 1) * 3),
			rock,
			Enum.Material.Rock
		)
	end
	part(model, "MountainStartLedge", Vector3.new(11, 0.7, 10), origin + Vector3.new(-7, 9.4, -3), moss, Enum.Material.Grass)
	part(model, "MountainBridge", Vector3.new(24, 0.7, 6), origin + Vector3.new(7, 9.4, 3), wood, Enum.Material.WoodPlanks)
	part(model, "MountainFarLedge", Vector3.new(12, 0.7, 10), origin + Vector3.new(22, 9.4, 7), moss, Enum.Material.Grass)

	for i, step in ipairs({
		{-1, -8, 3.0},
		{5, -4, 5.5},
		{11, 0, 7.5},
		{17, 4, 9.0},
	}) do
		part(
			model,
			"MountainShortcutRock_" .. i,
			Vector3.new(5.5, step[3], 5.5),
			origin + Vector3.new(step[1], step[3] / 2, step[2]),
			rock,
			Enum.Material.Rock
		)
	end

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 5), origin + Vector3.new(22, 9.95, 7), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-16, 0, -24), "山小屋へ木橋を渡る\n岩場は速いが足元注意")
	return body, target, -6.5
end

local function danchiCorridor(model, origin)
	local concrete = Color3.fromRGB(156, 160, 156)
	local metal = Color3.fromRGB(83, 96, 102)
	local unit = Color3.fromRGB(194, 198, 192)
	local body = part(model, "Body", Vector3.new(25, 14, 18), origin + Vector3.new(0, 7, 0), concrete, Enum.Material.Concrete)

	for floor = 1, 2 do
		part(
			model,
			"DanchiCorridor_" .. floor,
			Vector3.new(25, 0.6, 5),
			origin + Vector3.new(0, floor * 5.5, -11),
			metal,
			Enum.Material.Concrete
		)
	end
	for i = 1, 8 do
		local height = i * 1.4
		part(
			model,
			"DanchiSafeStep_" .. i,
			Vector3.new(6, height, 3.2),
			origin + Vector3.new(-15, height / 2, -22 + (i - 1) * 2.1),
			metal,
			Enum.Material.Metal
		)
	end
	part(model, "DanchiTopLanding", Vector3.new(8, 0.6, 7), origin + Vector3.new(-10, 11.5, -8), metal, Enum.Material.DiamondPlate)

	part(model, "OutdoorUnit1", Vector3.new(5, 3.0, 4), origin + Vector3.new(11, 1.5, -17), unit, Enum.Material.Metal)
	part(model, "OutdoorUnit2", Vector3.new(5, 6.0, 4), origin + Vector3.new(11, 3.0, -12), unit, Enum.Material.Metal)
	part(model, "OutdoorUnit3", Vector3.new(5, 9.0, 4), origin + Vector3.new(9, 4.5, -8), unit, Enum.Material.Metal)
	part(model, "OutdoorUnit4", Vector3.new(5, 11.0, 4), origin + Vector3.new(6, 5.5, -6), unit, Enum.Material.Metal)

	local target = part(model, "DeliveryPoint", Vector3.new(6, 0.5, 4), origin + Vector3.new(3, 12.05, -11), Color3.fromRGB(97, 185, 163), Enum.Material.Neon)
	sign(model, origin + Vector3.new(-17, 0, -24), "団地上階の外廊下へ\n階段は安全、室外機は近道")
	return body, target, -9.3
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
	JapaneseRoofRun = {label = "日本家屋・屋根口", challengeTier = "light", extraSeconds = 30, promptDistance = 8, verticalCheck = true, standalone = true, build = japaneseRoofRun},
	WesternBalcony = {label = "洋館・2階バルコニー", challengeTier = "light", extraSeconds = 30, promptDistance = 8, verticalCheck = true, standalone = true, build = westernBalcony},
	ShowaFireEscape = {label = "昭和ビル・非常階段", challengeTier = "heavy", extraSeconds = 45, promptDistance = 8, verticalCheck = true, standalone = true, build = showaFireEscape},
	LuxuryGardenWall = {label = "高級邸宅・庭園裏口", challengeTier = "light", extraSeconds = 26, build = luxuryGardenWall},
	HarborContainerRun = {label = "港町・コンテナ上部", challengeTier = "heavy", extraSeconds = 44, promptDistance = 8, verticalCheck = true, build = harborContainerRun},
	MountainBridge = {label = "山間・木橋の先", challengeTier = "heavy", extraSeconds = 46, promptDistance = 8, verticalCheck = true, standalone = true, build = mountainBridge},
	DanchiCorridor = {label = "団地・上階外廊下", challengeTier = "light", extraSeconds = 30, promptDistance = 8, verticalCheck = true, standalone = true, build = danchiCorridor},
}

function HouseTypes.build(model, houseType, origin, frontZ)
	local definition = HouseTypes.Definitions[houseType]
	assert(definition, "Unknown HouseType: " .. tostring(houseType))
	return definition.build(model, origin, frontZ)
end

return HouseTypes
