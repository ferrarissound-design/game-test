-- Night Delivery Release Candidate polish layer
-- Adds session missions, authoritative delivery grades/bonuses, random order modifiers,
-- and lightweight city dressing without replacing the v4 core script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local REMOTE_NAME = "NightDeliveryEvent"
local WORLD_NAME = "NightDeliveryWorld"

local deliveryEvent = ReplicatedStorage:WaitForChild(REMOTE_NAME, 30)
if not deliveryEvent or not deliveryEvent:IsA("RemoteEvent") then
	warn("Night Delivery RC: NightDeliveryEvent was not available")
	return
end

local JOB_LIMITS = {
	standard = 60,
	express = 35,
	rush = 26,
	long = 90,
	special = 50,
}

local GRADE_BONUS = {
	S = 100,
	A = 60,
	B = 25,
	C = 0,
}

local GRADE_ORDER = {
	S = 4,
	A = 3,
	B = 2,
	C = 1,
}

local SESSION_MISSIONS = {
	{id = "warmup", name = "夜の肩慣らし", target = 3, reward = 150},
	{id = "steady", name = "街に馴染む", target = 8, reward = 350},
	{id = "ace", name = "一晩のエース", target = 15, reward = 700},
}

local ORDER_MODIFIERS = {
	{id = "none", weight = 36, title = "通常便", description = "いつもの配達。自分に合うルートを選ぼう。", reward = 0, minGrade = "C"},
	{id = "fragile", weight = 12, title = "ワレモノ注意", description = "ジャンプや落下で荷物が傷む。地面を安定して走ろう。", reward = 110, minGrade = "A"},
	{id = "premium", weight = 10, title = "高級品", description = "丁寧に届けよう。A評価以上で追加報酬。", reward = 140, minGrade = "A"},
	{id = "tip", weight = 8, title = "常連さん", description = "受け取ってもらえればチップ確定。", reward = 55, minGrade = "C"},
	{id = "mystery", weight = 5, title = "宛名の薄い荷物", description = "近くで住所を確認。遠くではナビが弱くなる。", reward = 180, minGrade = "A"},
	{id = "frozen", weight = 9, title = "冷凍便", description = "35秒を超えると品質が下がる。寄り道は慎重に。", reward = 100, minGrade = "C"},
	{id = "oversized", weight = 8, title = "大型荷物", description = "自転車は使えない。徒歩で安定して運ぼう。", reward = 90, minGrade = "B"},
	{id = "hot", weight = 7, title = "温かい料理", description = "30秒以内に届けると追加報酬。", reward = 100, minGrade = "C"},
	{id = "secret", weight = 5, title = "秘密便", description = "遠くでは方角ナビが表示されない。街の目印を使おう。", reward = 125, minGrade = "B"},
}

local playerState = {}

local function getStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil, nil
	end
	return leaderstats:FindFirstChild("Coins"), leaderstats:FindFirstChild("Deliveries")
end

local function chooseModifier()
	local totalWeight = 0
	for _, modifier in ipairs(ORDER_MODIFIERS) do
		totalWeight += modifier.weight
	end

	local roll = math.random() * totalWeight
	local cursor = 0
	for _, modifier in ipairs(ORDER_MODIFIERS) do
		cursor += modifier.weight
		if roll <= cursor then
			return modifier
		end
	end
	return ORDER_MODIFIERS[1]
end

local function findModifier(id)
	for _, modifier in ipairs(ORDER_MODIFIERS) do
		if modifier.id == id then
			return modifier
		end
	end
	return nil
end

local function calculateGrade(elapsed, timeLimit)
	if not timeLimit or timeLimit <= 0 then
		return "C"
	end

	local ratio = elapsed / timeLimit
	if ratio <= 0.42 then
		return "S"
	elseif ratio <= 0.68 then
		return "A"
	elseif ratio <= 1.0 then
		return "B"
	end
	return "C"
end

local function modifierSucceeded(modifier, grade, elapsed, order)
	if not modifier or modifier.reward <= 0 then
		return false
	end
	if modifier.id == "fragile" and order.jumpDamaged then
		return false
	elseif modifier.id == "frozen" and elapsed > 35 then
		return false
	elseif modifier.id == "hot" and elapsed > 30 then
		return false
	end
	return (GRADE_ORDER[grade] or 1) >= (GRADE_ORDER[modifier.minGrade] or 1)
end

local function buildMissionState(state)
	local missions = {}
	for _, mission in ipairs(SESSION_MISSIONS) do
		table.insert(missions, {
			id = mission.id,
			name = mission.name,
			target = mission.target,
			reward = mission.reward,
			progress = math.min(state.sessionDeliveries, mission.target),
			completed = state.completedMissions[mission.id] == true,
		})
	end
	return missions
end

local function sendSessionState(player)
	local state = playerState[player]
	if not state then
		return
	end

	deliveryEvent:FireClient(player, "PolishSessionState", {
		sessionDeliveries = state.sessionDeliveries,
		missions = buildMissionState(state),
	})
end

local function awardMissionRewards(player, state)
	local coins = getStats(player)
	if not coins then
		return 0, {}
	end

	local total = 0
	local completedNow = {}
	for _, mission in ipairs(SESSION_MISSIONS) do
		if state.sessionDeliveries >= mission.target and not state.completedMissions[mission.id] then
			state.completedMissions[mission.id] = true
			total += mission.reward
			table.insert(completedNow, {
				id = mission.id,
				name = mission.name,
				reward = mission.reward,
			})
		end
	end

	if total > 0 then
		coins.Value += total
	end

	return total, completedNow
end

local function disconnectJumpMonitor(order)
	if order and order.jumpConnection then
		order.jumpConnection:Disconnect()
		order.jumpConnection = nil
	end
end

local function attachFragileMonitor(player, order)
	disconnectJumpMonitor(order)
	if not order or not order.modifier or order.modifier.id ~= "fragile" then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	order.jumpConnection = humanoid.StateChanged:Connect(function(_, newState)
		local state = playerState[player]
		if not state or state.activeOrder ~= order then
			return
		end
		if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
			order.jumpDamaged = true
		end
	end)
end

local function applyModifierSideEffects(player, modifier)
	local oversized = modifier and modifier.id == "oversized"
	local softNav = modifier and (modifier.id == "secret" or modifier.id == "mystery")
	player:SetAttribute("NightDeliveryBikeBlocked", oversized == true)
	player:SetAttribute("NightDeliveryNavSoft", softNav == true)

	if oversized and player:GetAttribute("BikeActive") == true then
		player:SetAttribute("BikeActive", false)
		local character = player.Character
		local bike = character and character:FindFirstChild("DeliveryBikeVisual")
		if bike then
			bike:Destroy()
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 20 + ((player:GetAttribute("SpeedLevel") or 0) * 2)
		end
		deliveryEvent:FireClient(player, "BikeMode", {
			active = false,
			speedLevel = player:GetAttribute("SpeedLevel") or 0,
		})
	end
end

local function prepareOrderFromAttributes(player)
	local state = playerState[player]
	if not state then
		return nil
	end

	local jobSerial = tonumber(player:GetAttribute("NightDeliveryJobSerial"))
	local jobTypeId = tostring(player:GetAttribute("NightDeliveryJobType") or "")
	local houseName = tostring(player:GetAttribute("NightDeliveryHouseName") or "")
	if not jobSerial or jobSerial <= 0 or houseName == "" or not JOB_LIMITS[jobTypeId] then
		return nil
	end

	if state.preparedOrder and state.preparedOrder.jobSerial == jobSerial then
		return state.preparedOrder
	end

	if state.activeOrder and state.activeOrder.jobSerial ~= jobSerial then
		disconnectJumpMonitor(state.activeOrder)
		state.activeOrder = nil
	end

	local requestedModifierId = player:GetAttribute("NightDeliveryRequestedModifier")
	local modifier = findModifier(requestedModifierId) or chooseModifier()
	local publicModifier = {
		jobSerial = jobSerial,
		id = modifier.id,
		title = modifier.title,
		description = modifier.description,
		reward = modifier.reward,
		minGrade = modifier.minGrade,
	}

	state.preparedOrder = {
		jobSerial = jobSerial,
		jobTypeId = jobTypeId,
		houseName = houseName,
		modifier = modifier,
		publicModifier = publicModifier,
	}
	applyModifierSideEffects(player, modifier)
	return state.preparedOrder
end

local function startPreparedOrder(player)
	local state = playerState[player]
	if not state then
		return
	end
	local jobSerial = tonumber(player:GetAttribute("NightDeliveryJobSerial"))
	local prepared = state.preparedOrder
	if not prepared or prepared.jobSerial ~= jobSerial then
		prepared = prepareOrderFromAttributes(player)
	end
	if not prepared then
		return
	end

	local timeLimit = tonumber(player:GetAttribute("NightDeliveryTimeLimit"))
	local startedAt = tonumber(player:GetAttribute("NightDeliveryOrderStartedAt"))
	if not timeLimit or not startedAt then
		return
	end
	if state.activeOrder and state.activeOrder.jobSerial == prepared.jobSerial then
		return
	end

	local _, deliveries = getStats(player)
	if not deliveries then
		return
	end

	if state.activeOrder then
		disconnectJumpMonitor(state.activeOrder)
	end
	local order = {
		baselineDeliveries = deliveries.Value,
		startedAt = startedAt,
		timeLimit = timeLimit,
		jobSerial = prepared.jobSerial,
		jobTypeId = prepared.jobTypeId,
		houseName = prepared.houseName,
		modifier = prepared.modifier,
		publicModifier = prepared.publicModifier,
		jumpDamaged = false,
	}
	state.activeOrder = order
	attachFragileMonitor(player, order)
end

local function sendPreparedModifier(player, requestedSerial)
	local prepared = prepareOrderFromAttributes(player)
	if not prepared then
		return
	end
	if requestedSerial and tonumber(requestedSerial) ~= prepared.jobSerial then
		return
	end
	deliveryEvent:FireClient(player, "PolishOrderModifier", prepared.publicModifier)
end

local function finishTrackedOrder(player)local function finishTrackedOrder(player)
	local state = playerState[player]
	if not state or not state.activeOrder then
		return
	end

	local coins, deliveries = getStats(player)
	if not coins or not deliveries then
		return
	end

	local order = state.activeOrder
	if deliveries.Value <= order.baselineDeliveries then
		return
	end
	if tonumber(player:GetAttribute("NightDeliveryCompletedJobSerial")) ~= order.jobSerial
		or tonumber(player:GetAttribute("NightDeliveryJobSerial")) ~= order.jobSerial then
		if order.jumpConnection then
			order.jumpConnection:Disconnect()
		end
		state.activeOrder = nil
		if state.preparedOrder and state.preparedOrder.jobSerial == order.jobSerial then
			state.preparedOrder = nil
		end
		return
	end
	disconnectJumpMonitor(order)
	state.activeOrder = nil
	if state.preparedOrder and state.preparedOrder.jobSerial == order.jobSerial then
		state.preparedOrder = nil
	end

	local elapsed = math.max(0, os.clock() - order.startedAt)
	local timeLimit = order.timeLimit or JOB_LIMITS[order.jobTypeId] or JOB_LIMITS.standard
	local grade = calculateGrade(elapsed, timeLimit)
	if order.modifier.id == "frozen" and elapsed > 35 then
		grade = ({S = "A", A = "B", B = "C", C = "C"})[grade] or "C"
	end
	if order.modifier.id == "fragile" and order.jumpDamaged then
		grade = "C"
	end
	local gradeBonus = GRADE_BONUS[grade] or 0
	local modifierBonus = modifierSucceeded(order.modifier, grade, elapsed, order) and order.modifier.reward or 0

	state.sessionDeliveries += 1
	local missionBonus, completedMissions = awardMissionRewards(player, state)
	local totalBonus = gradeBonus + modifierBonus

	if totalBonus > 0 then
		coins.Value += totalBonus
	end

	deliveryEvent:FireClient(player, "PolishDeliveryResult", {
		grade = grade,
		elapsed = elapsed,
		timeLimit = timeLimit,
		gradeBonus = gradeBonus,
		modifierId = order.modifier.id,
		modifierTitle = order.modifier.title,
		modifierBonus = modifierBonus,
		modifierSucceeded = modifierBonus > 0,
		missionBonus = missionBonus,
		completedMissions = completedMissions,
		totalBonus = totalBonus + missionBonus,
		sessionDeliveries = state.sessionDeliveries,
		missions = buildMissionState(state),
	})

	state.activeOrder = nil
end

local function initializePlayer(player)
	if playerState[player] then
		return
	end

	playerState[player] = {
		sessionDeliveries = 0,
		completedMissions = {},
		preparedOrder = nil,
		activeOrder = nil,
		lastRemoteAt = 0,
	}

	player:GetAttributeChangedSignal("NightDeliveryJobSerial"):Connect(function()
		task.defer(function()
			if player.Parent then
				prepareOrderFromAttributes(player)
			end
		end)
	end)
	player:GetAttributeChangedSignal("NightDeliveryOrderStartedAt"):Connect(function()
		task.defer(function()
			if player.Parent then
				startPreparedOrder(player)
			end
		end)
	end)
	player:GetAttributeChangedSignal("NightDeliveryCompletedJobSerial"):Connect(function()
		task.defer(function()
			if player.Parent then
				finishTrackedOrder(player)
			end
		end)
	end)
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("Humanoid", 10)
			local state = playerState[player]
			local order = state and state.activeOrder
			if order and order.modifier and order.modifier.id == "fragile" then
				attachFragileMonitor(player, order)
			end
		end)
	end)

	task.defer(function()
		if player.Parent then
			prepareOrderFromAttributes(player)
			startPreparedOrder(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(function(player)
	local state = playerState[player]
	if state and state.activeOrder then
		disconnectJumpMonitor(state.activeOrder)
	end
	playerState[player] = nil
end)

deliveryEvent.OnServerEvent:Connect(function(player, action, payload)
	local state = playerState[player]
	if not state then
		initializePlayer(player)
		state = playerState[player]
	end

	if action == "PolishRequestState" then
		sendSessionState(player)
		return
	elseif action == "PolishRequestOrderModifier" then
		local now = os.clock()
		if now - state.lastRemoteAt < 0.08 then
			return
		end
		state.lastRemoteAt = now
		local requestedSerial = type(payload) == "table" and payload.jobSerial or nil
		sendPreparedModifier(player, requestedSerial)
		return
	end
end)

-- Decorative release-candidate pass.-- Decorative release-candidate pass. Everything is generated from primitives,
-- so the project stays portable and needs no external assets.
local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addSurfaceText(part, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(238, 245, 255)
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function addPointLight(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function createTree(parent, position)
	makePart(parent, "TreeTrunk", Vector3.new(1.4, 7, 1.4), CFrame.new(position + Vector3.new(0, 3.5, 0)), Color3.fromRGB(84, 62, 45), Enum.Material.Wood)
	local crown = makePart(parent, "TreeCrown", Vector3.new(6, 6, 6), CFrame.new(position + Vector3.new(0, 8.2, 0)), Color3.fromRGB(45, 82, 61), Enum.Material.Grass)
	crown.Shape = Enum.PartType.Ball
end

local function createBench(parent, position, yaw)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	makePart(parent, "BenchSeat", Vector3.new(6, 0.5, 1.8), cf * CFrame.new(0, 1.8, 0), Color3.fromRGB(102, 77, 56), Enum.Material.Wood)
	makePart(parent, "BenchBack", Vector3.new(6, 2.4, 0.45), cf * CFrame.new(0, 2.9, 0.7), Color3.fromRGB(102, 77, 56), Enum.Material.Wood)
	makePart(parent, "BenchLeg", Vector3.new(0.45, 1.6, 0.45), cf * CFrame.new(-2.2, 0.8, 0), Color3.fromRGB(62, 65, 71), Enum.Material.Metal)
	makePart(parent, "BenchLeg", Vector3.new(0.45, 1.6, 0.45), cf * CFrame.new(2.2, 0.8, 0), Color3.fromRGB(62, 65, 71), Enum.Material.Metal)
end

local function createVendingMachine(parent, position, color)
	local body = makePart(parent, "VendingMachine", Vector3.new(3.3, 6.6, 2.2), CFrame.new(position + Vector3.new(0, 3.3, 0)), color, Enum.Material.Metal)
	local display = makePart(parent, "VendingGlow", Vector3.new(2.6, 3.2, 0.15), CFrame.new(position + Vector3.new(0, 4.1, -1.18)), Color3.fromRGB(190, 224, 239), Enum.Material.Neon)
	display.CanCollide = false
	addPointLight(display, Color3.fromRGB(176, 218, 240), 0.8, 10)
end

local function createCityDressing()
	local world = workspace:WaitForChild(WORLD_NAME, 30)
	if not world then
		warn("Night Delivery RC: world not found, skipping dressing")
		return
	end

	local old = world:FindFirstChild("ReleaseDressing")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "ReleaseDressing"
	folder.Parent = world

	-- Convenience store and parking lot
	makePart(folder, "StoreParking", Vector3.new(64, 0.25, 42), CFrame.new(150, 0.13, -48), Color3.fromRGB(53, 55, 60), Enum.Material.Pavement)
	makePart(folder, "ConvenienceStore", Vector3.new(34, 10, 22), CFrame.new(160, 5, -60), Color3.fromRGB(211, 216, 220), Enum.Material.Concrete)
	local storeSign = makePart(folder, "StoreSign", Vector3.new(27, 2.7, 0.5), CFrame.new(160, 9, -71.2), Color3.fromRGB(74, 178, 157), Enum.Material.Neon)
	addSurfaceText(storeSign, "NIGHT MART")
	addPointLight(storeSign, Color3.fromRGB(117, 235, 209), 1.2, 18)
	for x = 148, 172, 8 do
		local window = makePart(folder, "StoreWindow", Vector3.new(5.5, 5.2, 0.18), CFrame.new(x, 4.7, -71.15), Color3.fromRGB(236, 226, 181), Enum.Material.Glass)
		window.Transparency = 0.22
		addPointLight(window, Color3.fromRGB(255, 231, 182), 0.5, 9)
	end
	for x = 128, 174, 12 do
		makePart(folder, "ParkingLine", Vector3.new(0.18, 0.05, 16), CFrame.new(x, 0.28, -31), Color3.fromRGB(210, 210, 198), Enum.Material.SmoothPlastic)
	end

	-- Bus stop
	makePart(folder, "BusStopPad", Vector3.new(12, 0.3, 7), CFrame.new(25, 0.18, -34), Color3.fromRGB(97, 98, 101), Enum.Material.Concrete)
	makePart(folder, "BusStopRoof", Vector3.new(12, 0.45, 7), CFrame.new(25, 7.1, -34), Color3.fromRGB(70, 77, 88), Enum.Material.Metal)
	for dx = -5, 5, 10 do
		makePart(folder, "BusStopPole", Vector3.new(0.45, 7, 0.45), CFrame.new(25 + dx, 3.5, -34), Color3.fromRGB(75, 79, 87), Enum.Material.Metal)
	end
	createBench(folder, Vector3.new(25, 0, -34), 0)
	local routeSign = makePart(folder, "BusRouteSign", Vector3.new(4.5, 3, 0.4), CFrame.new(25, 5.4, -37.7), Color3.fromRGB(54, 88, 137), Enum.Material.Neon)
	addSurfaceText(routeSign, "MIDNIGHT 04")
	addPointLight(routeSign, Color3.fromRGB(117, 162, 225), 0.8, 12)

	-- Small park / rest corner
	makePart(folder, "PocketPark", Vector3.new(42, 0.2, 34), CFrame.new(-154, 0.11, 25), Color3.fromRGB(50, 72, 58), Enum.Material.Grass)
	for _, pos in ipairs({
		Vector3.new(-168, 0, 13),
		Vector3.new(-142, 0, 14),
		Vector3.new(-167, 0, 37),
		Vector3.new(-141, 0, 38),
	}) do
		createTree(folder, pos)
	end
	createBench(folder, Vector3.new(-154, 0, 22), 90)
	createBench(folder, Vector3.new(-154, 0, 31), -90)

	-- Depot details
	createVendingMachine(folder, Vector3.new(-103, 0, -79), Color3.fromRGB(67, 126, 183))
	createVendingMachine(folder, Vector3.new(-99, 0, -79), Color3.fromRGB(173, 72, 78))
	local depotLamp = makePart(folder, "DepotAreaLight", Vector3.new(4, 0.25, 1.3), CFrame.new(-82, 9.2, -80.5), Color3.fromRGB(224, 242, 255), Enum.Material.Neon)
	depotLamp.CanCollide = false
	addPointLight(depotLamp, Color3.fromRGB(200, 226, 255), 1.2, 22)

	-- Warehouse construction detail
	for index = 0, 6 do
		local x = 112 + index * 4
		local cone = makePart(folder, "TrafficCone", Vector3.new(1, 2.2, 1), CFrame.new(x, 1.1, -111), Color3.fromRGB(224, 111, 47), Enum.Material.SmoothPlastic)
		cone.Shape = Enum.PartType.Cylinder
	end
	makePart(folder, "WorkBarrier", Vector3.new(28, 1.1, 0.5), CFrame.new(124, 1.8, -108), Color3.fromRGB(229, 181, 63), Enum.Material.Metal)

	-- Roadside trees make the generated city read as a place, not a gray test grid.
	for z = -70, 105, 35 do
		createTree(folder, Vector3.new(-34, 0, z))
		createTree(folder, Vector3.new(34, 0, z))
	end

	local bloom = Lighting:FindFirstChild("NightDeliveryReleaseBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "NightDeliveryReleaseBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.28
	bloom.Size = 18
	bloom.Threshold = 1.7

	local colorCorrection = Lighting:FindFirstChild("NightDeliveryReleaseColor")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "NightDeliveryReleaseColor"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = -0.01
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = -0.08
	colorCorrection.TintColor = Color3.fromRGB(224, 232, 255)
end

task.spawn(createCityDressing)

print("Night Delivery RC polish layer loaded")
