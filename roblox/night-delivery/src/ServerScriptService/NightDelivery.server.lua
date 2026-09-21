-- Night Delivery v3
-- ServerScriptService/NightDelivery.server.lua
-- Self-contained prototype: generates the town, runs delivery jobs,
-- saves progression, unlocks a second district, and adds rare veteran jobs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")

local REMOTE_NAME = "NightDeliveryEvent"
local WORLD_NAME = "NightDeliveryWorld"
local DATASTORE_NAME = "NightDeliveryPlayerData_v2"

local BASE_WALK_SPEED = 20
local BIKE_BONUS_SPEED = 10
local SPEED_PER_LEVEL = 2
local MAX_SPEED_LEVEL = 5
local RIVERSIDE_UNLOCK_DELIVERIES = 5
local SPECIAL_JOB_UNLOCK_DELIVERIES = 8

local DISTRICT_NAMES = {
	central = "住宅街",
	riverside = "川沿い地区",
}

local DELIVERY_STORE = DataStoreService:GetDataStore(DATASTORE_NAME)

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

local deliveryEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not deliveryEvent then
	deliveryEvent = Instance.new("RemoteEvent")
	deliveryEvent.Name = REMOTE_NAME
	deliveryEvent.Parent = ReplicatedStorage
end

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

local function createHouse(id, displayName, districtId, position, bodyColor)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("DistrictId", districtId)
	model:SetAttribute("DistrictName", DISTRICT_NAMES[districtId] or districtId)
	model.Parent = housesFolder

	local body = makePart(
		"Body",
		Vector3.new(18, 12, 16),
		position + Vector3.new(0, 6, 0),
		bodyColor,
		model
	)

	makePart(
		"Roof",
		Vector3.new(20, 2, 18),
		position + Vector3.new(0, 13, 0),
		Color3.fromRGB(52, 56, 68),
		model,
		Enum.Material.Slate
	)

	makePart(
		"Door",
		Vector3.new(4, 7, 0.6),
		position + Vector3.new(0, 3.5, -8.3),
		Color3.fromRGB(112, 73, 48),
		model
	)

	local porch = makePart(
		"DeliveryPoint",
		Vector3.new(5.5, 0.5, 4),
		position + Vector3.new(0, 0.25, -11),
		Color3.fromRGB(76, 88, 96),
		model,
		Enum.Material.Concrete
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeliverPrompt"
	prompt.ActionText = "配達する"
	prompt.ObjectText = displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = porch

	local windowOffsets = {
		Vector3.new(-5, 7, -8.35),
		Vector3.new(5, 7, -8.35),
	}

	for index, offset in ipairs(windowOffsets) do
		local window = makePart(
			"Window" .. index,
			Vector3.new(3.4, 3.4, 0.3),
			position + offset,
			Color3.fromRGB(255, 221, 145),
			model,
			Enum.Material.Neon
		)

		local light = Instance.new("PointLight")
		light.Brightness = 0.5
		light.Range = 11
		light.Color = Color3.fromRGB(255, 222, 160)
		light.Parent = window
	end

	model.PrimaryPart = body
	return model, prompt
end

local function createWorld()
	setupLighting()

	makePart(
		"Ground",
		Vector3.new(420, 1, 380),
		Vector3.new(0, -0.5, 35),
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
	bikePrompt.HoldDuration = 0.2
	bikePrompt.MaxActivationDistance = 12
	bikePrompt.RequiresLineOfSight = false
	bikePrompt.Parent = bikePad

	local shopPad = makePart(
		"SpeedShop",
		Vector3.new(8, 0.7, 6),
		Vector3.new(-70, 0.35, -88),
		Color3.fromRGB(147, 108, 208),
		depot,
		Enum.Material.Neon
	)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "SpeedUpgradePrompt"
	shopPrompt.ActionText = "速度を強化"
	shopPrompt.ObjectText = "自転車ショップ"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.U
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
		parcel.Color = Color3.fromRGB(176, 132, 82)
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
	local now = workspace:GetServerTimeNow()
	local expiresAt = now + jobType.timeLimit

	playerJobs[player] = {
		houseName = target.Name,
		displayName = target:GetAttribute("DisplayName") or target.Name,
		districtId = districtId,
		districtName = districtName,
		jobTypeId = jobType.id,
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
	local reward = jobType.baseReward + (remaining * jobType.timeBonusPerSecond) + streakBonus

	local stats = getStats(player)
	local deliveriesAfter = nil
	if stats and stats.coins and stats.deliveries then
		stats.coins.Value += reward
		stats.deliveries.Value += 1
		deliveriesAfter = stats.deliveries.Value
	end

	if deliveriesAfter == RIVERSIDE_UNLOCK_DELIVERIES then
		sendStatus(player, "DistrictUnlocked", {
			districtId = "riverside",
			districtName = DISTRICT_NAMES.riverside,
		})
	end

	if deliveriesAfter == SPECIAL_JOB_UNLOCK_DELIVERIES then
		sendStatus(player, "SpecialJobsUnlocked", {
			jobTypeName = "深夜特別便",
		})
	end

	playerJobs[player] = nil
	clearParcelVisual(player)

	sendStatus(player, "Delivered", {
		houseName = houseName,
		displayName = job.displayName,
		reward = reward,
		timeRemaining = remaining,
		streak = streak,
		streakBonus = streakBonus,
	})
end

local function toggleBike(player)
	local active = not (player:GetAttribute("BikeActive") == true)
	player:SetAttribute("BikeActive", active)
	applyMovementSpeed(player)

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
	}

	local success, data = pcall(function()
		return DELIVERY_STORE:GetAsync("player_" .. player.UserId)
	end)

	if success and type(data) == "table" then
		defaultData.coins = tonumber(data.coins) or 0
		defaultData.deliveries = tonumber(data.deliveries) or 0
		defaultData.speedLevel = math.clamp(tonumber(data.speedLevel) or 0, 0, MAX_SPEED_LEVEL)
	elseif not success then
		warn("Night Delivery: DataStore load failed for", player.Name, data)
	end

	return defaultData
end

local function saveData(player)
	local stats = getStats(player)
	if not stats or not stats.coins or not stats.deliveries then
		return
	end

	local payload = {
		coins = stats.coins.Value,
		deliveries = stats.deliveries.Value,
		speedLevel = player:GetAttribute("SpeedLevel") or 0,
	}

	local success, err = pcall(function()
		DELIVERY_STORE:SetAsync("player_" .. player.UserId, payload)
	end)

	if not success then
		warn("Night Delivery: DataStore save failed for", player.Name, err)
	end
end

local depotPrompt, bikePrompt, shopPrompt, housePrompts = createWorld()

depotPrompt.Triggered:Connect(assignJob)
bikePrompt.Triggered:Connect(toggleBike)
shopPrompt.Triggered:Connect(tryUpgradeSpeed)

for _, entry in ipairs(housePrompts) do
	entry.prompt.Triggered:Connect(function(player)
		completeDelivery(player, entry.houseName)
	end)
end

local function setupPlayer(player)
	local data = loadData(player)

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
	playerStreak[player] = 0

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.wait(0.2)
			applyMovementSpeed(player)
		end

		task.wait(0.2)
		if playerJobs[player] then
			addParcelVisual(player, playerJobs[player].jobTypeId)
		end
	end)

	sendStatus(player, "Welcome", {
		speedLevel = data.speedLevel,
		deliveries = data.deliveries,
		riversideUnlockAt = RIVERSIDE_UNLOCK_DELIVERIES,
		specialJobUnlockAt = SPECIAL_JOB_UNLOCK_DELIVERIES,
		riversideUnlocked = data.deliveries >= RIVERSIDE_UNLOCK_DELIVERIES,
		specialJobsUnlocked = data.deliveries >= SPECIAL_JOB_UNLOCK_DELIVERIES,
		nextUpgradeCost = data.speedLevel < MAX_SPEED_LEVEL and getSpeedUpgradeCost(data.speedLevel) or 0,
	})
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
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
	task.wait(1)
end)
