-- Night Delivery v4
-- ServerScriptService/NightDelivery.server.lua
-- Code-complete prototype: generated town, progression, dynamic weather,
-- co-op bonuses, cosmetics, shop flow, rare jobs, and persistent upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local RULES = require(script.Parent:WaitForChild("NightDeliveryRules"))

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

-- Persistent story clues make repeated deliveries reveal a small neighborhood mystery.
local RUMOR_CLUES = {
	{deliveries = 3, title = "灯りのついた青い家", text = "誰も住んでいないはずの青い家で、今夜も玄関灯が点いている。", reward = 0},
	{deliveries = 8, title = "宛名のない荷物", text = "差出人の欄は空白。でも、古い配達員名簿と同じ名字が受取人に書かれていた。", reward = 0},
	{deliveries = 15, title = "最後の配達記録", text = "配達所の古い帳簿に、青い家を最後に訪ねた配達員の記録が残っていた。", reward = 0},
	{deliveries = 25, title = "夜の配達員", text = "荷物の中には「毎晩ありがとう」の手紙。青い家の灯りは、帰りを待つ人の目印だった。", reward = 500},
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
local playerResidentVisits = {}
local playerLastDestinationEvent = {}
local currentNightRule = RULES.NightConditions[1]
local playerStreak = {}
local playerShiftProgress = {}
local remoteLastAction = {}
local playerDataLoadSucceeded = {}
local currentWeather = WEATHER_TYPES[1]
local shopPadRef = nil
local jobCounterRef = nil
local bikePadRef = nil

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

local WORLD_THEMES = {
	{
		id = "japanese",
		name = "日本住宅街",
		groundColor = Color3.fromRGB(47, 61, 57),
		roadColor = Color3.fromRGB(48, 51, 55),
		warehouseRoadColor = Color3.fromRGB(42, 44, 49),
		canalColor = Color3.fromRGB(44, 91, 122),
		streetLightColor = Color3.fromRGB(255, 229, 174),
		streetLightBrightness = 1.8,
		streetLightRange = 24,
		streetLightHeight = 10,
		roadScale = 0.92,
		decoration = "japanese",
		initialWeatherId = "clear",
	},
	{
		id = "western",
		name = "西洋住宅街",
		groundColor = Color3.fromRGB(54, 71, 54),
		roadColor = Color3.fromRGB(50, 51, 56),
		warehouseRoadColor = Color3.fromRGB(44, 45, 50),
		canalColor = Color3.fromRGB(48, 94, 126),
		streetLightColor = Color3.fromRGB(255, 236, 194),
		streetLightBrightness = 1.7,
		streetLightRange = 27,
		streetLightHeight = 11,
		roadScale = 1.08,
		decoration = "western",
		initialWeatherId = "clear",
	},
	{
		id = "showa",
		name = "昭和住宅街",
		groundColor = Color3.fromRGB(54, 57, 50),
		roadColor = Color3.fromRGB(55, 54, 52),
		warehouseRoadColor = Color3.fromRGB(49, 48, 47),
		canalColor = Color3.fromRGB(55, 78, 87),
		streetLightColor = Color3.fromRGB(255, 193, 119),
		streetLightBrightness = 1.25,
		streetLightRange = 20,
		streetLightHeight = 8.5,
		roadScale = 0.78,
		decoration = "showa",
		initialWeatherId = "clear",
	},
	{
		id = "luxury",
		name = "高級住宅街",
		groundColor = Color3.fromRGB(43, 66, 52),
		roadColor = Color3.fromRGB(43, 45, 49),
		warehouseRoadColor = Color3.fromRGB(40, 42, 46),
		canalColor = Color3.fromRGB(42, 95, 119),
		streetLightColor = Color3.fromRGB(255, 240, 207),
		streetLightBrightness = 2.0,
		streetLightRange = 30,
		streetLightHeight = 12,
		roadScale = 1.18,
		decoration = "luxury",
		initialWeatherId = "clear",
	},
	{
		id = "harbor",
		name = "雨の港町",
		groundColor = Color3.fromRGB(48, 54, 57),
		roadColor = Color3.fromRGB(39, 43, 47),
		warehouseRoadColor = Color3.fromRGB(36, 40, 44),
		canalColor = Color3.fromRGB(35, 74, 95),
		streetLightColor = Color3.fromRGB(183, 219, 239),
		streetLightBrightness = 1.65,
		streetLightRange = 25,
		streetLightHeight = 11,
		roadScale = 1.02,
		decoration = "harbor",
		initialWeatherId = "rain",
	},
	{
		id = "mountain",
		name = "山間集落",
		groundColor = Color3.fromRGB(39, 58, 43),
		roadColor = Color3.fromRGB(56, 55, 51),
		warehouseRoadColor = Color3.fromRGB(49, 49, 46),
		canalColor = Color3.fromRGB(47, 84, 94),
		streetLightColor = Color3.fromRGB(255, 213, 145),
		streetLightBrightness = 1.1,
		streetLightRange = 19,
		streetLightHeight = 8,
		roadScale = 0.74,
		decoration = "mountain",
		initialWeatherId = "fog",
	},
	{
		id = "danchi",
		name = "団地エリア",
		groundColor = Color3.fromRGB(57, 65, 58),
		roadColor = Color3.fromRGB(48, 50, 53),
		warehouseRoadColor = Color3.fromRGB(43, 45, 48),
		canalColor = Color3.fromRGB(52, 88, 105),
		streetLightColor = Color3.fromRGB(220, 232, 238),
		streetLightBrightness = 1.55,
		streetLightRange = 24,
		streetLightHeight = 10.5,
		roadScale = 1.0,
		decoration = "danchi",
		initialWeatherId = "clear",
	},
}

local worldRandom = Random.new()
local selectedWorldTheme = WORLD_THEMES[worldRandom:NextInteger(1, #WORLD_THEMES)]

for _, weather in ipairs(WEATHER_TYPES) do
	if weather.id == selectedWorldTheme.initialWeatherId then
		currentWeather = weather
		break
	end
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
	Lighting.ClockTime = selectedWorldTheme.id == "showa" and 21.85 or 22.35
	Lighting.Brightness = selectedWorldTheme.id == "harbor" and 0.95 or (selectedWorldTheme.id == "mountain" and 1.05 or 1.35)
	Lighting.Ambient = selectedWorldTheme.id == "harbor"
		and Color3.fromRGB(53, 64, 76)
		or Color3.fromRGB(67, 72, 96)
	Lighting.OutdoorAmbient = selectedWorldTheme.id == "mountain"
		and Color3.fromRGB(34, 42, 42)
		or Color3.fromRGB(42, 47, 68)
	Lighting.FogColor = selectedWorldTheme.id == "mountain"
		and Color3.fromRGB(74, 82, 78)
		or (selectedWorldTheme.id == "harbor" and Color3.fromRGB(58, 69, 79) or Color3.fromRGB(34, 39, 57))
	Lighting.FogEnd = selectedWorldTheme.id == "mountain" and 330 or (selectedWorldTheme.id == "harbor" and 470 or 700)

	local atmosphere = Lighting:FindFirstChild("NightDeliveryAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "NightDeliveryAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = selectedWorldTheme.id == "mountain" and 0.36 or (selectedWorldTheme.id == "harbor" and 0.29 or 0.2)
	atmosphere.Haze = selectedWorldTheme.id == "mountain" and 2.0 or (selectedWorldTheme.id == "harbor" and 1.6 or 1.1)
	atmosphere.Color = selectedWorldTheme.id == "showa"
		and Color3.fromRGB(187, 161, 128)
		or Color3.fromRGB(145, 159, 205)
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


local function createShowaHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 2 and 10 or 8
	local bodyWidth = variant == 3 and 18 or 20
	local bodyDepth = 18
	local fadedColor = bodyColor:Lerp(Color3.fromRGB(143, 137, 121), 0.46)
	local body = makePart("Body", Vector3.new(bodyWidth, bodyHeight, bodyDepth), position + Vector3.new(0, bodyHeight / 2, 0), fadedColor, model, Enum.Material.WoodPlanks)
	local frontZ = -(bodyDepth / 2) - 0.3

	makePart("TinRoof", Vector3.new(bodyWidth + 3, 0.7, bodyDepth + 3), position + Vector3.new(0, bodyHeight + 0.6, 0), Color3.fromRGB(70, 72, 69), model, Enum.Material.Metal)
	makePart("Door", Vector3.new(3.2, 6.0, 0.5), position + Vector3.new(-2.2, 3.0, frontZ), Color3.fromRGB(76, 66, 52), model, Enum.Material.Wood)
	makeLitWindow(model, "Window1", Vector3.new(4.4, 2.7, 0.2), position + Vector3.new(4.2, 5.0, frontZ - 0.15), Color3.fromRGB(242, 197, 125))
	makeLitWindow(model, "Window2", Vector3.new(3.0, 2.4, 0.2), position + Vector3.new(-6.0, 5.2, frontZ - 0.15), Color3.fromRGB(238, 188, 112))
	makePart("Awning", Vector3.new(8.0, 0.35, 2.8), position + Vector3.new(3.6, 7.2, frontZ - 1.2), Color3.fromRGB(93, 87, 75), model, Enum.Material.Metal)

	if variant == 3 then
		makePart("SideShed", Vector3.new(7, 5.5, 11), position + Vector3.new(12, 2.75, 1), Color3.fromRGB(96, 92, 82), model, Enum.Material.CorrodedMetal)
	end
	return body, frontZ
end

local function createLuxuryHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 2 and 15 or 12
	local bodyWidth = variant == 3 and 28 or 24
	local bodyDepth = 19
	local body = makePart("Body", Vector3.new(bodyWidth, bodyHeight, bodyDepth), position + Vector3.new(0, bodyHeight / 2, 0), bodyColor:Lerp(Color3.fromRGB(224, 224, 219), 0.52), model, Enum.Material.Concrete)
	local frontZ = -(bodyDepth / 2) - 0.3

	makePart("FlatRoof", Vector3.new(bodyWidth + 1.5, 0.55, bodyDepth + 1.5), position + Vector3.new(0, bodyHeight + 0.3, 0), Color3.fromRGB(51, 54, 58), model, Enum.Material.Concrete)
	makePart("AccentWall", Vector3.new(5.0, bodyHeight - 1, 0.5), position + Vector3.new(-7.0, (bodyHeight - 1) / 2, frontZ), Color3.fromRGB(72, 67, 61), model, Enum.Material.Slate)
	makePart("Door", Vector3.new(3.8, 7.2, 0.45), position + Vector3.new(0, 3.6, frontZ), Color3.fromRGB(73, 65, 56), model, Enum.Material.Wood)
	makeLitWindow(model, "PanoramaWindow", Vector3.new(8.8, 3.6, 0.2), position + Vector3.new(6.3, 6.1, frontZ - 0.15), Color3.fromRGB(236, 226, 191))
	makeLitWindow(model, "SideWindow", Vector3.new(3.0, 3.0, 0.2), position + Vector3.new(-3.8, 6.2, frontZ - 0.15), Color3.fromRGB(229, 223, 196))

	makePart("GateLeft", Vector3.new(0.7, 4.2, 0.7), position + Vector3.new(-7.5, 2.1, frontZ - 5.2), Color3.fromRGB(66, 67, 69), model, Enum.Material.Slate)
	makePart("GateRight", Vector3.new(0.7, 4.2, 0.7), position + Vector3.new(7.5, 2.1, frontZ - 5.2), Color3.fromRGB(66, 67, 69), model, Enum.Material.Slate)
	makePart("Driveway", Vector3.new(12, 0.15, 8), position + Vector3.new(0, 0.1, frontZ - 5.0), Color3.fromRGB(100, 104, 105), model, Enum.Material.Concrete)

	if variant == 2 then
		makeLitWindow(model, "UpperWindow", Vector3.new(10, 2.6, 0.2), position + Vector3.new(2.5, 11.1, frontZ - 0.15), Color3.fromRGB(228, 219, 189))
	end
	return body, frontZ
end

local function createHarborHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 2 and 13 or 10
	local bodyWidth = 20
	local bodyDepth = 17
	local body = makePart("Body", Vector3.new(bodyWidth, bodyHeight, bodyDepth), position + Vector3.new(0, bodyHeight / 2, 0), bodyColor:Lerp(Color3.fromRGB(119, 133, 138), 0.42), model, variant == 3 and Enum.Material.Brick or Enum.Material.Metal)
	local frontZ = -(bodyDepth / 2) - 0.3

	makePart("Roof", Vector3.new(bodyWidth + 2, 0.7, bodyDepth + 2), position + Vector3.new(0, bodyHeight + 0.4, 0), Color3.fromRGB(48, 54, 59), model, Enum.Material.Metal)
	makePart("Door", Vector3.new(3.5, 6.5, 0.5), position + Vector3.new(-4.8, 3.25, frontZ), Color3.fromRGB(58, 74, 81), model, Enum.Material.Metal)
	makeLitWindow(model, "Window1", Vector3.new(4.2, 3.0, 0.2), position + Vector3.new(3.5, 5.6, frontZ - 0.15), Color3.fromRGB(203, 225, 232))
	makePart("Pipe", Vector3.new(0.65, bodyHeight - 1, 0.65), position + Vector3.new(8.6, (bodyHeight - 1) / 2, frontZ - 0.4), Color3.fromRGB(86, 92, 95), model, Enum.Material.Metal)
	makePart("MetalAwning", Vector3.new(8, 0.4, 3.2), position + Vector3.new(-2.6, 7.0, frontZ - 1.3), Color3.fromRGB(75, 83, 87), model, Enum.Material.Metal)

	if variant == 2 then
		makePart("UpperDeck", Vector3.new(9, 0.35, 2.5), position + Vector3.new(3.5, 9.3, frontZ - 1.4), Color3.fromRGB(84, 88, 91), model, Enum.Material.Metal)
		makeLitWindow(model, "UpperWindow", Vector3.new(4.4, 2.4, 0.2), position + Vector3.new(3.3, 10.7, frontZ - 0.15), Color3.fromRGB(196, 218, 229))
	end
	return body, frontZ
end

local function createMountainHouse(model, position, bodyColor, variant)
	local bodyHeight = variant == 2 and 11 or 8.5
	local bodyWidth = variant == 3 and 23 or 19
	local bodyDepth = 18
	local body = makePart("Body", Vector3.new(bodyWidth, bodyHeight, bodyDepth), position + Vector3.new(0, bodyHeight / 2, 0), bodyColor:Lerp(Color3.fromRGB(118, 91, 62), 0.38), model, Enum.Material.WoodPlanks)
	local frontZ = -(bodyDepth / 2) - 0.3
	local roofBaseY = bodyHeight + 0.4

	makeRotatedPart("RoofLeft", Vector3.new(bodyWidth / 1.05, 1.1, bodyDepth + 5), position + Vector3.new(-bodyWidth * 0.22, roofBaseY + 2.7, 0), Color3.fromRGB(48, 49, 47), model, Enum.Material.Slate, 0, 0, -31)
	makeRotatedPart("RoofRight", Vector3.new(bodyWidth / 1.05, 1.1, bodyDepth + 5), position + Vector3.new(bodyWidth * 0.22, roofBaseY + 2.7, 0), Color3.fromRGB(48, 49, 47), model, Enum.Material.Slate, 0, 0, 31)
	makePart("Door", Vector3.new(3.5, 6.4, 0.5), position + Vector3.new(0, 3.2, frontZ), Color3.fromRGB(74, 55, 39), model, Enum.Material.Wood)
	makeLitWindow(model, "Window1", Vector3.new(4.0, 3.0, 0.2), position + Vector3.new(-5.0, 5.2, frontZ - 0.15), Color3.fromRGB(244, 205, 139))
	makeLitWindow(model, "Window2", Vector3.new(4.0, 3.0, 0.2), position + Vector3.new(5.0, 5.2, frontZ - 0.15), Color3.fromRGB(244, 205, 139))
	makePart("WoodPile", Vector3.new(4.8, 2.0, 2.0), position + Vector3.new(8.0, 1.0, frontZ - 2.4), Color3.fromRGB(92, 66, 44), model, Enum.Material.Wood)
	return body, frontZ
end

local function createDanchiHouse(model, position, bodyColor, variant)
	local floors = variant == 2 and 4 or 3
	local bodyHeight = floors * 5
	local bodyWidth = variant == 3 and 28 or 24
	local bodyDepth = 15
	local body = makePart("Body", Vector3.new(bodyWidth, bodyHeight, bodyDepth), position + Vector3.new(0, bodyHeight / 2, 0), bodyColor:Lerp(Color3.fromRGB(188, 191, 184), 0.62), model, Enum.Material.Concrete)
	local frontZ = -(bodyDepth / 2) - 0.3

	makePart("FlatRoof", Vector3.new(bodyWidth + 1, 0.5, bodyDepth + 1), position + Vector3.new(0, bodyHeight + 0.3, 0), Color3.fromRGB(105, 107, 107), model, Enum.Material.Concrete)
	makePart("Entry", Vector3.new(4, 7, 0.5), position + Vector3.new(0, 3.5, frontZ), Color3.fromRGB(85, 91, 94), model, Enum.Material.Metal)

	for floor = 1, floors do
		local y = 2.7 + (floor - 1) * 5
		for _, x in ipairs({-7.5, -2.5, 2.5, 7.5}) do
			makeLitWindow(model, "Window_" .. floor .. "_" .. tostring(x), Vector3.new(2.6, 2.0, 0.18), position + Vector3.new(x, y, frontZ - 0.15), Color3.fromRGB(222, 224, 203))
		end
		if floor < floors then
			makePart("Balcony_" .. floor, Vector3.new(bodyWidth - 2, 0.25, 1.7), position + Vector3.new(0, y + 1.4, frontZ - 1.0), Color3.fromRGB(145, 147, 144), model, Enum.Material.Concrete)
		end
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

local RESIDENTS_BY_HOUSE = {
	BlueHouse = {name = "青木さん", color = Color3.fromRGB(82, 142, 191), first = "いつもこの時間にありがとう。温かいうちに受け取るね。", returnLine = "今夜も助かったよ。気をつけて帰ってね。"},
	RedHouse = {name = "佐藤さん", color = Color3.fromRGB(188, 104, 91), first = "遅くまでおつかれさま。荷物、待ってたよ。", returnLine = "また会えたね。今夜も配達ありがとう。"},
	GreenHouse = {name = "森さん", color = Color3.fromRGB(93, 150, 105), first = "庭の花が夜露に濡れてきれいでしょう。届けてくれてありがとう。", returnLine = "花に水をあげたところだよ。今夜もありがとう。"},
	YellowHouse = {name = "小林さん", color = Color3.fromRGB(194, 163, 75), first = "この明かりを目印にしてくれたの？助かったよ。", returnLine = "待っていたよ。足元に気をつけてね。"},
	PurpleHouse = {name = "高橋さん", color = Color3.fromRGB(133, 108, 170), first = "夜の配達って大変だね。受け取れてよかった。", returnLine = "今夜も届けてくれてありがとう。"},
	WhiteHouse = {name = "山本さん", color = Color3.fromRGB(183, 188, 190), first = "ちょうど必要なものだったんだ。ありがとう。", returnLine = "いつも助かってるよ。温かいお茶をどうぞ。"},
	OrangeHouse = {name = "井上さん", color = Color3.fromRGB(198, 132, 78), first = "おかえりなさい、って言いたくなる時間だね。ありがとう。", returnLine = "今夜も無事に届いたね。気をつけて。"},
	MintHouse = {name = "中村さん", color = Color3.fromRGB(93, 169, 148), first = "雨が降る前に届いてよかった。ありがとう。", returnLine = "またお願いしちゃったね。助かったよ。"},
	RiverBlueHouse = {name = "川辺さん", color = Color3.fromRGB(84, 143, 185), first = "川沿いは暗いから、灯りを頼りに来たよ。", returnLine = "川風が冷たいね。今夜もありがとう。"},
	RiverPinkHouse = {name = "桃井さん", color = Color3.fromRGB(183, 117, 143), first = "川の音を聞いて待っていたよ。ありがとう。", returnLine = "今夜も川沿いまでご苦労さま。"},
	RiverTealHouse = {name = "水野さん", color = Color3.fromRGB(82, 151, 153), first = "こんな遅くまで届けてくれてありがとう。", returnLine = "荷物、確かに受け取ったよ。気をつけてね。"},
	RiverCreamHouse = {name = "白石さん", color = Color3.fromRGB(183, 165, 130), first = "遠くまでありがとう。温かい飲み物を用意しておくね。", returnLine = "また来てくれてうれしいよ。ありがとう。"},
	Warehouse01 = {name = "田中さん", color = Color3.fromRGB(113, 140, 151), first = "夜勤の休憩に間に合った。ありがとう。", returnLine = "今夜の仕事もこれで頑張れそうだ。"},
	Warehouse02 = {name = "加藤さん", color = Color3.fromRGB(157, 127, 91), first = "倉庫まで届けてくれて助かったよ。", returnLine = "荷物を受け取ったよ。夜道に気をつけて。"},
	Warehouse03 = {name = "吉田さん", color = Color3.fromRGB(111, 150, 121), first = "ちょうど手が離せなかったんだ。ありがとう。", returnLine = "いつも時間どおりだね。助かるよ。"},
	Warehouse04 = {name = "斎藤さん", color = Color3.fromRGB(155, 124, 151), first = "この時間の配達は心強いね。ありがとう。", returnLine = "今夜もご苦労さま。無事に帰ってね。"},
}

local function createResident(model, position, frontZ, resident)
	model:SetAttribute("ResidentName", resident.name)
	model:SetAttribute("ResidentFirstLine", resident.first)
	model:SetAttribute("ResidentReturnLine", resident.returnLine)

	local basePosition = position + Vector3.new(7.5, 0, frontZ - 3)
	local torso = makePart("ResidentTorso", Vector3.new(1.6, 1.9, 0.85), basePosition + Vector3.new(0, 2.0, 0), resident.color, model)
	torso.CanCollide = false
	local head = makePart("ResidentHead", Vector3.new(1.2, 1.2, 1.2), basePosition + Vector3.new(0, 3.55, 0), Color3.fromRGB(231, 199, 166), model)
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false
	for _, x in ipairs({-0.43, 0.43}) do
		local leg = makePart("ResidentLeg", Vector3.new(0.48, 1.05, 0.55), basePosition + Vector3.new(x, 0.55, 0), Color3.fromRGB(48, 55, 68), model)
		leg.CanCollide = false
	end
	for _, x in ipairs({-1.0, 1.0}) do
		local arm = makePart("ResidentArm", Vector3.new(0.45, 1.5, 0.55), basePosition + Vector3.new(x, 2.0, 0), resident.color, model)
		arm.CanCollide = false
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ResidentNameTag"
	billboard.Size = UDim2.fromOffset(150, 30)
	billboard.StudsOffset = Vector3.new(0, 1.0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 55
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	label.BackgroundTransparency = 0.18
	label.Text = resident.name
	label.TextColor3 = Color3.fromRGB(247, 240, 220)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
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
	elseif selectedWorldTheme.id == "western" then
		body, frontZ = createWesternHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "showa" then
		body, frontZ = createShowaHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "luxury" then
		body, frontZ = createLuxuryHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "harbor" then
		body, frontZ = createHarborHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "mountain" then
		body, frontZ = createMountainHouse(model, position, bodyColor, variant)
	elseif selectedWorldTheme.id == "danchi" then
		body, frontZ = createDanchiHouse(model, position, bodyColor, variant)
	else
		body, frontZ = createJapaneseHouse(model, position, bodyColor, variant)
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

	local resident = RESIDENTS_BY_HOUSE[id]
	if resident then
		createResident(model, position, frontZ, resident)
	end

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


local function createThemeTree(position, scale, pine)
	scale = scale or 1
	local trunk = makePart("ThemeTreeTrunk", Vector3.new(1.1 * scale, 5.5 * scale, 1.1 * scale), position + Vector3.new(0, 2.75 * scale, 0), Color3.fromRGB(78, 59, 43), world, Enum.Material.Wood)
	if pine then
		for level = 1, 3 do
			local crown = makePart("PineCrown", Vector3.new((6.5 - level) * scale, 3.5 * scale, (6.5 - level) * scale), position + Vector3.new(0, (5.0 + level * 2.1) * scale, 0), Color3.fromRGB(40, 72, 49), world, Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	else
		local crown = makePart("ThemeTreeCrown", Vector3.new(5.6 * scale, 5.6 * scale, 5.6 * scale), position + Vector3.new(0, 7.1 * scale, 0), Color3.fromRGB(44, 82, 55), world, Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
	end
	return trunk
end

local function createUtilityPole(position)
	local pole = makePart("UtilityPole", Vector3.new(0.55, 10, 0.55), position + Vector3.new(0, 5, 0), Color3.fromRGB(74, 65, 55), world, Enum.Material.Wood)
	makePart("UtilityCrossbar", Vector3.new(5.0, 0.35, 0.35), position + Vector3.new(0, 9.1, 0), Color3.fromRGB(74, 65, 55), world, Enum.Material.Wood)
	return pole
end

local function createThemeDressing()
	local theme = selectedWorldTheme.id

	if theme == "japanese" then
		for _, pos in ipairs({Vector3.new(-105, 0, 52), Vector3.new(102, 0, 48), Vector3.new(-128, 0, 118)}) do
			makePart("BlockWall", Vector3.new(12, 2.2, 0.7), pos + Vector3.new(0, 1.1, 0), Color3.fromRGB(112, 113, 106), world, Enum.Material.Concrete)
		end
		makePart("VendingMachineTheme", Vector3.new(3, 6, 2), Vector3.new(37, 3, 75), Color3.fromRGB(178, 65, 64), world, Enum.Material.Metal)
	elseif theme == "western" then
		for _, pos in ipairs({Vector3.new(-118, 0, 45), Vector3.new(119, 0, 70), Vector3.new(-105, 0, 118), Vector3.new(105, 0, 118)}) do
			createThemeTree(pos, 1.0, false)
		end
		for _, pos in ipairs({Vector3.new(-46, 0, 65), Vector3.new(48, 0, 85)}) do
			makePart("MailboxPost", Vector3.new(0.35, 3.5, 0.35), pos + Vector3.new(0, 1.75, 0), Color3.fromRGB(84, 73, 61), world, Enum.Material.Wood)
			makePart("Mailbox", Vector3.new(1.8, 1.2, 1.2), pos + Vector3.new(0, 3.6, 0), Color3.fromRGB(77, 91, 104), world, Enum.Material.Metal)
		end
	elseif theme == "showa" then
		for z = -75, 115, 38 do
			createUtilityPole(Vector3.new(-31, 0, z))
			createUtilityPole(Vector3.new(31, 0, z + 12))
		end
		makePart("OldShopAwning", Vector3.new(13, 0.4, 4), Vector3.new(-145, 5.8, -12), Color3.fromRGB(132, 73, 59), world, Enum.Material.Fabric)
		local sign = makePart("OldShopSign", Vector3.new(8, 2.2, 0.35), Vector3.new(-145, 8, -14), Color3.fromRGB(198, 169, 103), world, Enum.Material.Neon)
		makeSurfaceText(sign, "よろず屋")
	elseif theme == "luxury" then
		for _, pos in ipairs({Vector3.new(-125, 0, 52), Vector3.new(123, 0, 52), Vector3.new(-125, 0, 105), Vector3.new(123, 0, 105)}) do
			createThemeTree(pos, 1.15, false)
		end
		for _, x in ipairs({-132, -120, 120, 132}) do
			makePart("Hedge", Vector3.new(9, 3.0, 2.2), Vector3.new(x, 1.5, 78), Color3.fromRGB(45, 88, 57), world, Enum.Material.Grass)
		end
		makePart("LuxuryGate", Vector3.new(18, 0.6, 1.2), Vector3.new(0, 3.0, 121), Color3.fromRGB(78, 81, 82), world, Enum.Material.Metal)
	elseif theme == "harbor" then
		for index, pos in ipairs({Vector3.new(-146, 0, -92), Vector3.new(-126, 0, -92), Vector3.new(115, 0, -96), Vector3.new(137, 0, -96)}) do
			makePart("CargoContainer" .. index, Vector3.new(14, 7, 6), pos + Vector3.new(0, 3.5, 0), index % 2 == 0 and Color3.fromRGB(70, 103, 116) or Color3.fromRGB(127, 72, 62), world, Enum.Material.Metal)
		end
		for _, pos in ipairs({Vector3.new(-180, 0, 164), Vector3.new(180, 0, 164)}) do
			makePart("HarborCranePost", Vector3.new(1.5, 18, 1.5), pos + Vector3.new(0, 9, 0), Color3.fromRGB(93, 100, 104), world, Enum.Material.Metal)
			makePart("HarborCraneArm", Vector3.new(14, 1.0, 1.0), pos + Vector3.new(6, 17, 0), Color3.fromRGB(93, 100, 104), world, Enum.Material.Metal)
		end
	elseif theme == "mountain" then
		for _, pos in ipairs({
			Vector3.new(-180, 0, -20), Vector3.new(-160, 0, 40), Vector3.new(-175, 0, 105),
			Vector3.new(180, 0, 5), Vector3.new(165, 0, 62), Vector3.new(176, 0, 120),
			Vector3.new(-90, 0, 150), Vector3.new(95, 0, 152)
		}) do
			createThemeTree(pos, worldRandom:NextNumber(0.9, 1.3), true)
		end
		for _, pos in ipairs({Vector3.new(-38, 0, 35), Vector3.new(40, 0, 92)}) do
			makePart("Rock", Vector3.new(5, 3, 4), pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(86, 88, 82), world, Enum.Material.Rock)
		end
	elseif theme == "danchi" then
		for _, x in ipairs({-150, -118, 118, 150}) do
			local block = makePart("DanchiBackground", Vector3.new(24, 24, 18), Vector3.new(x, 12, 72), Color3.fromRGB(160, 164, 160), world, Enum.Material.Concrete)
			for floor = 1, 4 do
				for _, dx in ipairs({-7, 0, 7}) do
					makePart("DanchiWindow", Vector3.new(2.8, 1.8, 0.18), Vector3.new(x + dx, 3 + (floor - 1) * 5.2, 62.9), Color3.fromRGB(221, 222, 199), world, Enum.Material.Neon)
				end
			end
		end
		makePart("PlaygroundSand", Vector3.new(30, 0.25, 24), Vector3.new(-150, 0.15, 15), Color3.fromRGB(135, 119, 90), world, Enum.Material.Sand)
		makePart("SlidePlatform", Vector3.new(5, 4, 5), Vector3.new(-150, 2, 15), Color3.fromRGB(91, 115, 129), world, Enum.Material.Metal)
	end
end

local function createWorld()
	world:SetAttribute("ThemeId", selectedWorldTheme.id)
	world:SetAttribute("ThemeName", selectedWorldTheme.name)
	world:SetAttribute("ThemeDecoration", selectedWorldTheme.decoration)
	world:SetAttribute("InitialWeather", selectedWorldTheme.initialWeatherId)
	print("Night Delivery world theme:", selectedWorldTheme.name)
	setupLighting()

	makePart(
		"Ground",
		Vector3.new(460, 1, 410),
		Vector3.new(0, -0.5, 20),
		selectedWorldTheme.groundColor,
		world,
		Enum.Material.Grass
	)

	makePart(
		"MainRoad",
		Vector3.new(34 * selectedWorldTheme.roadScale, 0.3, 260),
		Vector3.new(0, 0.15, 10),
		selectedWorldTheme.roadColor,
		world,
		Enum.Material.Pavement
	)

	makePart(
		"CrossRoad",
		Vector3.new(320, 0.3, 28 * selectedWorldTheme.roadScale),
		Vector3.new(0, 0.17, 20),
		selectedWorldTheme.roadColor,
		world,
		Enum.Material.Pavement
	)

	makePart(
		"NorthRoad",
		Vector3.new(240, 0.3, 24 * selectedWorldTheme.roadScale),
		Vector3.new(0, 0.17, 95),
		selectedWorldTheme.roadColor,
		world,
		Enum.Material.Pavement
	)

	makePart(
		"RiversideRoad",
		Vector3.new(360, 0.3, 24 * selectedWorldTheme.roadScale),
		Vector3.new(0, 0.17, 135),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Pavement
	)

	local canal = makePart(
		"Canal",
		Vector3.new(400, 0.5, 22),
		Vector3.new(0, 0.05, 182),
		selectedWorldTheme.canalColor,
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
		Vector3.new(360, 0.3, 24 * selectedWorldTheme.roadScale),
		Vector3.new(0, 0.17, -125),
		selectedWorldTheme.warehouseRoadColor,
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

	createThemeDressing()

	shopPadRef = shopPad
	jobCounterRef = depotPad
	bikePadRef = bikePad
	return depotPrompt, bikePrompt, shopPrompt, prompts
end

local function sendStatus(player, action, payload)
	deliveryEvent:FireClient(player, action, payload or {})
end

local function requirePlayerReady(player)
	if player:GetAttribute("NightDeliveryReady") == true then
		return true
	end
	sendStatus(player, "Message", {
		text = "プレイヤーデータを読み込み中。少し待ってから操作してね。",
	})
	return false
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
	if currentNightRule.id == "festival" and bikeActive then
		targetSpeed -= 2
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

	local function bikePart(name, size, offset, color, shape, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
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

	local function bikeBeam(name, fromOffset, toOffset, thickness, color)
		local midpoint = (fromOffset + toOffset) / 2
		local length = (toOffset - fromOffset).Magnitude
		local localFrame = CFrame.lookAt(midpoint, toOffset)
		return bikePart(
			name,
			Vector3.new(thickness, thickness, length),
			localFrame,
			color,
			nil,
			Enum.Material.Metal
		)
	end

	local frontAxle = Vector3.new(0, -2.02, -0.98)
	local rearAxle = Vector3.new(0, -2.02, 1.88)
	local crank = Vector3.new(0, -1.72, 0.44)
	local seatJoint = Vector3.new(0, -0.80, 0.56)
	local headJoint = Vector3.new(0, -0.77, -0.59)
	local frameColor = style.color
	local trimColor = Color3.fromRGB(190, 202, 210)
	local rubberColor = Color3.fromRGB(31, 34, 39)

	-- Narrow cylinders run along the bicycle's left-right axis, leaving both wheels upright.
	bikePart("FrontTire", Vector3.new(0.22, 2.02, 2.02), CFrame.new(frontAxle), rubberColor, Enum.PartType.Cylinder)
	bikePart("RearTire", Vector3.new(0.22, 2.02, 2.02), CFrame.new(rearAxle), rubberColor, Enum.PartType.Cylinder)

	for _, axle in ipairs({frontAxle, rearAxle}) do
		bikePart("WheelHubLeft", Vector3.new(0.16, 0.32, 0.32), CFrame.new(-0.17, axle.Y, axle.Z), trimColor, Enum.PartType.Cylinder)
		bikePart("WheelHubRight", Vector3.new(0.16, 0.32, 0.32), CFrame.new(0.17, axle.Y, axle.Z), trimColor, Enum.PartType.Cylinder)

		for _, side in ipairs({-0.12, 0.12}) do
			local center = Vector3.new(side, axle.Y, axle.Z)
			bikeBeam("WheelSpoke", center, center + Vector3.new(0, 0.76, 0), 0.035, trimColor)
			bikeBeam("WheelSpoke", center, center + Vector3.new(0, -0.76, 0), 0.035, trimColor)
		end
	end

	-- A clear triangular frame makes it read as a bicycle at a glance.
	bikeBeam("FrameTopTube", seatJoint, headJoint, 0.12, frameColor)
	bikeBeam("FrameDownTube", headJoint, crank, 0.14, frameColor)
	bikeBeam("FrameSeatTube", crank, seatJoint, 0.12, frameColor)
	bikeBeam("RearStayTop", seatJoint, rearAxle, 0.09, trimColor)
	bikeBeam("RearStayBottom", crank, rearAxle, 0.09, trimColor)
	bikeBeam("FrontFork", headJoint, frontAxle, 0.13, frameColor)

	-- Seat, steering stem, handlebars, pedals, and a small delivery crate finish the silhouette.
	bikeBeam("SeatPost", seatJoint, seatJoint + Vector3.new(0, 0.28, 0.02), 0.10, trimColor)
	bikePart("Saddle", Vector3.new(0.48, 0.10, 0.34), CFrame.new(0, -0.47, 0.58), rubberColor)
	bikeBeam("HandlebarStem", headJoint, Vector3.new(0, -0.28, -0.72), 0.10, trimColor)
	bikePart("Handlebar", Vector3.new(0.88, 0.10, 0.12), CFrame.new(0, -0.28, -0.72), rubberColor)
	bikePart("PedalAxle", Vector3.new(0.56, 0.12, 0.12), CFrame.new(crank), trimColor)
	bikePart("LeftPedal", Vector3.new(0.14, 0.10, 0.34), CFrame.new(-0.34, -1.72, 0.44), rubberColor)
	bikePart("RightPedal", Vector3.new(0.14, 0.10, 0.34), CFrame.new(0.34, -1.72, 0.44), rubberColor)

	bikeBeam("CargoRackLeft", Vector3.new(-0.38, -1.05, 1.05), Vector3.new(-0.38, -1.05, 2.15), 0.08, trimColor)
	bikeBeam("CargoRackRight", Vector3.new(0.38, -1.05, 1.05), Vector3.new(0.38, -1.05, 2.15), 0.08, trimColor)
	bikePart("DeliveryCrate", Vector3.new(0.90, 0.62, 0.82), CFrame.new(0, -0.72, 1.70), style.color, nil, Enum.Material.SmoothPlastic)
	bikePart("CrateLatch", Vector3.new(0.94, 0.07, 0.08), CFrame.new(0, -0.73, 1.27), trimColor, nil, Enum.Material.Metal)
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

local ROUTE_DISTANCE_FACTOR = 1.15
local JOB_TIME_PROFILES = {
	standard = {paceMultiplier = 1.75, setupSeconds = 5, minimum = 16, maximum = 40},
	express = {paceMultiplier = 1.25, setupSeconds = 4, minimum = 12, maximum = 28},
	long = {paceMultiplier = 3.1, setupSeconds = 7, minimum = 24, maximum = 72},
	special = {paceMultiplier = 1.65, setupSeconds = 5, minimum = 16, maximum = 38},
}

local ROUTE_CHOICES = {
	lantern = {title = "街灯の道", timeMultiplier = 1.35, reward = 0},
	shortcut = {title = "裏路地の近道", timeMultiplier = 0.78, reward = 80},
}

local function getDeliveryDistance(house)
	local depot = world:FindFirstChild("Depot")
	local counter = depot and depot:FindFirstChild("JobCounter")
	local deliveryPoint = house and house:FindFirstChild("DeliveryPoint")
	if not counter or not deliveryPoint then
		return 0
	end
	return (deliveryPoint.Position - counter.Position).Magnitude
end

local function getJobTimeLimit(jobType, house)
	local profile = JOB_TIME_PROFILES[jobType.id] or JOB_TIME_PROFILES.standard
	local estimatedWalkingTime = getDeliveryDistance(house) * ROUTE_DISTANCE_FACTOR / BASE_WALK_SPEED
	local seconds = estimatedWalkingTime * profile.paceMultiplier + profile.setupSeconds
	return math.clamp(math.ceil(seconds), profile.minimum, profile.maximum)
end

local function assignJob(player)
	if not requirePlayerReady(player) then
		return
	end
	if not isNearPart(player, jobCounterRef, 14) then
		return
	end
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

	local jobType = chooseJobType(player)
	local candidates = {}
	local fallbackCandidates = {}
	local lastHouse = playerLastHouse[player]

	for _, house in ipairs(houses) do
		if isHouseUnlocked(player, house) and (house.Name ~= lastHouse or #houses == 1) then
			table.insert(fallbackCandidates, house)
			local distance = getDeliveryDistance(house)
			local matchesRoute = jobType.id == "express" and distance <= 210
				or jobType.id == "long" and distance >= 185
				or jobType.id ~= "express" and jobType.id ~= "long"
			if matchesRoute then
				table.insert(candidates, house)
			end
		end
	end

	if #candidates == 0 then
		candidates = fallbackCandidates
	end
	if #candidates == 0 then
		return
	end

	local target = candidates[math.random(1, #candidates)]
	local destinationEvent = nil
	if math.random() <= RULES.DestinationEventChance then
		destinationEvent = RULES.chooseWeighted(RULES.DestinationEvents, playerLastDestinationEvent[player])
		playerLastDestinationEvent[player] = destinationEvent.id
	end
	local isAnomaly = math.random() <= RULES.RareAnomalyChance
	local districtId = target:GetAttribute("DistrictId") or "central"
	local districtName = target:GetAttribute("DistrictName") or DISTRICT_NAMES[districtId] or districtId
	local weather = currentWeather
	local baseTimeLimit = getJobTimeLimit(jobType, target)
	local jobSerial = (player:GetAttribute("NightDeliveryJobSerial") or 0) + 1

	player:SetAttribute("NightDeliveryTimeLimit", nil)
	player:SetAttribute("NightDeliveryOrderStartedAt", nil)
	player:SetAttribute("NightDeliveryJobSerial", jobSerial)
	player:SetAttribute("NightDeliveryJobType", jobType.id)
	player:SetAttribute("NightDeliveryHouseName", target.Name)
	playerJobs[player] = {
		jobSerial = jobSerial,
		houseName = target.Name,
		displayName = target:GetAttribute("DisplayName") or target.Name,
		districtId = districtId,
		districtName = districtName,
		jobTypeId = jobType.id,
		weatherId = weather.id,
		weatherName = weather.name,
		weatherMultiplier = weather.rewardMultiplier,
		baseTimeLimit = baseTimeLimit,
		bagCapacity = math.clamp(1 + (player:GetAttribute("BagStyleLevel") or 0), 1, 3),
		extraStops = {},
		residentName = target:GetAttribute("ResidentName") or "住人",
		residentFirstLine = target:GetAttribute("ResidentFirstLine") or "配達ありがとう。",
		residentReturnLine = target:GetAttribute("ResidentReturnLine") or "今夜もありがとう。",
		routeChoice = nil,
		routeReward = 0,
		destinationEvent = destinationEvent,
		destinationEventPrompted = false,
		destinationEventReward = 0,
		isAnomaly = isAnomaly,
	}

	player:SetAttribute("NightDeliveryBikeBlocked", false)
	if isAnomaly then
		sendStatus(player, "RareAnomaly", {title = "宛名が一瞬、読めなくなった"})
	end
	playerLastHouse[player] = target.Name
	addParcelVisual(player, jobType.id)

	sendStatus(player, "JobAssigned", {
		houseName = target.Name,
		jobSerial = jobSerial,
		displayName = target:GetAttribute("DisplayName") or target.Name,
		districtId = districtId,
		districtName = districtName,
		jobTypeId = jobType.id,
		jobTypeName = jobType.name,
		weatherId = weather.id,
		weatherName = weather.name,
		weatherMultiplier = weather.rewardMultiplier,
		baseTimeLimit = baseTimeLimit,
		baseReward = jobType.baseReward,
		bagCapacity = playerJobs[player].bagCapacity,
		nightCondition = currentNightRule.name,
	})
end

local function completeDelivery(player, houseName)
	if not requirePlayerReady(player) then
		return
	end
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
	if not job.routeChoice or not job.expiresAt then
		sendStatus(player, "Message", {
			text = "先に配達ルートを選ぼう。",
		})
		return
	end

	local targetHouse = housesFolder:FindFirstChild(job.houseName)
	local deliveryPoint = targetHouse and targetHouse:FindFirstChild("DeliveryPoint")
	if not isNearPart(player, deliveryPoint, 13) then
		return
	end

	if job.destinationEvent and not job.destinationEventChoice then
		if not job.destinationEventPrompted then
			job.destinationEventPrompted = true
			sendStatus(player, "DestinationEvent", {
				jobSerial = job.jobSerial,
				id = job.destinationEvent.id,
				title = job.destinationEvent.title,
				body = job.destinationEvent.body,
				quickLabel = job.destinationEvent.quickLabel,
				carefulLabel = job.destinationEvent.carefulLabel,
			})
		end
		return
	end

	local visits = playerResidentVisits[player] or {}
	playerResidentVisits[player] = visits
	local visitCount = visits[job.houseName] or 0
	visits[job.houseName] = visitCount + 1
	local residentReaction = visitCount == 0 and job.residentFirstLine or job.residentReturnLine

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
	local routeBonus = job.routeChoice == "shortcut" and remaining > 0 and (job.routeReward or 0) or 0
	reward += routeBonus
	local destinationEventBonus = job.destinationEventReward or 0
	local sideRequestBonus = job.currentStopBonus or 0
	reward += sideRequestBonus
	if currentNightRule.id == "festival" then
		reward = math.floor(reward * 1.1)
	end

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
	reward += coopBonus + destinationEventBonus

	-- A small chance of a grateful resident tipping the courier keeps ordinary jobs surprising.
	local tipChance = currentNightRule.id == "tip" and 30 or 14
	local neighborhoodTip = 0
	if math.random(1, 100) <= tipChance then
		neighborhoodTip = math.random(40, 90) + (currentNightRule.id == "tip" and 40 or 0)
		reward += neighborhoodTip
	end

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
	local rumorUnlocked = nil
	if stats and stats.coins and stats.deliveries then
		stats.coins.Value += reward
		stats.deliveries.Value += 1
		deliveriesAfter = stats.deliveries.Value
		player:SetAttribute("NightDeliveryCompletedJobSerial", job.jobSerial)

		local clueLevel = player:GetAttribute("NightDeliveryRumorClueLevel") or 0
		local nextClue = RUMOR_CLUES[clueLevel + 1]
		if nextClue and deliveriesAfter >= nextClue.deliveries then
			clueLevel += 1
			player:SetAttribute("NightDeliveryRumorClueLevel", clueLevel)
			if nextClue.reward > 0 then
				stats.coins.Value += nextClue.reward
			end
			rumorUnlocked = {
				chapter = clueLevel,
				total = #RUMOR_CLUES,
				title = nextClue.title,
				text = nextClue.text,
				reward = nextClue.reward,
			}
		end
	end

	local districtUnlocked = deliveriesAfter == RIVERSIDE_UNLOCK_DELIVERIES
	local specialJobsUnlocked = deliveriesAfter == SPECIAL_JOB_UNLOCK_DELIVERIES
	local warehouseUnlocked = deliveriesAfter == WAREHOUSE_UNLOCK_DELIVERIES

	local hasNextStops = type(job.extraStops) == "table" and #job.extraStops > 0
	if hasNextStops then
		job.houseName = nil
	end
	if not hasNextStops then
		playerJobs[player] = nil
	end
	player:SetAttribute("NightDeliveryTimeLimit", nil)
	player:SetAttribute("NightDeliveryOrderStartedAt", nil)
	player:SetAttribute("NightDeliveryJobType", nil)
	player:SetAttribute("NightDeliveryHouseName", nil)
	player:SetAttribute("NightDeliveryBikeBlocked", false)
	clearParcelVisual(player)

	sendStatus(player, "Delivered", {
		houseName = houseName,
		displayName = job.displayName,
		residentName = job.residentName,
		residentReaction = residentReaction,
		reward = reward,
		timeRemaining = remaining,
		streak = streak,
		streakBonus = streakBonus,
		routeTitle = job.routeTitle,
		routeBonus = routeBonus,
		destinationEventBonus = destinationEventBonus,
		sideRequestBonus = sideRequestBonus,
		destinationEventId = job.destinationEvent and job.destinationEvent.id or nil,
		isAnomaly = job.isAnomaly == true,
		weatherName = job.weatherName or "晴れ",
		weatherBonus = weatherBonus,
		coopBonus = coopBonus,
		neighborhoodTip = neighborhoodTip,
		helperCount = helperCount,
		shiftBonus = shiftBonus,
		shiftProgress = playerShiftProgress[player] or 0,
		shiftTarget = SHIFT_TARGET,
		rankName = getRankName(deliveriesAfter or 0),
		districtUnlocked = districtUnlocked,
		specialJobsUnlocked = specialJobsUnlocked,
		warehouseUnlocked = warehouseUnlocked,
		hasNextStops = hasNextStops,
	})
	if hasNextStops then
		local options = {}
		for _, stop in ipairs(job.extraStops) do
			local house = housesFolder:FindFirstChild(stop.houseName)
			local point = house and house:FindFirstChild("DeliveryPoint")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			table.insert(options, {
				houseName = stop.houseName,
				displayName = stop.displayName,
				distance = root and point and math.floor((root.Position - point.Position).Magnitude) or 0,
				reward = stop.reward or 0,
			})
		end
		sendStatus(player, "NextStopOptions", {
			jobSerial = job.jobSerial,
			stops = options,
			bagCapacity = job.bagCapacity,
		})
	end
	if job.isAnomaly then
		sendStatus(player, "RareAnomaly", {title = "配達済みの家から、もう一度お礼が聞こえた"})
	end
	if rumorUnlocked then
		sendStatus(player, "RumorUnlocked", rumorUnlocked)
	end
end

local function sendSideRequestOffer(player, jobSerial)
	local job = playerJobs[player]
	if not job or job.jobSerial ~= jobSerial or not job.houseName
		or job.sideOffer or #job.extraStops >= (job.bagCapacity - 1)
		or math.random() > 0.38 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local used = {[job.houseName] = true}
	for _, stop in ipairs(job.extraStops) do used[stop.houseName] = true end
	local candidates = {}
	for _, house in ipairs(housesFolder:GetChildren()) do
		local point = house:FindFirstChild("DeliveryPoint")
		if point and isHouseUnlocked(player, house) and not used[house.Name] then
			local distance = (root.Position - point.Position).Magnitude
			if distance <= 220 then
				table.insert(candidates, {house = house, distance = distance})
			end
		end
	end
	if #candidates == 0 then
		return
	end
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local shortlist = {}
	for index = 1, math.min(3, #candidates) do
		table.insert(shortlist, candidates[index])
	end
	local chosen = shortlist[math.random(1, #shortlist)]
	local expiresAt = os.clock() + 35
	job.sideOffer = {houseName = chosen.house.Name, expiresAt = expiresAt, reward = 180}
	sendStatus(player, "SideJobOffer", {
		jobSerial = job.jobSerial,
		houseName = chosen.house.Name,
		displayName = chosen.house:GetAttribute("DisplayName") or chosen.house.Name,
		distance = math.floor(chosen.distance),
		reward = 180,
		expiresIn = 35,
		cargoType = "追加の通常便",
	})
end

local function startNextStop(player, job, stopIndex)
	local stop = job.extraStops[stopIndex]
	if not stop then return end
	table.remove(job.extraStops, stopIndex)
	local target = housesFolder:FindFirstChild(stop.houseName)
	if not target then return end

	job.jobSerial = (player:GetAttribute("NightDeliveryJobSerial") or 0) + 1
	job.houseName = target.Name
	job.displayName = target:GetAttribute("DisplayName") or target.Name
	job.residentName = target:GetAttribute("ResidentName") or "住人"
	job.residentFirstLine = target:GetAttribute("ResidentFirstLine") or "配達ありがとう。"
	job.residentReturnLine = target:GetAttribute("ResidentReturnLine") or "今夜もありがとう。"
	job.weatherId = currentWeather.id
	job.weatherName = currentWeather.name
	job.weatherMultiplier = currentWeather.rewardMultiplier
	job.currentStopBonus = stop.reward or 0
	job.destinationEventChoice = nil
	job.destinationEventPrompted = false
	job.destinationEventReward = 0
	job.routeReward = 0
	job.routeTitle = nil
	job.isAnomaly = math.random() <= RULES.RareAnomalyChance
	job.isSideRequest = true
	job.baseTimeLimit = getJobTimeLimit(findJobType(job.jobTypeId), target)
	job.routeChoice = nil
	job.expiresAt = nil
	job.startedAt = nil
	job.destinationEvent = math.random() <= RULES.DestinationEventChance
		and RULES.chooseWeighted(RULES.DestinationEvents, playerLastDestinationEvent[player]) or nil
	if job.destinationEvent then playerLastDestinationEvent[player] = job.destinationEvent.id end
	player:SetAttribute("NightDeliveryJobSerial", job.jobSerial)
	player:SetAttribute("NightDeliveryTimeLimit", nil)
	player:SetAttribute("NightDeliveryOrderStartedAt", nil)
	player:SetAttribute("NightDeliveryJobType", job.jobTypeId)
	player:SetAttribute("NightDeliveryHouseName", target.Name)
	player:SetAttribute("NightDeliveryBikeBlocked", false)
	addParcelVisual(player, job.jobTypeId)
	sendStatus(player, "JobAssigned", {
		houseName = target.Name,
		jobSerial = job.jobSerial,
		displayName = job.displayName,
		districtId = target:GetAttribute("DistrictId") or "central",
		districtName = target:GetAttribute("DistrictName") or "住宅街",
		jobTypeId = job.jobTypeId,
		jobTypeName = "追加依頼",
		weatherId = currentWeather.id,
		weatherName = currentWeather.name,
		weatherMultiplier = currentWeather.rewardMultiplier,
		baseTimeLimit = job.baseTimeLimit,
		baseReward = findJobType(job.jobTypeId).baseReward + job.currentStopBonus,
		sideRequest = true,
	})
end

local function toggleBike(player)
	if not requirePlayerReady(player) then
		return
	end
	if not isNearPart(player, bikePadRef, 14) then
		return
	end
	if player:GetAttribute("NightDeliveryBikeBlocked") == true then
		sendStatus(player, "Message", {text = "大型荷物を運んでいる間は自転車に乗れないよ。"})
		return
	end
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
	if not requirePlayerReady(player) then
		return
	end
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
		rumorClueLevel = 0,
	}
	if not DELIVERY_STORE then
		return defaultData, false
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
		defaultData.rumorClueLevel = math.clamp(tonumber(data.rumorClueLevel) or 0, 0, #RUMOR_CLUES)
	elseif not success then
		warn("Night Delivery: DataStore load failed after retries for", player.Name)
	end

	local dataCanBeSaved = success and (data == nil or type(data) == "table")
	if success and data ~= nil and type(data) ~= "table" then
		warn("Night Delivery: invalid saved data; refusing to overwrite it for", player.Name)
	end

	return defaultData, dataCanBeSaved
end

local function saveData(player)
	if not DELIVERY_STORE then
		return false
	end
	if playerDataLoadSucceeded[player] ~= true then
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
		rumorClueLevel = player:GetAttribute("NightDeliveryRumorClueLevel") or 0,
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
	if not requirePlayerReady(player) then
		return
	end
	if not isNearPart(player, shopPadRef, 16) then
		return
	end
	sendShopState(player)
	sendStatus(player, "ShopOpened", {})
end

local function buyNextStyle(player, kind)
	if not requirePlayerReady(player) then
		return
	end
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

	if currentNightRule.id == "fog" then
		Lighting.FogEnd = math.min(Lighting.FogEnd, 390)
	elseif currentNightRule.id == "blackout" then
		Lighting.Brightness = math.max(0.65, Lighting.Brightness * 0.72)
		Lighting.FogEnd = math.min(Lighting.FogEnd, 430)
	elseif currentNightRule.id == "festival" then
		Lighting.Ambient = Color3.fromRGB(91, 77, 78)
	end

	deliveryEvent:FireAllClients("NightConditionChanged", {
		id = currentNightRule.id,
		name = currentNightRule.name,
		description = currentNightRule.description,
	})
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

deliveryEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then
		return
	end

	local now = os.clock()
	local lastAction = remoteLastAction[player] or 0
	local immediateActions = {
		ChooseRoute = true,
		ResolveDestinationEvent = true,
		AcceptSideJob = true,
		IgnoreSideJob = true,
		ChooseNextStop = true,
	}
	if not immediateActions[action] and now - lastAction < REMOTE_COOLDOWN_SECONDS then
		return
	end
	remoteLastAction[player] = now

	if action == "AcceptSideJob" or action == "IgnoreSideJob" then
		local job = playerJobs[player]
		if not job or type(payload) ~= "table"
			or tonumber(payload.jobSerial) ~= job.jobSerial
			or not job.sideOffer or os.clock() > job.sideOffer.expiresAt then
			return
		end
		if action == "IgnoreSideJob" then
			job.sideOffer = nil
			sendStatus(player, "Message", {text = "追加依頼を見送った。今の配達を続けよう。"})
			return
		end
		if #job.extraStops >= (job.bagCapacity - 1)
			or tostring(payload.houseName or "") ~= job.sideOffer.houseName then
			return
		end
		local sideHouse = housesFolder:FindFirstChild(job.sideOffer.houseName)
		if not sideHouse or not isHouseUnlocked(player, sideHouse) then
			job.sideOffer = nil
			return
		end
		table.insert(job.extraStops, {
			houseName = sideHouse.Name,
			displayName = sideHouse:GetAttribute("DisplayName") or sideHouse.Name,
			reward = job.sideOffer.reward,
		})
		job.sideOffer = nil
		sendStatus(player, "SideJobAccepted", {
			displayName = sideHouse:GetAttribute("DisplayName") or sideHouse.Name,
			reward = 180,
			queuedStops = #job.extraStops,
			bagCapacity = job.bagCapacity,
		})
		if #job.extraStops < (job.bagCapacity - 1) then
			local jobSerial = job.jobSerial
			task.delay(5, function()
				local currentJob = playerJobs[player]
				if currentJob and currentJob.jobSerial == jobSerial and currentJob.houseName then
					sendSideRequestOffer(player, jobSerial)
				end
			end)
		end
	elseif action == "ChooseNextStop" then
		local job = playerJobs[player]
		if not job or job.houseName or type(payload) ~= "table"
			or tonumber(payload.jobSerial) ~= job.jobSerial then
			return
		end
		local houseName = tostring(payload.houseName or "")
		for index, stop in ipairs(job.extraStops) do
			if stop.houseName == houseName then
				startNextStop(player, job, index)
				return
			end
		end
	elseif action == "ResolveDestinationEvent" then
		local job = playerJobs[player]
		if not requirePlayerReady(player)
			or not job
			or not job.destinationEvent
			or job.destinationEventChoice
			or type(payload) ~= "table"
			or tonumber(payload.jobSerial) ~= job.jobSerial then
			return
		end
		local house = housesFolder:FindFirstChild(job.houseName)
		local point = house and house:FindFirstChild("DeliveryPoint")
		if not isNearPart(player, point, 13) then
			return
		end
		local choice = tostring(payload.choice or "")
		if choice ~= "quick" and choice ~= "careful" then
			return
		end
		job.destinationEventChoice = choice
		job.destinationEventReward = choice == "careful" and job.destinationEvent.carefulBonus or job.destinationEvent.quickBonus
		completeDelivery(player, job.houseName)
	elseif action == "ChooseRoute" then
		local job = playerJobs[player]
		local routeId = type(payload) == "table" and tostring(payload.routeId or "") or ""
		local route = ROUTE_CHOICES[routeId]
		if not requirePlayerReady(player)
			or not job
			or job.routeChoice
			or not route
			or type(payload) ~= "table"
			or tonumber(payload.jobSerial) ~= job.jobSerial then
			return
		end

		job.routeChoice = routeId
		job.routeTitle = route.title
		job.routeReward = route.reward
		job.timeLimit = math.clamp(math.ceil(job.baseTimeLimit * route.timeMultiplier), 10, 90)
		job.startedAt = os.clock()
		job.expiresAt = workspace:GetServerTimeNow() + job.timeLimit
		if currentNightRule.id == "roadwork" and routeId == "shortcut" then
			job.routeReward += 40
		end
		player:SetAttribute("NightDeliveryTimeLimit", job.timeLimit)
		player:SetAttribute("NightDeliveryOrderStartedAt", job.startedAt)
		sendStatus(player, "JobRouteChosen", {
			jobSerial = job.jobSerial,
			routeId = routeId,
			routeTitle = route.title,
			timeLimit = job.timeLimit,
			expiresAt = job.expiresAt,
			reward = job.routeReward,
		})
		local jobSerial = job.jobSerial
		task.delay(8, function()
			local currentJob = playerJobs[player]
			if currentJob and currentJob.jobSerial == jobSerial and currentJob.houseName then
				sendSideRequestOffer(player, jobSerial)
			end
		end)
	elseif action == "RequestState" then
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
		if requirePlayerReady(player) and isNearPart(player, shopPadRef, 18) then
			sendShopState(player)
		end
	end
end)

currentNightRule = RULES.chooseWeighted(RULES.NightConditions)
world:SetAttribute("NightConditionId", currentNightRule.id)
applyWeather(currentWeather)
startWeatherLoop()

task.spawn(function()
	while true do
		task.wait(240)
		currentNightRule = RULES.chooseWeighted(RULES.NightConditions, currentNightRule.id)
		world:SetAttribute("NightConditionId", currentNightRule.id)
		applyWeather(currentWeather)
	end
end)

for _, entry in ipairs(housePrompts) do
	entry.prompt.Triggered:Connect(function(player)
		completeDelivery(player, entry.houseName)
	end)
end

local function setupPlayer(player)
	player:SetAttribute("NightDeliveryReady", false)
	local data, dataCanBeSaved = loadData(player)
	if not player.Parent then
		return
	end
	playerDataLoadSucceeded[player] = dataCanBeSaved == true

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
	player:SetAttribute("NightDeliveryTimeLimit", nil)
	player:SetAttribute("NightDeliveryOrderStartedAt", nil)
	player:SetAttribute("NightDeliveryJobSerial", 0)
	player:SetAttribute("NightDeliveryCompletedJobSerial", 0)
	player:SetAttribute("NightDeliveryJobType", nil)
	player:SetAttribute("NightDeliveryHouseName", nil)
	player:SetAttribute("NightDeliveryBikeBlocked", false)
	player:SetAttribute("BagStyleLevel", data.bagStyleLevel)
	player:SetAttribute("BikeStyleLevel", data.bikeStyleLevel)
	player:SetAttribute("ShiftWins", data.shiftWins)
	player:SetAttribute("NightDeliveryRumorClueLevel", data.rumorClueLevel)
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
	if DELIVERY_STORE and not dataCanBeSaved then
		sendStatus(player, "Message", {
			text = "セーブデータを確認できませんでした。このセッションの進行は保存されません。",
		})
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerJobs[player] = nil
	playerLastHouse[player] = nil
	playerResidentVisits[player] = nil
	playerLastDestinationEvent[player] = nil
	playerStreak[player] = nil
	playerShiftProgress[player] = nil
	remoteLastAction[player] = nil
	playerDataLoadSucceeded[player] = nil
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