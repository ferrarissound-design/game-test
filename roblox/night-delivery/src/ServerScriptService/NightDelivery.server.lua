-- Night Delivery prototype
-- Put this Script in ServerScriptService if you are not using Rojo.
-- It creates a small night town, a depot, five delivery houses,
-- and the core loop: accept job -> deliver -> earn coins -> repeat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local ROUND_TIME = 60
local BASE_REWARD = 50
local TIME_BONUS_PER_SECOND = 2

local REMOTE_NAME = "NightDeliveryEvent"
local WORLD_NAME = "NightDeliveryWorld"

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

local function setupLighting()
	Lighting.ClockTime = 22.2
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(70, 76, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(45, 50, 72)
	Lighting.FogColor = Color3.fromRGB(35, 40, 58)
	Lighting.FogEnd = 650

	if not Lighting:FindFirstChild("NightDeliveryAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "NightDeliveryAtmosphere"
		atmosphere.Density = 0.22
		atmosphere.Haze = 1.2
		atmosphere.Color = Color3.fromRGB(150, 165, 210)
		atmosphere.Decay = Color3.fromRGB(75, 80, 110)
		atmosphere.Parent = Lighting
	end
end

local function createStreetLight(position)
	local pole = makePart(
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

	return pole, lamp
end

local function createHouse(id, position, bodyColor)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("HouseId", id)
	model.Parent = housesFolder

	local body = makePart(
		"Body",
		Vector3.new(18, 12, 16),
		position + Vector3.new(0, 6, 0),
		bodyColor,
		model
	)

	local roof = makePart(
		"Roof",
		Vector3.new(20, 2, 18),
		position + Vector3.new(0, 13, 0),
		Color3.fromRGB(52, 56, 68),
		model,
		Enum.Material.Slate
	)

	local door = makePart(
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
	prompt.ObjectText = id
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
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
		light.Brightness = 0.55
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
		Vector3.new(280, 1, 220),
		Vector3.new(0, -0.5, 10),
		Color3.fromRGB(48, 62, 58),
		world,
		Enum.Material.Grass
	)

	makePart(
		"MainRoad",
		Vector3.new(34, 0.3, 220),
		Vector3.new(0, 0.15, 10),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Asphalt
	)

	makePart(
		"CrossRoad",
		Vector3.new(280, 0.3, 28),
		Vector3.new(0, 0.17, 20),
		Color3.fromRGB(45, 47, 52),
		world,
		Enum.Material.Asphalt
	)

	for z = -80, 100, 30 do
		createStreetLight(Vector3.new(-21, 0, z))
		createStreetLight(Vector3.new(21, 0, z))
	end

	local depot = Instance.new("Model")
	depot.Name = "Depot"
	depot.Parent = world

	makePart(
		"DepotBuilding",
		Vector3.new(24, 10, 18),
		Vector3.new(-72, 5, -55),
		Color3.fromRGB(52, 77, 93),
		depot
	)

	local depotPad = makePart(
		"JobCounter",
		Vector3.new(9, 1, 7),
		Vector3.new(-72, 0.5, -68),
		Color3.fromRGB(240, 186, 86),
		depot,
		Enum.Material.Neon
	)

	local depotPrompt = Instance.new("ProximityPrompt")
	depotPrompt.Name = "AcceptJobPrompt"
	depotPrompt.ActionText = "配達を受ける"
	depotPrompt.ObjectText = "夜間配達所"
	depotPrompt.KeyboardKeyCode = Enum.KeyCode.E
	depotPrompt.HoldDuration = 0.35
	depotPrompt.MaxActivationDistance = 12
	depotPrompt.RequiresLineOfSight = false
	depotPrompt.Parent = depotPad

	local sign = makePart(
		"DepotSign",
		Vector3.new(12, 3, 0.6),
		Vector3.new(-72, 9, -64),
		Color3.fromRGB(102, 184, 225),
		depot,
		Enum.Material.Neon
	)

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "NIGHT DELIVERY"
	signText.TextScaled = true
	signText.TextColor3 = Color3.fromRGB(245, 250, 255)
	signText.Font = Enum.Font.GothamBold
	signText.Parent = signGui

	local houseDefinitions = {
		{name = "Blue House", position = Vector3.new(-70, 0, 48), color = Color3.fromRGB(74, 111, 154)},
		{name = "Red House", position = Vector3.new(70, 0, 60), color = Color3.fromRGB(146, 76, 72)},
		{name = "Green House", position = Vector3.new(-74, 0, 96), color = Color3.fromRGB(77, 124, 94)},
		{name = "Yellow House", position = Vector3.new(74, 0, -8), color = Color3.fromRGB(151, 127, 69)},
		{name = "Purple House", position = Vector3.new(72, 0, -68), color = Color3.fromRGB(111, 81, 137)},
	}

	local prompts = {}

	for _, definition in ipairs(houseDefinitions) do
		local _, prompt = createHouse(definition.name, definition.position, definition.color)
		table.insert(prompts, {
			houseName = definition.name,
			prompt = prompt,
		})
	end

	return depotPrompt, prompts
end

local function getCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	return leaderstats:FindFirstChild("Coins")
end

local function sendStatus(player, action, payload)
	deliveryEvent:FireClient(player, action, payload)
end

local function assignJob(player)
	local houses = housesFolder:GetChildren()
	if #houses == 0 then
		return
	end

	local current = playerJobs[player]
	local candidates = {}

	for _, house in ipairs(houses) do
		if not current or house.Name ~= current.houseName or #houses == 1 then
			table.insert(candidates, house)
		end
	end

	local target = candidates[math.random(1, #candidates)]
	local expiresAt = workspace:GetServerTimeNow() + ROUND_TIME

	playerJobs[player] = {
		houseName = target.Name,
		expiresAt = expiresAt,
		startedAt = workspace:GetServerTimeNow(),
	}

	sendStatus(player, "JobAssigned", {
		houseName = target.Name,
		expiresAt = expiresAt,
		roundTime = ROUND_TIME,
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
			text = "ここじゃない。配達先を確認しよう。",
		})
		return
	end

	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, math.floor(job.expiresAt - now))
	local reward = BASE_REWARD + (remaining * TIME_BONUS_PER_SECOND)

	local coins = getCoins(player)
	if coins then
		coins.Value += reward
	end

	playerJobs[player] = nil

	sendStatus(player, "Delivered", {
		houseName = houseName,
		reward = reward,
		timeRemaining = remaining,
	})
end

local depotPrompt, housePrompts = createWorld()

depotPrompt.Triggered:Connect(function(player)
	if playerJobs[player] then
		sendStatus(player, "Message", {
			text = "すでに配達中だよ。今の荷物を先に届けよう。",
		})
		return
	end

	assignJob(player)
end)

for _, entry in ipairs(housePrompts) do
	entry.prompt.Triggered:Connect(function(player)
		completeDelivery(player, entry.houseName)
	end)
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.WalkSpeed = 20
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerJobs[player] = nil
end)
