-- Night Delivery v4
-- ServerScriptService/NightDelivery.server.lua
-- Code-complete prototype: generated town, progression, dynamic weather,
-- co-op bonuses, cosmetics, shop flow, rare jobs, and persistent upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")

local REMOTE_NAME = "NightDeliveryEvent"
local WORLD_NAME = "NightDeliveryWorld"
local DATASTORE_NAME = "NightDeliveryPlayerData_v2"

local deliveryEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if deliveryEvent and not deliveryEvent:IsA("RemoteEvent") then
	warn("Night Delivery: replacing non-RemoteEvent instance named " .. REMOTE_NAME)
	deliveryEvent:Destroy()
	deliveryEvent = nil
end

if not deliveryEvent then
	deliveryEvent = Instance.new("RemoteEvent")
	deliveryEvent.Name = REMOTE_NAME
	deliveryEvent.Parent = ReplicatedStorage
end

local BASE_WALK_SPEED = 20
local BIKE_BONUS_SPEED = 10
local SPEED_PER_LEVEL = 2
local MAX_SPEED_LEVEL = 5
local RIVERSIDE_UNLOCK_DELIVERIES = 5
local SPECIAL_JOB_UNLOCK_DELIVERIES = 8
local WAREHOUSE_UNLOCK_DELIVERIES = 15
local SHIFT_TARGET = 5
local SHIFT_REWARD = 300
local COOP_RANGE = 36
local COOP_BONUS_PER_HELPER = 0.15
local MAX_COOP_HELPERS = 2
local HELPER_REWARD = 25
local WEATHER_CHANGE_SECONDS = 150
local AUTOSAVE_SECONDS = 120
local REMOTE_COOLDOWN_SECONDS = 0.12

local DISTRICT_NAMES = {
	central = "住宅街",
	riverside = "川沿い地区",
	warehouse = "倉庫街",
}

local WEATHER_TYPES = {
	{id = "clear", name = "晴れ", rewardMultiplier = 1.0},
	{id = "rain", name = "雨", rewardMultiplier = 1.25},
	{id = "fog", name = "濃霧", rewardMultiplier = 1.15},
}

local BAG_STYLES = {
	{name = "クラシック", cost = 0, color = Color3.fromRGB(176, 132, 82)},
	{name = "ブルー", cost = 500, color = Color3.fromRGB(74, 141, 214)},
	{name = "ネオン", cost = 1200, color = Color3.fromRGB(68, 235, 193)},
	{name = "ゴールド", cost = 2500, color = Color3.fromRGB(236, 194, 74)},
}

local BIKE_STYLES = {
	{name = "スチール", cost = 0, color = Color3.fromRGB(94, 126, 142)},
	{name = "レッド", cost = 700, color = Color3.fromRGB(200, 76, 72)},
	{name = "ネオン", cost = 1500, color = Color3.fromRGB(83, 213, 232)},
	{name = "ゴールド", cost = 3000, color = Color3.fromRGB(228, 184, 67)},
}

local dataStoreAvailable, deliveryStoreResult = pcall(function()
	return DataStoreService:GetDataStore(DATASTORE_NAME)
end)
local DELIVERY_STORE = dataStoreAvailable and deliveryStoreResult or nil

if not dataStoreAvailable then
	warn("Night Delivery: DataStore is unavailable; using session data only", deliveryStoreResult)
end

local JOB_TYPES = {
	{
		id = "standard",
		name = "通常便",
		weight = 60,
		timeLimit = 60,
		baseReward = 50,
		timeBonusPerSecond = 2,
		minDeliveries = 0,
	},
	{
		id = "express",
		name = "速達便",
		weight = 25,
		timeLimit = 35,
		baseReward = 90,
		timeBonusPerSecond = 3,
		minDeliveries = 0,
	},
	{
		id = "long",
		name = "遠距離便",
		weight = 15,
		timeLimit = 90,
		baseReward = 120,
		timeBonusPerSecond = 1,
		minDeliveries = 0,
	},
	{
		id = "special",
		name = "深夜特別便",
		weight = 8,
		timeLimit = 50,
		baseReward = 220,
		timeBonusPerSecond = 4,
		minDeliveries = SPECIAL_JOB_UNLOCK_DELIVERIES,
	},
}

local oldWorld = workspace:FindFirstChild(WORLD_NAME)
if oldWorld then
	oldWorld:Destroy()
end

local world = Instance.new("Folder")
world.Name = WORLD_NAME
world.Parent = workspace

local housesFolder = Instance.new("Folder")
housesFolder.Name = "Houses"
housesFolder.Parent = world

local playerJobs = {}
local playerLastHouse = {}
local playerStreak = {}
local playerShiftProgress = {}
local remoteLastAction = {}
local currentWeather = WEATHER_TYPES[1]
local shopPadRef = nil

local function makePart(name, size, position, color, parent, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeSurfaceText(part, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 250, 255)
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

local function setupLighting()
	Lighting.ClockTime = 22.35
	Lighting.Brightness = 1.35
	Lighting.Ambient = Color3.fromRGB(67, 72, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(42, 47, 68)
	Lighting.FogColor = Color3.fromRGB(34, 39, 57)
	Lighting.FogEnd = 700

	local atmosphere = Lighting:FindFirstChild("NightDeliveryAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "NightDeliveryAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.2
	atmosphere.Haze = 1.1
	atmosphere.Color = Color3.fromRGB(145, 159, 205)
	atmosphere.Decay = Color3.fromRGB(73, 78, 110)
end

local function createStreetLight(position)
	makePart(
		"StreetLightPole",
		Vector3.new(0.6, 10, 0.6),
		position + Vector3.new(0, 5, 0),
		Color3.fromRGB(65, 65, 72),
		world,
		Enum.Material.Metal
	)

	local lamp = makePart(
		"StreetLightLamp",
		Vector3.new(2.2, 0.5, 1),
		position + Vector3.new(0, 10.1, 0),
		Color3.fromRGB(255, 229, 166),
		world,
		Enum.Material.Neon
	)

	local light = Instance.new("PointLight")
	light.Brightness = 1.8
	light.Range = 24
	light.Color = Color3.fromRGB(255, 229, 174)
	light.Parent = lamp
end

local WORLD_THEMES = {
	{id = "japanese", name = "日本住宅街"},
	{id = "western", name = "西洋住宅街"},
}

local worldRandom = Random.new()
local selectedWorldTheme = WORLD_THEMES[worldRandom:NextInteger(1, #WORLD_THEMES)]

local function makeLitWindow(model, name, size, position, color)
	local window = makePart(
		name,
		size,
		position,
		color or Color3.fromRGB(255, 221, 145),
		model,
		Enum.Material.Neon
	)
	window.CanCollide = false

	local light = Instance.new("PointLight")
	light.Brightness = 0.45
	light.Range = 11
	light.Color = Color3.fromRGB(255, 222, 160)
	light.Parent = window
	return window
end

local function makeRotatedPart(name, size, position, color, parent, material, yaw, pitch, roll)
	local part = makePart(name, size, position, color, parent, material)
	part.CFrame = CFrame.new(position) * CFrame.Angles(
		math.rad(pitch or 0),
		math.rad(yaw or 0),
		math.rad(roll or 0)
	)
	return part
end

local function createJapaneseHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 1 and 8 or (variant == 2 and 11 or 9)
	local bodyWidth = variant == 3 and 22 or 20
	local bodyDepth = variant == 2 and 17 or 19
	local body = makePart(
		"Body",
		Vector3.new(bodyWidth, bodyHeight, bodyDepth),
		position + Vector3.new(0, bodyHeight / 2, 0),
		bodyColor:Lerp(Color3.fromRGB(214, 205, 184), 0.18),
		model,
		Enum.Material.WoodPlanks
	)

	local roofColor = variant == 3 and Color3.fromRGB(46, 49, 55) or Color3.fromRGB(56, 60, 66)
	makePart(
		"RoofLower",
		Vector3.new(bodyWidth + 4, 0.8, bodyDepth + 4),
		position + Vector3.new(0, bodyHeight + 0.45, 0),
		roofColor,
		model,
		Enum.Material.Slate
	)
	makePart(
		"RoofUpper",
		Vector3.new(bodyWidth + 2.2, 0.7, bodyDepth + 2.2),
		position + Vector3.new(0, bodyHeight + 1.15, 0),
		roofColor:Lerp(Color3.fromRGB(25, 27, 31), 0.16),
		model,
		Enum.Material.Slate
	)
	makePart(
		"RoofRidge",
		Vector3.new(1.1, 1.1, bodyDepth + 1.5),
		position + Vector3.new(0, bodyHeight + 1.85, 0),
		Color3.fromRGB(40, 42, 47),
		model,
		Enum.Material.Slate
	)

	local frontZ = -(bodyDepth / 2) - 0.31
	makePart(
		"Door",
		Vector3.new(3.6, 6.2, 0.55),
		position + Vector3.new(0, 3.1, frontZ),
		Color3.fromRGB(86, 62, 44),
		model,
		Enum.Material.Wood
	)

	-- Wooden frame and a small engawa/entry deck make the silhouette read as Japanese.
	for _, x in ipairs({-bodyWidth / 2 + 1.1, bodyWidth / 2 - 1.1}) do
		makePart(
			"FrontPost",
			Vector3.new(0.45, bodyHeight - 0.8, 0.45),
			position + Vector3.new(x, (bodyHeight - 0.8) / 2, frontZ - 0.1),
			Color3.fromRGB(77, 59, 43),
			model,
			Enum.Material.Wood
		)
	end

	makePart(
		"Engawa",
		Vector3.new(bodyWidth - 3, 0.35, 2.3),
		position + Vector3.new(0, 0.55, frontZ - 1.25),
		Color3.fromRGB(104, 78, 55),
		model,
		Enum.Material.WoodPlanks
	)

	if variant == 2 then
		makePart(
			"UpperBand",
			Vector3.new(bodyWidth + 0.3, 0.5, bodyDepth + 0.3),
			position + Vector3.new(0, 7.1, 0),
			Color3.fromRGB(86, 67, 50),
			model,
			Enum.Material.Wood
		)
	end

	makeLitWindow(model, "Window1", Vector3.new(3.2, 2.8, 0.22), position + Vector3.new(-5.1, math.min(5.7, bodyHeight - 2.3), frontZ - 0.18))
	makeLitWindow(model, "Window2", Vector3.new(3.2, 2.8, 0.22), position + Vector3.new(5.1, math.min(5.7, bodyHeight - 2.3), frontZ - 0.18))

	if variant == 2 then
		makeLitWindow(model, "WindowUpper", Vector3.new(4.4, 2.1, 0.22), position + Vector3.new(0, 8.7, frontZ - 0.18), Color3.fromRGB(247, 214, 155))
	end

	return body, frontZ
end

local function createWesternHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 1 and 12 or (variant == 2 and 15 or 10)
	local bodyWidth = variant == 3 and 24 or 19
	local bodyDepth = 16
	local wallMaterial = variant == 3 and Enum.Material.Brick or Enum.Material.Concrete
	local body = makePart(
		"Body",
		Vector3.new(bodyWidth, bodyHeight, bodyDepth),
		position + Vector3.new(0, bodyHeight / 2, 0),
		bodyColor:Lerp(Color3.fromRGB(225, 218, 205), 0.2),
		model,
		wallMaterial
	)

	local frontZ = -(bodyDepth / 2) - 0.31
	local roofBaseY = bodyHeight + 0.5
	local roofColor = variant == 2 and Color3.fromRGB(67, 49, 45) or Color3.fromRGB(62, 58, 61)

	-- Two sloped roof planes create a clear western-house silhouette.
	makeRotatedPart(
		"RoofLeft",
		Vector3.new(bodyWidth / 1.05, 1.0, bodyDepth + 4),
		position + Vector3.new(-bodyWidth * 0.22, roofBaseY + 2.2, 0),
		roofColor,
		model,
		Enum.Material.Slate,
		0, 0, -24
	)
	makeRotatedPart(
		"RoofRight",
		Vector3.new(bodyWidth / 1.05, 1.0, bodyDepth + 4),
		position + Vector3.new(bodyWidth * 0.22, roofBaseY + 2.2, 0),
		roofColor,
		model,
		Enum.Material.Slate,
		0, 0, 24
	)
	makePart(
		"RoofRidge",
		Vector3.new(1.0, 0.7, bodyDepth + 3.5),
		position + Vector3.new(0, roofBaseY + 4.0, 0),
		roofColor:Lerp(Color3.fromRGB(30, 29, 31), 0.2),
		model,
		Enum.Material.Slate
	)

	makePart(
		"Door",
		Vector3.new(3.5, 7, 0.55),
		position + Vector3.new(0, 3.5, frontZ),
		variant == 2 and Color3.fromRGB(61, 89, 112) or Color3.fromRGB(105, 70, 48),
		model,
		Enum.Material.Wood
	)

	makePart(
		"Porch",
		Vector3.new(9, 0.45, 3.3),
		position + Vector3.new(0, 0.45, frontZ - 1.8),
		Color3.fromRGB(132, 126, 115),
		model,
		Enum.Material.WoodPlanks
	)

	for _, x in ipairs({-3.7, 3.7}) do
		makePart(
			"PorchColumn",
			Vector3.new(0.45, 6.5, 0.45),
			position + Vector3.new(x, 3.25, frontZ - 2.7),
			Color3.fromRGB(222, 218, 207),
			model,
			Enum.Material.Wood
		)
	end

	makePart(
		"PorchAwning",
		Vector3.new(10.5, 0.45, 4.6),
		position + Vector3.new(0, 6.55, frontZ - 1.3),
		roofColor,
		model,
		Enum.Material.Slate
	)

	makeLitWindow(model, "Window1", Vector3.new(3.2, 3.2, 0.22), position + Vector3.new(-5, 6.4, frontZ - 0.18))
	makeLitWindow(model, "Window2", Vector3.new(3.2, 3.2, 0.22), position + Vector3.new(5, 6.4, frontZ - 0.18))

	if variant == 2 then
		makeLitWindow(model, "WindowUpper1", Vector3.new(3, 2.7, 0.22), position + Vector3.new(-4.8, 11.3, frontZ - 0.18))
		makeLitWindow(model, "WindowUpper2", Vector3.new(3, 2.7, 0.22), position + Vector3.new(4.8, 11.3, frontZ - 0.18))
	elseif variant == 3 then
		makePart(
			"GarageDoor",
			Vector3.new(7.2, 5.3, 0.45),
			position + Vector3.new(7.0, 2.65, frontZ),
			Color3.fromRGB(177, 178, 174),
			model,
			Enum.Material.Metal
		)
	end

	return body, frontZ
end

local function createWarehouseHouse(model, position, bodyColor, variant)
	local body = makePart(
		"Body",
		Vector3.new(24, 10, 20),
		position + Vector3.new(0, 5, 0),
		bodyColor,
		model,
		variant == 2 and Enum.Material.Brick or Enum.Material.Metal
	)
	makePart(
		"Roof",
		Vector3.new(26, 1, 22),
		position + Vector3.new(0, 10.5, 0),
		Color3.fromRGB(55, 58, 64),
		model,
		Enum.Material.Metal
	)
	makePart(
		"LoadingDoor",
		Vector3.new(9, 7, 0.5),
		position + Vector3.new(0, 3.5, -10.25),
		Color3.fromRGB(119, 124, 128),
		model,
		Enum.Material.Metal
	)
	makeLitWindow(model, "WarehouseWindow1", Vector3.new(3, 2.4, 0.2), position + Vector3.new(-7.5, 7.5, -10.3), Color3.fromRGB(208, 225, 226))
	makeLitWindow(model, "WarehouseWindow2", Vector3.new(3, 2.4, 0.2), position + Vector3.new(7.5, 7.5, -10.3), Color3.fromRGB(208, 225, 226))
	return body, -10.25
end

local function createHouse(id, displayName, districtId, position, bodyColor)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("DistrictId", districtId)
	model:SetAttribute("DistrictName", DISTRICT_NAMES[districtId] or districtId)
	model:SetAttribute("WorldThemeId", selectedWorldTheme.id)
	model:SetAttribute("WorldThemeName", selectedWorldTheme.name)
	model.Parent = housesFolder

	local variant = worldRandom:NextInteger(1, 3)
	model:SetAttribute("HouseVariant", variant)

	local body
	local frontZ
	if districtId == "warehouse" then
		body, frontZ = createWarehouseHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "japanese" then
		body, frontZ = createJapaneseHouse(model, position, bodyColor, variant)
	else
		body, frontZ = createWesternHouse(model, position, bodyColor, variant)
	end

	local porch = makePart(
		"DeliveryPoint",
		Vector3.new(5.5, 0.5, 4),
		position + Vector3.new(0, 0.25, frontZ - 3),
		Color3.fromRGB(76, 88, 96),
		model,
		Enum.Material.Concrete
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeliverPrompt"
	prompt.ActionText = "配達する"
	prompt.ObjectText = displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = porch

	local porchLight = makePart(
		"PorchLight",
		Vector3.new(0.55, 0.55, 0.25),
		position + Vector3.new(0, 7.25, frontZ - 0.2),
		Color3.fromRGB(255, 226, 169),
		model,
		Enum.Material.Neon
	)
	porchLight.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = 0.7
	light.Range = 13
	light.Color = Color3.fromRGB(255, 222, 165)
	light.Parent = porchLight

	model.PrimaryPart = body
	return model, prompt
end

local function createWorld()
	world:SetAttribute("ThemeId", selectedWorldTheme.id)
	world:SetAttribute("ThemeName", selectedWorldTheme.name)
	print("Night Delivery world theme:", selectedWorldTheme.name)
	setupLighting()

	makePart(
		"Ground",
		Vector3.new(460, 1, 410),
		Vector3.new(0, -0.5, 20),
		Color3.fromRGB(47, 61, 57),
		world,
		Enum.Material.Grass
	)

	makePart(
		"MainRoad",
		Vector3.new(34, 0.3, 260),
		Vector3.new(0, 0.15, 10),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Pavement
	)

	makePart(
		"CrossRoad",
		Vector3.new(320, 0.3, 28),
		Vector3.new(0, 0.17, 20),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Pavement
	)

	makePart(
		"NorthRoad",
		Vector3.new(240, 0.3, 24),
		Vector3.new(0, 0.17, 95),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Pavement
	)

	makePart(
		"RiversideRoad",
		Vector3.new(360, 0.3, 24),
		Vector3.new(0, 0.17, 135),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Pavement
	)

	local canal = makePart(
		"Canal",
		Vector3.new(400, 0.5, 22),
		Vector3.new(0, 0.05, 182),
		Color3.fromRGB(44, 91, 122),
		world,
		Enum.Material.Glass
	)
	canal.Transparency = 0.18
	canal.CanCollide = false

	for x = -165, 165, 55 do
		createStreetLight(Vector3.new(x, 0, 123))
	end

	makePart(
		"WarehouseRoad",
		Vector3.new(360, 0.3, 24),
		Vector3.new(0, 0.17, -125),
		Color3.fromRGB(42, 44, 49),
		world,
		Enum.Material.Pavement
	)

	for x = -165, 165, 55 do
		createStreetLight(Vector3.new(x, 0, -113))
	end

	for z = -100, 120, 30 do
		createStreetLight(Vector3.new(-21, 0, z))
		createStreetLight(Vector3.new(21, 0, z))
	end

	local depot = Instance.new("Model")
	depot.Name = "Depot"
	depot.Parent = world

	makePart(
		"DepotBuilding",
		Vector3.new(26, 10, 20),
		Vector3.new(-82, 5, -70),
		Color3.fromRGB(52, 77, 93),
		depot
	)

	local depotPad = makePart(
		"JobCounter",
		Vector3.new(9, 1, 7),
		Vector3.new(-82, 0.5, -84),
		Color3.fromRGB(240, 186, 86),
		depot,
		Enum.Material.Neon
	)

	local depotPrompt = Instance.new("ProximityPrompt")
	depotPrompt.Name = "AcceptJobPrompt"
	depotPrompt.ActionText = "配達を受ける"
	depotPrompt.ObjectText = "夜間配達所"
	depotPrompt.KeyboardKeyCode = Enum.KeyCode.E
	depotPrompt.Style = Enum.ProximityPromptStyle.Custom
	depotPrompt.HoldDuration = 0.25
	depotPrompt.MaxActivationDistance = 12
	depotPrompt.RequiresLineOfSight = false
	depotPrompt.Parent = depotPad

	local sign = makePart(
		"DepotSign",
		Vector3.new(14, 3, 0.6),
		Vector3.new(-82, 9, -79),
		Color3.fromRGB(102, 184, 225),
		depot,
		Enum.Material.Neon
	)
	makeSurfaceText(sign, "NIGHT DELIVERY")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DeliverySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(-58, 0.5, -72)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 0.25
	spawn.Color = Color3.fromRGB(97, 145, 181)
	spawn.Parent = world

	local bikePad = makePart(
		"BikeStand",
		Vector3.new(8, 0.7, 6),
		Vector3.new(-58, 0.35, -88),
		Color3.fromRGB(76, 168, 188),
		depot,
		Enum.Material.Neon
	)
	local bikePrompt = Instance.new("ProximityPrompt")
	bikePrompt.Name = "BikeModePrompt"
	bikePrompt.ActionText = "自転車モード切替"
	bikePrompt.ObjectText = "配達自転車"
	bikePrompt.KeyboardKeyCode = Enum.KeyCode.B
	bikePrompt.Style = Enum.ProximityPromptStyle.Custom
	bikePrompt.HoldDuration = 0.2
	bikePrompt.MaxActivationDistance = 12
	bikePrompt.RequiresLineOfSight = false
	bikePrompt.Parent = bikePad

	local shopPad = makePart(
		"UpgradeShop",
		Vector3.new(8, 0.7, 6),
		Vector3.new(-70, 0.35, -88),
		Color3.fromRGB(147, 108, 208),
		depot,
		Enum.Material.Neon
	)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "UpgradeShopPrompt"
	shopPrompt.ActionText = "ショップを開く"
	shopPrompt.ObjectText = "夜間配達ショップ"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.U
	shopPrompt.Style = Enum.ProximityPromptStyle.Custom
	shopPrompt.HoldDuration = 0.2
	shopPrompt.MaxActivationDistance = 12
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopPad

	local houseDefinitions = {
		{name = "BlueHouse", displayName = "青い家", districtId = "central", position = Vector3.new(-72, 0, 46), color = Color3.fromRGB(74, 111, 154)},
		{name = "RedHouse", displayName = "赤い家", districtId = "central", position = Vector3.new(72, 0, 60), color = Color3.fromRGB(146, 76, 72)},
		{name = "GreenHouse", displayName = "緑の家", districtId = "central", position = Vector3.new(-78, 0, 102), color = Color3.fromRGB(77, 124, 94)},
		{name = "YellowHouse", displayName = "黄色い家", districtId = "central", position = Vector3.new(76, 0, -8), color = Color3.fromRGB(151, 127, 69)},
		{name = "PurpleHouse", displayName = "紫の家", districtId = "central", position = Vector3.new(78, 0, -72), color = Color3.fromRGB(111, 81, 137)},
		{name = "WhiteHouse", displayName = "白い家", districtId = "central", position = Vector3.new(-112, 0, 96), color = Color3.fromRGB(180, 184, 190)},
		{name = "OrangeHouse", displayName = "橙の家", districtId = "central", position = Vector3.new(118, 0, 96), color = Color3.fromRGB(173, 107, 65)},
		{name = "MintHouse", displayName = "ミントの家", districtId = "central", position = Vector3.new(112, 0, 24), color = Color3.fromRGB(93, 151, 145)},
		{name = "RiverBlueHouse", displayName = "川辺の青い家", districtId = "riverside", position = Vector3.new(-150, 0, 157), color = Color3.fromRGB(71, 105, 148)},
		{name = "RiverPinkHouse", displayName = "川辺の桃色の家", districtId = "riverside", position = Vector3.new(-82, 0, 157), color = Color3.fromRGB(158, 101, 119)},
		{name = "RiverTealHouse", displayName = "川辺の青緑の家", districtId = "riverside", position = Vector3.new(82, 0, 157), color = Color3.fromRGB(72, 132, 133)},
		{name = "RiverCreamHouse", displayName = "川辺のクリームの家", districtId = "riverside", position = Vector3.new(150, 0, 157), color = Color3.fromRGB(181, 161, 119)},
		{name = "Warehouse01", displayName = "第1倉庫", districtId = "warehouse", position = Vector3.new(-150, 0, -145), color = Color3.fromRGB(92, 101, 112)},
		{name = "Warehouse02", displayName = "第2倉庫", districtId = "warehouse", position = Vector3.new(-78, 0, -145), color = Color3.fromRGB(110, 91, 81)},
		{name = "Warehouse03", displayName = "第3倉庫", districtId = "warehouse", position = Vector3.new(78, 0, -145), color = Color3.fromRGB(82, 105, 99)},
		{name = "Warehouse04", displayName = "第4倉庫", districtId = "warehouse", position = Vector3.new(150, 0, -145), color = Color3.fromRGB(105, 91, 118)},
	}

	local prompts = {}
	for _, definition in ipairs(houseDefinitions) do
		local _, prompt = createHouse(definition.name, definition.displayName, definition.districtId, definition.position, definition.color)
		table.insert(prompts, {
			houseName = definition.name,
			displayName = definition.displayName,
			prompt = prompt,
		})
	end

	shopPadRef = shopPad
	return depotPrompt, bikePrompt, shopPrompt, prompts
end

local function sendStatus(player, action, payload)
	deliveryEvent:FireClient(player, action, payload or {})
end

local function getStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return {
		coins = leaderstats:FindFirstChild("Coins"),
		deliveries = leaderstats:FindFirstChild("Deliveries"),
	}
end

local function getSpeedUpgradeCost(level)
	return 150 + (level * 125)
end

local function getRankName(deliveries)
	if deliveries >= 30 then
		return "夜のエース"
	elseif deliveries >= 15 then
		return "ベテラン配達員"
	elseif deliveries >= 5 then
		return "配達員"
	end
	return "新人"
end

local function getStyle(styleTable, level)
	local index = math.clamp((level or 0) + 1, 1, #styleTable)
	return styleTable[index], index - 1
end

local function getNextStyle(styleTable, level)
	local nextIndex = (level or 0) + 2
	if nextIndex > #styleTable then
		return nil
	end
	return styleTable[nextIndex], nextIndex - 1
end

local function isNearPart(player, part, range)
	if not part then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - part.Position).Magnitude <= range
end

local function applyMovementSpeed(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedLevel = player:GetAttribute("SpeedLevel") or 0
	local bikeActive = player:GetAttribute("BikeActive") == true
	local targetSpeed = BASE_WALK_SPEED + (speedLevel * SPEED_PER_LEVEL)

	if bikeActive then
		targetSpeed += BIKE_BONUS_SPEED
	end

	humanoid.WalkSpeed = targetSpeed
end

local function clearParcelVisual(player)
	local character = player.Character
	if not character then
		return
	end

	local old = character:FindFirstChild("DeliveryParcel")
	if old then
		old:Destroy()
	end
end

local function clearBikeVisual(player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("DeliveryBikeVisual")
	if old then
		old:Destroy()
	end
end

local function addBikeVisual(player)
	clearBikeVisual(player)
	if player:GetAttribute("BikeActive") ~= true then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local style = getStyle(BIKE_STYLES, player:GetAttribute("BikeStyleLevel") or 0)
	local model = Instance.new("Model")
	model.Name = "DeliveryBikeVisual"
	model.Parent = character

	local function bikePart(name, size, offset, color, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.Metal
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		if shape then
			part.Shape = shape
		end
		part.CFrame = root.CFrame * offset
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	bikePart("Frame", Vector3.new(0.25, 1.4, 3.2), CFrame.new(0, -1.9, 0.7), style.color)
	bikePart("WheelFront", Vector3.new(0.35, 2.3, 2.3), CFrame.new(0, -2.0, -1.0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 42, 46), Enum.PartType.Cylinder)
	bikePart("WheelBack", Vector3.new(0.35, 2.3, 2.3), CFrame.new(0, -2.0, 2.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 42, 46), Enum.PartType.Cylinder)
end

local function addParcelVisual(player, jobTypeId)
	local character = player.Character
	if not character then
		return
	end

	clearParcelVisual(player)

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local parcel = Instance.new("Part")
	parcel.Name = "DeliveryParcel"
	parcel.Size = Vector3.new(2.2, 1.7, 1.3)

	local bagStyle = getStyle(BAG_STYLES, player:GetAttribute("BagStyleLevel") or 0)

	if jobTypeId == "special" then
		parcel.Color = Color3.fromRGB(186, 112, 255)
		parcel.Material = Enum.Material.Neon
	elseif jobTypeId == "express" then
		parcel.Color = Color3.fromRGB(255, 178, 72)
		parcel.Material = Enum.Material.SmoothPlastic
	elseif jobTypeId == "long" then
		parcel.Color = Color3.fromRGB(91, 151, 204)
		parcel.Material = Enum.Material.SmoothPlastic
	else
		parcel.Color = bagStyle.color
		parcel.Material = Enum.Material.SmoothPlastic
	end

	parcel.CanCollide = false
	parcel.CanQuery = false
	parcel.Massless = true
	parcel.CFrame = root.CFrame * CFrame.new(0, 0.5, 1.35)
	parcel.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = parcel
	weld.Parent = parcel
end

local function getPlayerDeliveries(player)
	local stats = getStats(player)
	if stats and stats.deliveries then
		return stats.deliveries.Value
	end
	return 0
end

local function isHouseUnlocked(player, house)
	local districtId = house:GetAttribute("DistrictId") or "central"
	if districtId == "riverside" then
		return getPlayerDeliveries(player) >= RIVERSIDE_UNLOCK_DELIVERIES
	elseif districtId == "warehouse" then
		return getPlayerDeliveries(player) >= WAREHOUSE_UNLOCK_DELIVERIES
	end
	return true
end

local function chooseJobType(player)
	local deliveries = getPlayerDeliveries(player)
	local available = {}
	local totalWeight = 0

	for _, jobType in ipairs(JOB_TYPES) do
		if deliveries >= (jobType.minDeliveries or 0) then
			table.insert(available, jobType)
			totalWeight += jobType.weight
		end
	end

	local roll = math.random() * totalWeight
	local cursor = 0

	for _, jobType in ipairs(available) do
		cursor += jobType.weight
		if roll <= cursor then
			return jobType
		end
	end

	return available[1] or JOB_TYPES[1]
end

local function findJobType(id)
	for _, jobType in ipairs(JOB_TYPES) do
		if jobType.id == id then
			return jobType
		end
	end
	return JOB_TYPES[1]
end

local function assignJob(player)
	if playerJobs[player] then
		sendStatus(player, "Message", {
			text = "すでに配達中だよ。今の荷物を先に届けよう。",
		})
		return
	end

	local houses = housesFolder:GetChildren()
	if #houses == 0 then
		return
	end

	local candidates = {}
	local lastHouse = playerLastHouse[player]

	for _, house in ipairs(houses) do
		if isHouseUnlocked(player, house) and (house.Name ~= lastHouse or #houses == 1) then
			table.insert(candidates, house)
		end
	end

	if #candidates == 0 then
		return
	end

	local target = candidates[math.random(1, #candidates)]
	local jobType = chooseJobType(player)
	local districtId = target:GetAttribute("DistrictId") or "central"
	local districtName = target:GetAttribute("DistrictName") or DISTRICT_NAMES[districtId] or districtId
	local weather = currentWeather
	local now = workspace:GetServerTimeNow()
	local expiresAt = now + jobType.timeLimit

	playerJobs[player] = {
		houseName = target.Name,
		displayName = target:GetAttribute("DisplayName") or target.Name,
		districtId = districtId,
		districtName = districtName,
		jobTypeId = jobType.id,
		weatherId = weather.id,
		weatherName = weather.name,
		weatherMultiplier = weather.rewardMultiplier,
		expiresAt = expiresAt,
		startedAt = now,
	}

	playerLastHouse[player] = target.Name
	addParcelVisual(player, jobType.id)

	sendStatus(player, "JobAssigned", {
		houseName = target.Name,
		displayName = target:GetAttribute("DisplayName") or target.Name,
		districtId = districtId,
		districtName = districtName,
		jobTypeId = jobType.id,
		jobTypeName = jobType.name,
		weatherId = weather.id,
		weatherName = weather.name,
		weatherMultiplier = weather.rewardMultiplier,
		expiresAt = expiresAt,
		timeLimit = jobType.timeLimit,
		baseReward = jobType.baseReward,
	})
end

local function completeDelivery(player, houseName)
	local job = playerJobs[player]
	if not job then
		sendStatus(player, "Message", {
			text = "先に配達所で荷物を受け取ろう。",
		})
		return
	end

	if job.houseName ~= houseName then
		sendStatus(player, "Message", {
			text = "ここじゃない。黄色く光っている配達先を確認しよう。",
		})
		return
	end

	local jobType = findJobType(job.jobTypeId)
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, math.floor(job.expiresAt - now))

	if remaining > 0 then
		playerStreak[player] = (playerStreak[player] or 0) + 1
	else
		playerStreak[player] = 0
	end

	local streak = playerStreak[player] or 0
	local streakBonus = math.min(streak, 5) * 10
	local rawReward = jobType.baseReward + (remaining * jobType.timeBonusPerSecond) + streakBonus
	local weatherMultiplier = job.weatherMultiplier or 1
	local weatherBonus = math.max(0, math.floor(rawReward * (weatherMultiplier - 1)))
	local reward = math.floor(rawReward * weatherMultiplier)

	local targetHouse = housesFolder:FindFirstChild(houseName)
	local targetPart = targetHouse and targetHouse:FindFirstChild("DeliveryPoint")
	local helperCount = 0

	if targetPart then
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player and isNearPart(otherPlayer, targetPart, COOP_RANGE) then
				helperCount += 1
				local otherStats = getStats(otherPlayer)
				if otherStats and otherStats.coins then
					otherStats.coins.Value += HELPER_REWARD
					sendStatus(otherPlayer, "AssistReward", {
						reward = HELPER_REWARD,
						playerName = player.DisplayName,
					})
				end
				if helperCount >= MAX_COOP_HELPERS then
					break
				end
			end
		end
	end

	local coopBonus = math.floor(reward * (COOP_BONUS_PER_HELPER * helperCount))
	reward += coopBonus

	local shiftBonus = 0
	if remaining > 0 then
		playerShiftProgress[player] = (playerShiftProgress[player] or 0) + 1
		if playerShiftProgress[player] >= SHIFT_TARGET then
			playerShiftProgress[player] = 0
			shiftBonus = SHIFT_REWARD
			reward += shiftBonus
			player:SetAttribute("ShiftWins", (player:GetAttribute("ShiftWins") or 0) + 1)
		end
	end

	local stats = getStats(player)
	local deliveriesAfter = nil
	if stats and stats.coins and stats.deliveries then
		stats.coins.Value += reward
		stats.deliveries.Value += 1
		deliveriesAfter = stats.deliveries.Value
	end

	local districtUnlocked = deliveriesAfter == RIVERSIDE_UNLOCK_DELIVERIES
	local specialJobsUnlocked = deliveriesAfter == SPECIAL_JOB_UNLOCK_DELIVERIES
	local warehouseUnlocked = deliveriesAfter == WAREHOUSE_UNLOCK_DELIVERIES

	playerJobs[player] = nil
	clearParcelVisual(player)

	sendStatus(player, "Delivered", {
		houseName = houseName,
		displayName = job.displayName,
		reward = reward,
		timeRemaining = remaining,
		streak = streak,
		streakBonus = streakBonus,
		weatherName = job.weatherName or "晴れ",
		weatherBonus = weatherBonus,
		coopBonus = coopBonus,
		helperCount = helperCount,
		shiftBonus = shiftBonus,
		shiftProgress = playerShiftProgress[player] or 0,
		shiftTarget = SHIFT_TARGET,
		rankName = getRankName(deliveriesAfter or 0),
		districtUnlocked = districtUnlocked,
		specialJobsUnlocked = specialJobsUnlocked,
		warehouseUnlocked = warehouseUnlocked,
	})
end

local function toggleBike(player)
	local active = not (player:GetAttribute("BikeActive") == true)
	player:SetAttribute("BikeActive", active)
	applyMovementSpeed(player)
	addBikeVisual(player)

	sendStatus(player, "BikeMode", {
		active = active,
		speedLevel = player:GetAttribute("SpeedLevel") or 0,
	})
end

local function tryUpgradeSpeed(player)
	local level = player:GetAttribute("SpeedLevel") or 0
	if level >= MAX_SPEED_LEVEL then
		sendStatus(player, "Message", {
			text = "速度強化は最大レベルだよ。",
		})
		return
	end

	local stats = getStats(player)
	if not stats or not stats.coins then
		return
	end

	local cost = getSpeedUpgradeCost(level)
	if stats.coins.Value < cost then
		sendStatus(player, "Message", {
			text = string.format("速度強化には %d Coins 必要。", cost),
		})
		return
	end

	stats.coins.Value -= cost
	level += 1
	player:SetAttribute("SpeedLevel", level)
	applyMovementSpeed(player)

	local nextCost = level < MAX_SPEED_LEVEL and getSpeedUpgradeCost(level) or 0
	sendStatus(player, "SpeedUpgraded", {
		level = level,
		nextCost = nextCost,
	})
end

local function loadData(player)
	local defaultData = {
		coins = 0,
		deliveries = 0,
		speedLevel = 0,
		bagStyleLevel = 0,
		bikeStyleLevel = 0,
		shiftWins = 0,
	}
	if not DELIVERY_STORE then
		return defaultData
	end

	local success = false
	local data = nil

	for attempt = 1, 3 do
		success, data = pcall(function()
			return DELIVERY_STORE:GetAsync("player_" .. player.UserId)
		end)
		if success then
			break
		end
		warn("Night Delivery: DataStore load attempt failed for", player.Name, attempt, data)
		task.wait(0.35 * attempt)
	end

	if success and type(data) == "table" then
		defaultData.coins = tonumber(data.coins) or 0
		defaultData.deliveries = tonumber(data.deliveries) or 0
		defaultData.speedLevel = math.clamp(tonumber(data.speedLevel) or 0, 0, MAX_SPEED_LEVEL)
		defaultData.bagStyleLevel = math.clamp(tonumber(data.bagStyleLevel) or 0, 0, #BAG_STYLES - 1)
		defaultData.bikeStyleLevel = math.clamp(tonumber(data.bikeStyleLevel) or 0, 0, #BIKE_STYLES - 1)
		defaultData.shiftWins = math.max(0, tonumber(data.shiftWins) or 0)
	elseif not success then
		warn("Night Delivery: DataStore load failed after retries for", player.Name)
	end

	return defaultData
end

local function saveData(player)
	if not DELIVERY_STORE then
		return false
	end

	local stats = getStats(player)
	if not stats or not stats.coins or not stats.deliveries then
		return
	end

	local payload = {
		coins = stats.coins.Value,
		deliveries = stats.deliveries.Value,
		speedLevel = player:GetAttribute("SpeedLevel") or 0,
		bagStyleLevel = player:GetAttribute("BagStyleLevel") or 0,
		bikeStyleLevel = player:GetAttribute("BikeStyleLevel") or 0,
		shiftWins = player:GetAttribute("ShiftWins") or 0,
	}

	local success = false
	local err = nil
	for attempt = 1, 3 do
		success, err = pcall(function()
			DELIVERY_STORE:UpdateAsync("player_" .. player.UserId, function()
				return payload
			end)
		end)
		if success then
			return true
		end
		warn("Night Delivery: DataStore save attempt failed for", player.Name, attempt, err)
		task.wait(0.35 * attempt)
	end

	warn("Night Delivery: DataStore save failed after retries for", player.Name, err)
	return false
end

local function sendShopState(player)
	local stats = getStats(player)
	if not stats or not stats.coins then
		return
	end

	local speedLevel = player:GetAttribute("SpeedLevel") or 0
	local bagLevel = player:GetAttribute("BagStyleLevel") or 0
	local bikeStyleLevel = player:GetAttribute("BikeStyleLevel") or 0
	local bagStyle = getStyle(BAG_STYLES, bagLevel)
	local bikeStyle = getStyle(BIKE_STYLES, bikeStyleLevel)
	local nextBag = getNextStyle(BAG_STYLES, bagLevel)
	local nextBike = getNextStyle(BIKE_STYLES, bikeStyleLevel)

	sendStatus(player, "ShopState", {
		coins = stats.coins.Value,
		speedLevel = speedLevel,
		speedCost = speedLevel < MAX_SPEED_LEVEL and getSpeedUpgradeCost(speedLevel) or 0,
		bagStyleName = bagStyle.name,
		bagNextName = nextBag and nextBag.name or nil,
		bagCost = nextBag and nextBag.cost or 0,
		bikeStyleName = bikeStyle.name,
		bikeNextName = nextBike and nextBike.name or nil,
		bikeCost = nextBike and nextBike.cost or 0,
	})
end

local function openShop(player)
	if not isNearPart(player, shopPadRef, 16) then
		return
	end
	sendShopState(player)
	sendStatus(player, "ShopOpened", {})
end

local function buyNextStyle(player, kind)
	if not isNearPart(player, shopPadRef, 18) then
		return
	end

	local stats = getStats(player)
	if not stats or not stats.coins then
		return
	end

	local styleTable = kind == "bag" and BAG_STYLES or BIKE_STYLES
	local attributeName = kind == "bag" and "BagStyleLevel" or "BikeStyleLevel"
	local level = player:GetAttribute(attributeName) or 0
	local nextStyle, nextLevel = getNextStyle(styleTable, level)

	if not nextStyle then
		sendStatus(player, "Message", {text = "このコスメは最大まで解放済み。"})
		return
	end

	if stats.coins.Value < nextStyle.cost then
		sendStatus(player, "Message", {text = string.format("%d Coins 必要。", nextStyle.cost)})
		return
	end

	stats.coins.Value -= nextStyle.cost
	player:SetAttribute(attributeName, nextLevel)

	if kind == "bag" and playerJobs[player] then
		addParcelVisual(player, playerJobs[player].jobTypeId)
	elseif kind == "bike" then
		addBikeVisual(player)
	end

	sendStatus(player, "CosmeticPurchased", {
		kind = kind,
		name = nextStyle.name,
	})
	sendShopState(player)
end

local function applyWeather(weather)
	currentWeather = weather
	local atmosphere = Lighting:FindFirstChild("NightDeliveryAtmosphere")

	if weather.id == "rain" then
		Lighting.Brightness = 1.0
		Lighting.FogEnd = 480
		Lighting.FogColor = Color3.fromRGB(48, 58, 72)
		if atmosphere then
			atmosphere.Density = 0.32
			atmosphere.Haze = 1.8
		end
	elseif weather.id == "fog" then
		Lighting.Brightness = 1.15
		Lighting.FogEnd = 280
		Lighting.FogColor = Color3.fromRGB(80, 88, 102)
		if atmosphere then
			atmosphere.Density = 0.48
			atmosphere.Haze = 2.4
		end
	else
		Lighting.Brightness = 1.35
		Lighting.FogEnd = 700
		Lighting.FogColor = Color3.fromRGB(34, 39, 57)
		if atmosphere then
			atmosphere.Density = 0.2
			atmosphere.Haze = 1.1
		end
	end

	deliveryEvent:FireAllClients("WeatherChanged", {
		weatherId = weather.id,
		weatherName = weather.name,
		rewardMultiplier = weather.rewardMultiplier,
	})
end

local function startWeatherLoop()
	task.spawn(function()
		while true do
			task.wait(WEATHER_CHANGE_SECONDS)
			local candidates = {}
			for _, weather in ipairs(WEATHER_TYPES) do
				if weather.id ~= currentWeather.id then
					table.insert(candidates, weather)
				end
			end
			applyWeather(candidates[math.random(1, #candidates)])
		end
	end)
end

local function sendPlayerState(player)
	local stats = getStats(player)
	local deliveries = stats and stats.deliveries and stats.deliveries.Value or 0
	local speedLevel = player:GetAttribute("SpeedLevel") or 0

	sendStatus(player, "Welcome", {
		speedLevel = speedLevel,
		deliveries = deliveries,
		rankName = getRankName(deliveries),
		shiftProgress = playerShiftProgress[player] or 0,
		shiftTarget = SHIFT_TARGET,
		shiftWins = player:GetAttribute("ShiftWins") or 0,
		weatherName = currentWeather.name,
		weatherMultiplier = currentWeather.rewardMultiplier,
		riversideUnlockAt = RIVERSIDE_UNLOCK_DELIVERIES,
		specialJobUnlockAt = SPECIAL_JOB_UNLOCK_DELIVERIES,
		warehouseUnlockAt = WAREHOUSE_UNLOCK_DELIVERIES,
		riversideUnlocked = deliveries >= RIVERSIDE_UNLOCK_DELIVERIES,
		specialJobsUnlocked = deliveries >= SPECIAL_JOB_UNLOCK_DELIVERIES,
		warehouseUnlocked = deliveries >= WAREHOUSE_UNLOCK_DELIVERIES,
		nextUpgradeCost = speedLevel < MAX_SPEED_LEVEL and getSpeedUpgradeCost(speedLevel) or 0,
	})
end

local depotPrompt, bikePrompt, shopPrompt, housePrompts = createWorld()

depotPrompt.Triggered:Connect(assignJob)
bikePrompt.Triggered:Connect(toggleBike)
shopPrompt.Triggered:Connect(openShop)

deliveryEvent.OnServerEvent:Connect(function(player, action)
	if type(action) ~= "string" then
		return
	end

	local now = os.clock()
	local lastAction = remoteLastAction[player] or 0
	if now - lastAction < REMOTE_COOLDOWN_SECONDS then
		return
	end
	remoteLastAction[player] = now

	if action == "RequestState" then
		if player:GetAttribute("NightDeliveryReady") == true then
			sendPlayerState(player)
		else
			task.spawn(function()
				for _ = 1, 100 do
					if not player.Parent then
						return
					end
					if player:GetAttribute("NightDeliveryReady") == true then
						sendPlayerState(player)
						return
					end
					task.wait(0.1)
				end
			end)
		end
	elseif action == "BuySpeed" then
		if isNearPart(player, shopPadRef, 18) then
			tryUpgradeSpeed(player)
			sendShopState(player)
		end
	elseif action == "BuyBagStyle" then
		buyNextStyle(player, "bag")
	elseif action == "BuyBikeStyle" then
		buyNextStyle(player, "bike")
	elseif action == "RequestShopState" then
		if isNearPart(player, shopPadRef, 18) then
			sendShopState(player)
		end
	end
end)

applyWeather(currentWeather)
startWeatherLoop()

for _, entry in ipairs(housePrompts) do
	entry.prompt.Triggered:Connect(function(player)
		completeDelivery(player, entry.houseName)
	end)
end

local function setupPlayer(player)
	player:SetAttribute("NightDeliveryReady", false)
	local data = loadData(player)
	if not player.Parent then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = leaderstats

	local deliveries = Instance.new("IntValue")
	deliveries.Name = "Deliveries"
	deliveries.Value = data.deliveries
	deliveries.Parent = leaderstats

	player:SetAttribute("SpeedLevel", data.speedLevel)
	player:SetAttribute("BikeActive", false)
	player:SetAttribute("BagStyleLevel", data.bagStyleLevel)
	player:SetAttribute("BikeStyleLevel", data.bikeStyleLevel)
	player:SetAttribute("ShiftWins", data.shiftWins)
	playerStreak[player] = 0
	playerShiftProgress[player] = 0

	local function setupCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.wait(0.2)
			applyMovementSpeed(player)
			addBikeVisual(player)
		end

		task.wait(0.2)
		if playerJobs[player] then
			addParcelVisual(player, playerJobs[player].jobTypeId)
		end
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end

	player:SetAttribute("NightDeliveryReady", true)
	sendPlayerState(player)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerJobs[player] = nil
	playerLastHouse[player] = nil
	playerStreak[player] = nil
	playerShiftProgress[player] = nil
	remoteLastAction[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
	task.wait(1)
end)