-- Night Delivery v4
-- StarterPlayer/StarterPlayerScripts/NightDelivery.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local deliveryEvent = ReplicatedStorage:WaitForChild("NightDeliveryEvent")

local RIVERSIDE_UNLOCK_DELIVERIES = 5
local SPECIAL_JOB_UNLOCK_DELIVERIES = 8
local WAREHOUSE_UNLOCK_DELIVERIES = 15

local currentHouseName = nil
local currentDisplayName = nil
local currentDistrictName = nil
local currentJobTypeName = nil
local currentJobTypeId = nil
local currentWeatherName = "晴れ"
local currentWeatherMultiplier = 1
local activeJobWeatherName = nil
local activeJobWeatherMultiplier = nil
local currentRankName = "新人"
local shiftProgress = 0
local shiftTarget = 6
local expiresAt = nil
local currentHighlight = nil
local currentBillboard = nil
local currentTargetPart = nil
local blockingTravelObjectiveActive = false
local destinationEventObjectiveActive = false
local bikeActive = false
local routeJobSerial = nil
local routeShortcutReward = 80
local playerControls = nil
bikeActive = player:GetAttribute("BikeActive") == true
local bikeAudioCharacter = nil
local bikeAudioHumanoid = nil
local bikeRollingSound = nil
local bikeIsMoving = false
local bikeRunSoundVolumes = {}
local bikeAudioConnections = {}

local BIKE_CHAIN_SOUND_ID = "rbxassetid://9114229845"

local function clearBikeAudio()
	for _, connection in ipairs(bikeAudioConnections) do
		connection:Disconnect()
	end
	table.clear(bikeAudioConnections)

	for runningSound, originalVolume in pairs(bikeRunSoundVolumes) do
		if runningSound.Parent then
			runningSound.Volume = originalVolume
		end
	end
	table.clear(bikeRunSoundVolumes)

	if bikeRollingSound then
		bikeRollingSound:Stop()
		bikeRollingSound:Destroy()
		bikeRollingSound = nil
	end
	bikeAudioCharacter = nil
	bikeAudioHumanoid = nil
	bikeIsMoving = false
end

local function refreshBikeAudio()
	local character = bikeAudioCharacter
	local humanoid = bikeAudioHumanoid
	if not character or not humanoid then
		return
	end

	local riding = player:GetAttribute("BikeActive") == true
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Sound") and descendant.Name == "Running" then
			if bikeRunSoundVolumes[descendant] == nil then
				bikeRunSoundVolumes[descendant] = descendant.Volume
			end
			descendant.Volume = riding and 0 or bikeRunSoundVolumes[descendant]
		end
	end

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if bikeRollingSound then
		if riding and bikeIsMoving and grounded and humanoid.Health > 0 then
			bikeRollingSound.PlaybackSpeed = math.clamp(humanoid.WalkSpeed / 20, 0.7, 1.25)
			if not bikeRollingSound.IsPlaying then
				bikeRollingSound:Play()
			end
		else
			bikeRollingSound:Stop()
		end
	end
end

local function setupBikeAudio(character)
	clearBikeAudio()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid or player.Character ~= character then
		return
	end

	bikeAudioCharacter = character
	bikeAudioHumanoid = humanoid
	local rollingSound = Instance.new("Sound")
	rollingSound.Name = "NightDeliveryBikeChain"
	rollingSound.SoundId = BIKE_CHAIN_SOUND_ID
	rollingSound.Volume = 0.12
	rollingSound.PlaybackSpeed = 0.8
	rollingSound.Looped = true
	rollingSound.RollOffMaxDistance = 55
	rollingSound.Parent = root
	bikeRollingSound = rollingSound

	table.insert(bikeAudioConnections, character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Sound") and descendant.Name == "Running" then
			task.defer(refreshBikeAudio)
		end
	end))
	table.insert(bikeAudioConnections, humanoid.Running:Connect(function(speed)
		bikeIsMoving = speed > 1
		refreshBikeAudio()
	end))
	table.insert(bikeAudioConnections, humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(refreshBikeAudio))
	refreshBikeAudio()
end

player:GetAttributeChangedSignal("BikeActive"):Connect(function()
	bikeActive = player:GetAttribute("BikeActive") == true
	refreshBikeAudio()
end)
player.CharacterAdded:Connect(function(character)
	task.spawn(setupBikeAudio, character)
end)
player.CharacterRemoving:Connect(clearBikeAudio)
if player.Character then
	task.spawn(setupBikeAudio, player.Character)
end

local function setRouteMovementLocked(locked)
	local ok, controls = pcall(function()
		if not playerControls then
			local playerScripts = player:WaitForChild("PlayerScripts")
			local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
			playerControls = playerModule:GetControls()
		end
		return playerControls
	end)
	if not ok or not controls then
		warn("[NightDelivery] could not access player controls for route chooser")
		return
	end

	if locked then
		controls:Disable()
	else
		controls:Enable()
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "NightDeliveryUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Core route chooser.
-- This lives in the main gameplay client instead of relying on the optional
-- polish HUD, so accepting a parcel can never leave the player unable to
-- choose a route.
local routeGui = Instance.new("ScreenGui")
routeGui.Name = "NightDeliveryRouteUI"
routeGui.ResetOnSpawn = false
routeGui.IgnoreGuiInset = false
routeGui.DisplayOrder = 100
routeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
routeGui.Parent = player.PlayerGui

local routeFrame = Instance.new("Frame")
routeFrame.Name = "RouteChoice"
routeFrame.Size = UDim2.new(0.88, 0, 0, 220)
routeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
routeFrame.Position = UDim2.fromScale(0.5, 0.5)
routeFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
routeFrame.BackgroundTransparency = 0.03
routeFrame.Visible = false
routeFrame.ZIndex = 100
routeFrame.Parent = routeGui

local routeSizeConstraint = Instance.new("UISizeConstraint")
routeSizeConstraint.MinSize = Vector2.new(280, 220)
routeSizeConstraint.MaxSize = Vector2.new(460, 220)
routeSizeConstraint.Parent = routeFrame

local routeCorner = Instance.new("UICorner")
routeCorner.CornerRadius = UDim.new(0, 16)
routeCorner.Parent = routeFrame

local routeStroke = Instance.new("UIStroke")
routeStroke.Color = Color3.fromRGB(105, 171, 230)
routeStroke.Transparency = 0.18
routeStroke.Thickness = 1.5
routeStroke.Parent = routeFrame

local routeTitle = Instance.new("TextLabel")
routeTitle.Size = UDim2.new(1, -24, 0, 30)
routeTitle.Position = UDim2.fromOffset(12, 10)
routeTitle.BackgroundTransparency = 1
routeTitle.Text = "どのルートで届ける？"
routeTitle.TextColor3 = Color3.fromRGB(246, 250, 255)
routeTitle.Font = Enum.Font.GothamBold
routeTitle.TextSize = 19
routeTitle.TextXAlignment = Enum.TextXAlignment.Left
routeTitle.ZIndex = 101
routeTitle.Parent = routeFrame

local routeHint = Instance.new("TextLabel")
routeHint.Size = UDim2.new(1, -24, 0, 32)
routeHint.Position = UDim2.fromOffset(12, 42)
routeHint.BackgroundTransparency = 1
routeHint.Text = "荷物を受け取った。先に配達ルートを選ぼう。"
routeHint.TextColor3 = Color3.fromRGB(191, 205, 224)
routeHint.Font = Enum.Font.Gotham
routeHint.TextSize = 12
routeHint.TextWrapped = true
routeHint.TextXAlignment = Enum.TextXAlignment.Left
routeHint.ZIndex = 101
routeHint.Parent = routeFrame

local lanternRouteButton = Instance.new("TextButton")
lanternRouteButton.Name = "LanternRoute"
lanternRouteButton.Size = UDim2.new(1, -24, 0, 58)
lanternRouteButton.Position = UDim2.fromOffset(12, 86)
lanternRouteButton.BackgroundColor3 = Color3.fromRGB(54, 76, 89)
lanternRouteButton.Text = "街灯の道  ・  時間に余裕  ・  追加報酬なし"
lanternRouteButton.TextColor3 = Color3.fromRGB(241, 247, 252)
lanternRouteButton.TextSize = 14
lanternRouteButton.TextWrapped = true
lanternRouteButton.Font = Enum.Font.GothamBold
lanternRouteButton.ZIndex = 101
lanternRouteButton.Parent = routeFrame

local lanternCorner = Instance.new("UICorner")
lanternCorner.CornerRadius = UDim.new(0, 10)
lanternCorner.Parent = lanternRouteButton

local shortcutRouteButton = Instance.new("TextButton")
shortcutRouteButton.Name = "ShortcutRoute"
shortcutRouteButton.Size = UDim2.new(1, -24, 0, 58)
shortcutRouteButton.Position = UDim2.fromOffset(12, 152)
shortcutRouteButton.BackgroundColor3 = Color3.fromRGB(103, 70, 51)
shortcutRouteButton.TextColor3 = Color3.fromRGB(255, 239, 219)
shortcutRouteButton.TextSize = 14
shortcutRouteButton.TextWrapped = true
shortcutRouteButton.Font = Enum.Font.GothamBold
shortcutRouteButton.ZIndex = 101
shortcutRouteButton.Parent = routeFrame

local shortcutCorner = Instance.new("UICorner")
shortcutCorner.CornerRadius = UDim.new(0, 10)
shortcutCorner.Parent = shortcutRouteButton

local function showCoreRouteChoice(jobSerial, shortcutReward)
	routeJobSerial = tonumber(jobSerial)
	routeShortcutReward = tonumber(shortcutReward) or 80
	if not routeJobSerial then
		return
	end
	routeHint.Text = "荷物を受け取った。先に配達ルートを選ぼう。"
	lanternRouteButton.Active = true
	lanternRouteButton.AutoButtonColor = true
	shortcutRouteButton.Active = true
	shortcutRouteButton.AutoButtonColor = true
	lanternRouteButton.Text = "街灯の道  ・  時間に余裕  ・  追加報酬なし"
	shortcutRouteButton.Text = string.format(
		"裏路地の近道  ・  制限時間短め  ・  成功で +%d Coins",
		routeShortcutReward
	)
	routeFrame.Visible = true
	setRouteMovementLocked(true)
	print("[NightDelivery] core route chooser shown", routeJobSerial)
end

local function hideCoreRouteChoice()
	routeFrame.Visible = false
	routeJobSerial = nil
	setRouteMovementLocked(false)
end

local function submitCoreRoute(routeId)
	if not routeFrame.Visible or not routeJobSerial then
		return
	end
	lanternRouteButton.Active = false
	lanternRouteButton.AutoButtonColor = false
	shortcutRouteButton.Active = false
	shortcutRouteButton.AutoButtonColor = false
	routeHint.Text = "ルートを確定しています..."
	deliveryEvent:FireServer("ChooseRoute", {
		jobSerial = routeJobSerial,
		routeId = routeId,
	})

	local submittedSerial = routeJobSerial
	task.delay(1.5, function()
		if routeFrame.Visible
			and routeJobSerial == submittedSerial
			and player:GetAttribute("NightDeliveryOrderStartedAt") == nil then
			routeHint.Text = "まだ確定していません。もう一度ルートを選べます。"
			lanternRouteButton.Active = true
			lanternRouteButton.AutoButtonColor = true
			shortcutRouteButton.Active = true
			shortcutRouteButton.AutoButtonColor = true
		end
	end)
end

lanternRouteButton.Activated:Connect(function()
	submitCoreRoute("lantern")
end)

shortcutRouteButton.Activated:Connect(function()
	submitCoreRoute("shortcut")
end)

local function recoverCoreRouteChoice()
	local jobSerial = tonumber(player:GetAttribute("NightDeliveryJobSerial"))
	local houseName = tostring(player:GetAttribute("NightDeliveryHouseName") or "")
	local startedAt = player:GetAttribute("NightDeliveryOrderStartedAt")
	if jobSerial and jobSerial > 0 and houseName ~= "" and startedAt == nil then
		local world = workspace:FindFirstChild("NightDeliveryWorld")
		local shortcutReward = 80
		if world and tostring(world:GetAttribute("NightConditionId") or "") == "roadwork" then
			shortcutReward += 40
		end
		if not routeFrame.Visible or routeJobSerial ~= jobSerial then
			routeHint.Text = "荷物を受け取った。先に配達ルートを選ぼう。"
			showCoreRouteChoice(jobSerial, shortcutReward)
		end
	elseif startedAt ~= nil then
		hideCoreRouteChoice()
	end
end

player:GetAttributeChangedSignal("NightDeliveryJobSerial"):Connect(function()
	task.defer(recoverCoreRouteChoice)
end)
player:GetAttributeChangedSignal("NightDeliveryHouseName"):Connect(function()
	task.defer(recoverCoreRouteChoice)
end)
player:GetAttributeChangedSignal("NightDeliveryOrderStartedAt"):Connect(function()
	task.defer(recoverCoreRouteChoice)
end)
task.defer(recoverCoreRouteChoice)

local panel = Instance.new("Frame")
panel.Name = "ObjectivePanel"
panel.Size = UDim2.fromOffset(170, 72)
panel.Position = UDim2.fromOffset(10, 10)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
panel.BackgroundTransparency = 0.28
panel.BorderSizePixel = 0
panel.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(130, 72)
sizeConstraint.MaxSize = Vector2.new(230, 72)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(97, 140, 180)
stroke.Transparency = 0.5
stroke.Thickness = 1
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 20)
title.Position = UDim2.fromOffset(10, 5)
title.BackgroundTransparency = 1
title.Text = "現在の目的"
title.TextColor3 = Color3.fromRGB(232, 241, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -20, 0, 22)
targetLabel.Position = UDim2.fromOffset(10, 26)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "配達所で荷物を受け取ろう"
targetLabel.TextColor3 = Color3.fromRGB(210, 219, 232)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 13
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.TextTruncate = Enum.TextTruncate.AtEnd
targetLabel.Parent = panel

local jobLabel = Instance.new("TextLabel")
jobLabel.Size = UDim2.new(1, -20, 0, 24)
jobLabel.Position = UDim2.fromOffset(10, 48)
jobLabel.BackgroundTransparency = 1
jobLabel.Text = "通常便 / 速達便 / 遠距離便 / 深夜特別便"
jobLabel.TextColor3 = Color3.fromRGB(157, 190, 225)
jobLabel.Font = Enum.Font.GothamMedium
jobLabel.TextSize = 11
jobLabel.TextXAlignment = Enum.TextXAlignment.Left
jobLabel.TextYAlignment = Enum.TextYAlignment.Top
jobLabel.TextWrapped = true
jobLabel.Parent = panel
jobLabel.Visible = false -- Details are shown when the job is assigned, then navigation takes over.

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -20, 0, 20)
timerLabel.Position = UDim2.fromOffset(10, 49)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 219, 138)
timerLabel.Font = Enum.Font.GothamMedium
timerLabel.TextSize = 13
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = panel

local statusPanel = Instance.new("Frame")
statusPanel.Name = "StatusPanel"
statusPanel.Size = UDim2.fromOffset(170, 76)
statusPanel.AnchorPoint = Vector2.new(1, 0)
statusPanel.Position = UDim2.new(1, -10, 0, 10)
statusPanel.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
statusPanel.BackgroundTransparency = 0.28
statusPanel.BorderSizePixel = 0
statusPanel.Parent = gui

local statusSizeConstraint = Instance.new("UISizeConstraint")
statusSizeConstraint.MinSize = Vector2.new(130, 76)
statusSizeConstraint.MaxSize = Vector2.new(230, 76)
statusSizeConstraint.Parent = statusPanel

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = statusPanel

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(97, 140, 180)
statusStroke.Transparency = 0.5
statusStroke.Thickness = 1
statusStroke.Parent = statusPanel

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.new(1, -20, 0, 20)
statusTitle.Position = UDim2.fromOffset(10, 5)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "🌙 NIGHT DELIVERY"
statusTitle.TextColor3 = Color3.fromRGB(232, 241, 255)
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 13
statusTitle.TextXAlignment = Enum.TextXAlignment.Right
statusTitle.Parent = statusPanel

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 20)
statsLabel.Position = UDim2.fromOffset(10, 27)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "Coins 0  •  配達 0  •  🚲 OFF"
statsLabel.TextColor3 = Color3.fromRGB(190, 206, 220)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 12
statsLabel.TextXAlignment = Enum.TextXAlignment.Right
statsLabel.Parent = statusPanel

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -20, 0, 36)
progressLabel.Position = UDim2.fromOffset(10, 93)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "川沿い地区まであと5件"
progressLabel.TextColor3 = Color3.fromRGB(145, 207, 184)
progressLabel.Font = Enum.Font.GothamMedium
progressLabel.TextSize = 11
progressLabel.TextXAlignment = Enum.TextXAlignment.Right
progressLabel.TextYAlignment = Enum.TextYAlignment.Top
progressLabel.TextWrapped = true
progressLabel.Parent = statusPanel
progressLabel.Visible = false

local weatherLabel = Instance.new("TextLabel")
weatherLabel.Size = UDim2.new(1, -20, 0, 20)
weatherLabel.Position = UDim2.fromOffset(10, 49)
weatherLabel.BackgroundTransparency = 1
weatherLabel.Text = "☀ 晴れ  •  報酬 x1.00"
weatherLabel.TextColor3 = Color3.fromRGB(191, 210, 228)
weatherLabel.Font = Enum.Font.GothamMedium
weatherLabel.TextSize = 12
weatherLabel.TextXAlignment = Enum.TextXAlignment.Right
weatherLabel.Parent = statusPanel
weatherLabel.Visible = false

local shiftLabel = Instance.new("TextLabel")
shiftLabel.Size = UDim2.new(1, -20, 0, 20)
shiftLabel.Position = UDim2.fromOffset(10, 49)
shiftLabel.BackgroundTransparency = 1
shiftLabel.Text = "新人  •  夜勤 0/6"
shiftLabel.TextColor3 = Color3.fromRGB(225, 205, 154)
shiftLabel.Font = Enum.Font.GothamMedium
shiftLabel.TextSize = 12
shiftLabel.TextXAlignment = Enum.TextXAlignment.Right
shiftLabel.Parent = statusPanel

local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0.78, 0, 0, 42)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -74)
toast.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(245, 248, 255)
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 14
toast.TextWrapped = true
toast.BorderSizePixel = 0
toast.Parent = gui

local toastSizeConstraint = Instance.new("UISizeConstraint")
toastSizeConstraint.MinSize = Vector2.new(220, 42)
toastSizeConstraint.MaxSize = Vector2.new(440, 42)
toastSizeConstraint.Parent = toast

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 9)
toastCorner.Parent = toast

local guide = Instance.new("TextLabel")
guide.Size = UDim2.new(1, 0, 0, 24)
guide.AnchorPoint = Vector2.new(0.5, 1)
guide.Position = UDim2.new(0.5, 0, 1, 0)
guide.BackgroundColor3 = Color3.fromRGB(28, 34, 44)
guide.BackgroundTransparency = 0.38
guide.TextColor3 = Color3.fromRGB(215, 226, 238)
guide.Font = Enum.Font.Gotham
guide.TextSize = 11
guide.Text = "黄  配達所  /  青  自転車  /  紫  ショップ"
guide.BorderSizePixel = 0
guide.Parent = gui
task.delay(9, function()
	if guide.Parent then guide.Visible = false end
end)

local promptButton = Instance.new("TextButton")
promptButton.Name = "InteractionPrompt"
promptButton.Size = UDim2.new(0.72, 0, 0, 34)
promptButton.AnchorPoint = Vector2.new(0.5, 1)
promptButton.Position = UDim2.new(0.5, 0, 1, -30)
promptButton.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
promptButton.BackgroundTransparency = 0.18
promptButton.BorderSizePixel = 0
promptButton.TextColor3 = Color3.fromRGB(245, 248, 255)
promptButton.Font = Enum.Font.GothamBold
promptButton.TextSize = 13
promptButton.AutoButtonColor = true
promptButton.Visible = false
promptButton.ZIndex = 5
promptButton.Parent = gui

local promptSizeConstraint = Instance.new("UISizeConstraint")
promptSizeConstraint.MinSize = Vector2.new(180, 34)
promptSizeConstraint.MaxSize = Vector2.new(300, 34)
promptSizeConstraint.Parent = promptButton

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 8)
promptCorner.Parent = promptButton

local activePrompt = nil
local promptHoldActive = false

local function endPromptHold()
	if activePrompt and promptHoldActive then
		promptHoldActive = false
		activePrompt:InputHoldEnd()
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	endPromptHold()
	activePrompt = prompt

	local inputText = prompt.KeyboardKeyCode.Name
	if inputType == Enum.ProximityPromptInputType.Touch then
		inputText = "タップ"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		inputText = prompt.GamepadKeyCode.Name:gsub("Button", "")
	end

	local actionText = prompt.ActionText
	if prompt.Name == "DeliverPrompt" and currentHouseName
		and prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == currentHouseName
		and player:GetAttribute("NightDeliveryOddityId") == "silent_house" then
		actionText = "静かに置く"
	end
	promptButton.Text = string.format("%s  %s", inputText, actionText)
	promptButton.Visible = true
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt ~= activePrompt then
		return
	end

	endPromptHold()
	activePrompt = nil
	promptButton.Visible = false
end)

promptButton.InputBegan:Connect(function(input)
	local isPointer = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if activePrompt and isPointer and not promptHoldActive then
		promptHoldActive = true
		activePrompt:InputHoldBegin()
	end
end)

promptButton.InputEnded:Connect(function(input)
	local isPointer = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if isPointer then
		endPromptHold()
	end
end)


local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopPanel"
shopFrame.Size = UDim2.new(0.9, 0, 0, 260)
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
shopFrame.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
shopFrame.BackgroundTransparency = 0.03
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = gui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 14)
shopCorner.Parent = shopFrame

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(160, 122, 210)
shopStroke.Transparency = 0.2
shopStroke.Thickness = 1.5
shopStroke.Parent = shopFrame

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, -48, 0, 38)
shopTitle.Position = UDim2.fromOffset(16, 8)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "🌙 夜間配達ショップ"
shopTitle.TextColor3 = Color3.fromRGB(241, 235, 255)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 20
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Parent = shopFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.Position = UDim2.new(1, -44, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(57, 61, 74)
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(245, 245, 250)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 24
closeButton.Parent = shopFrame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local shopCoins = Instance.new("TextLabel")
shopCoins.Size = UDim2.new(1, -32, 0, 26)
shopCoins.Position = UDim2.fromOffset(16, 48)
shopCoins.BackgroundTransparency = 1
shopCoins.Text = "Coins 0"
shopCoins.TextColor3 = Color3.fromRGB(255, 219, 138)
shopCoins.Font = Enum.Font.GothamMedium
shopCoins.TextSize = 16
shopCoins.TextXAlignment = Enum.TextXAlignment.Left
shopCoins.Parent = shopFrame

local function makeShopButton(y)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -32, 0, 48)
	button.Position = UDim2.fromOffset(16, y)
	button.BackgroundColor3 = Color3.fromRGB(47, 54, 70)
	button.TextColor3 = Color3.fromRGB(238, 242, 250)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 15
	button.TextWrapped = true
	button.Parent = shopFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = button
	return button
end

local speedButton = makeShopButton(80)
local bagButton = makeShopButton(136)
local bikeStyleButton = makeShopButton(192)

closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

speedButton.Activated:Connect(function()
	deliveryEvent:FireServer("BuySpeed")
end)

bagButton.Activated:Connect(function()
	deliveryEvent:FireServer("BuyBagStyle")
end)

bikeStyleButton.Activated:Connect(function()
	deliveryEvent:FireServer("BuyBikeStyle")
end)

local weatherOverlay = Instance.new("Frame")
weatherOverlay.Name = "WeatherOverlay"
weatherOverlay.Size = UDim2.fromScale(1, 1)
weatherOverlay.BackgroundColor3 = Color3.fromRGB(116, 126, 142)
weatherOverlay.BackgroundTransparency = 1
weatherOverlay.BorderSizePixel = 0
weatherOverlay.ZIndex = 0
weatherOverlay.Parent = gui

local rainLines = {}
for index = 1, 24 do
	local line = Instance.new("Frame")
	line.Name = "Rain" .. index
	line.Size = UDim2.fromOffset(2, 24)
	line.BackgroundColor3 = Color3.fromRGB(190, 210, 230)
	line.BackgroundTransparency = 0.58
	line.BorderSizePixel = 0
	line.Rotation = 12
	line.Visible = false
	line.ZIndex = 0
	line.Parent = weatherOverlay
	table.insert(rainLines, line)
end

local function updateWeatherVisual()
	local raining = currentWeatherName == "雨"
	local foggy = currentWeatherName == "濃霧"
	weatherOverlay.BackgroundTransparency = foggy and 0.9 or 1
	for _, line in ipairs(rainLines) do
		line.Visible = raining
	end
end

local toastSerial = 0

local function showToast(text)
	toastSerial += 1
	local serial = toastSerial

	toast.Text = text
	TweenService:Create(toast, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.14,
		TextTransparency = 0,
	}):Play()

	task.delay(2.7, function()
		if serial ~= toastSerial then
			return
		end

		TweenService:Create(toast, TweenInfo.new(0.25), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
	end)
end

local function clearWaypoint()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end

	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	currentTargetPart = nil
end

local function setWaypoint(houseName)
	clearWaypoint()

	local world = workspace:WaitForChild("NightDeliveryWorld", 10)
	if not world then
		return
	end

	local houses = world:FindFirstChild("Houses")
	if not houses then
		return
	end

	local house = houses:FindFirstChild(houseName)
	if not house then
		return
	end

	local body = house:FindFirstChild("Body")
	if not body then
		return
	end
	currentTargetPart = house:FindFirstChild("DeliveryPoint") or body

	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalDeliveryHighlight"
	highlight.FillColor = Color3.fromRGB(255, 211, 92)
	highlight.FillTransparency = 0.68
	highlight.OutlineColor = Color3.fromRGB(255, 238, 160)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = house
	highlight.Parent = house
	currentHighlight = highlight

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LocalDeliveryMarker"
	billboard.Size = UDim2.fromOffset(132, 30)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.MaxDistance = 90
	billboard.Adornee = body
	billboard.Parent = body
	currentBillboard = billboard

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	label.BackgroundTransparency = 0.1
	label.Text = "📦 " .. (currentDisplayName or "配達先")
	label.TextColor3 = Color3.fromRGB(255, 236, 170)
	label.TextSize = 13
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 10)
	labelCorner.Parent = label
end

local function updateStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	local deliveries = leaderstats and leaderstats:FindFirstChild("Deliveries")

	local coinText = coins and coins.Value or 0
	local deliveryText = deliveries and deliveries.Value or 0
	local bikeText = bikeActive and "🚲" or ""

	statsLabel.Text = string.format("%d Coins  •  %d件 %s", coinText, deliveryText, bikeText)
	shiftLabel.Text = string.format("SHIFT %d/%d", shiftProgress, shiftTarget)
	local weatherIcon = currentWeatherName == "雨" and "🌧" or (currentWeatherName == "濃霧" and "🌫" or "☀")
	if currentHouseName and activeJobWeatherName and activeJobWeatherMultiplier then
		weatherLabel.Text = string.format(
			"%s 現在 %s  •  この依頼 %s x%.2f",
			weatherIcon,
			currentWeatherName,
			activeJobWeatherName,
			activeJobWeatherMultiplier
		)
	else
		weatherLabel.Text = string.format("%s %s  •  次の依頼 x%.2f", weatherIcon, currentWeatherName, currentWeatherMultiplier)
	end

	if deliveryText < RIVERSIDE_UNLOCK_DELIVERIES then
		local remaining = RIVERSIDE_UNLOCK_DELIVERIES - deliveryText
		progressLabel.Text = string.format("🌉 川沿い地区まであと%d件", remaining)
		progressLabel.TextColor3 = Color3.fromRGB(145, 207, 184)
	elseif deliveryText < SPECIAL_JOB_UNLOCK_DELIVERIES then
		local remaining = SPECIAL_JOB_UNLOCK_DELIVERIES - deliveryText
		progressLabel.Text = string.format("🌉 川沿い地区 解放済み  •  特別便まであと%d件", remaining)
		progressLabel.TextColor3 = Color3.fromRGB(151, 201, 230)
	elseif deliveryText < WAREHOUSE_UNLOCK_DELIVERIES then
		local remaining = WAREHOUSE_UNLOCK_DELIVERIES - deliveryText
		progressLabel.Text = string.format("🟣 特別便 解放済み  •  倉庫街まであと%d件", remaining)
		progressLabel.TextColor3 = Color3.fromRGB(197, 157, 238)
	else
		progressLabel.Text = "🌉 川沿い / 🟣 特別便 / 🏭 倉庫街 すべて解放済み"
		progressLabel.TextColor3 = Color3.fromRGB(221, 190, 116)
	end
end

local function connectStats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	local coins = leaderstats:WaitForChild("Coins", 5)
	local deliveries = leaderstats:WaitForChild("Deliveries", 5)

	if coins then
		coins:GetPropertyChangedSignal("Value"):Connect(updateStats)
	end
	if deliveries then
		deliveries:GetPropertyChangedSignal("Value"):Connect(updateStats)
	end

	updateStats()
end

task.spawn(connectStats)

deliveryEvent.OnClientEvent:Connect(function(action, payload)
	if action == "JobAssigned" then
		blockingTravelObjectiveActive = false
		destinationEventObjectiveActive = false
		currentHouseName = payload.houseName
		currentDisplayName = payload.displayName
		if payload.houseType and payload.houseType ~= "Normal" then
			currentDisplayName = currentDisplayName .. "（" .. tostring(payload.houseTypeLabel or "Obby") .. "）"
		end
		currentDistrictName = payload.districtName
		currentJobTypeName = payload.jobTypeName
		currentJobTypeId = payload.jobTypeId
		activeJobWeatherName = payload.weatherName or currentWeatherName
		activeJobWeatherMultiplier = payload.weatherMultiplier or currentWeatherMultiplier
		updateWeatherVisual()
		expiresAt = payload.expiresAt

		targetLabel.Text = "▲ " .. (currentDisplayName or currentHouseName)
		jobLabel.Text = string.format(
			"%s  •  %s  •  %s x%.2f  •  基本 %d  •  バッグ枠 %d",
			currentDistrictName or "住宅街",
			currentJobTypeName or "配達",
			activeJobWeatherName or currentWeatherName,
			activeJobWeatherMultiplier or currentWeatherMultiplier,
			payload.baseReward or 0,
			payload.bagCapacity or 1
		)
		if payload.recipient then
			jobLabel.Text ..= "  •  Recipient: " .. tostring(payload.recipient)
		elseif payload.oddityInstruction then
			jobLabel.Text ..= "  •  " .. tostring(payload.oddityInstruction)
		end
		if (payload.walkingBonusPreview or 0) > 0 then
			jobLabel.Text ..= string.format("  •  🚶 徒歩成功 +%d", payload.walkingBonusPreview)
		end
		jobLabel.TextColor3 = currentJobTypeId == "special"
			and Color3.fromRGB(214, 156, 255)
			or (currentJobTypeId == "rush" and Color3.fromRGB(255, 207, 110) or Color3.fromRGB(157, 190, 225))

		setWaypoint(currentHouseName)
		showCoreRouteChoice(payload.jobSerial, payload.shortcutReward)
		updateStats()
		if payload.oddityInstruction then
			showToast(tostring(payload.oddityInstruction))
		elseif payload.recipient then
			showToast("Recipient: " .. tostring(payload.recipient))
		elseif payload.neighborhoodThreadTitle then
			showToast("🧩 街のつながり: " .. tostring(payload.neighborhoodThreadTitle))
		elseif currentJobTypeId == "special" then
			showToast("🟣 深夜特別便！ 高報酬のレア依頼だ。")
		elseif currentJobTypeId == "rush" then
			showToast("⚡ 急ぎ便！ 短い制限時間で届けよう。")
		else
			showToast("荷物を受け取った。黄色く光る家へ届けよう。")
		end
	elseif action == "JobRouteChosen" then
		hideCoreRouteChoice()
		routeHint.Text = "ルート選択済み。黄色い目印の配達先へ向かおう。"
		expiresAt = payload.expiresAt
		jobLabel.Text ..= "  •  " .. (payload.routeTitle or "選択ルート")
		if payload.routeId == "shortcut" then
			showToast(string.format(
				"裏路地の近道を選択。時間内なら追加 +%d Coins！",
				tonumber(payload.reward) or 0
			))
		else
			showToast("街灯の道を選択。時間に余裕を持って配達しよう。")
		end
	elseif action == "TravelEventStarted" then
		if payload.blocking == true then
			blockingTravelObjectiveActive = true
			targetLabel.Text = "道中イベント: " .. tostring(payload.title or "通行止め")
			if currentHighlight then currentHighlight.Enabled = false end
			if currentBillboard then currentBillboard.Enabled = false end
		end
	elseif action == "TravelEventResolved" or action == "TravelEventExpired" then
		if payload.blocking == true and blockingTravelObjectiveActive and currentHouseName then
			blockingTravelObjectiveActive = false
			if not destinationEventObjectiveActive then
				targetLabel.Text = "配達先: " .. (currentDisplayName or currentHouseName)
			end
		end
	elseif action == "Delivered" then
		hideCoreRouteChoice()
		routeHint.Text = "荷物を受け取った。先に配達ルートを選ぼう。"
		local bonusText = ""
		if (payload.streakBonus or 0) > 0 then
			bonusText = string.format("  連続 +%d", payload.streakBonus)
		end

		if (payload.routeBonus or 0) > 0 then
			bonusText ..= string.format("  近道 +%d", payload.routeBonus)
		end
		if (payload.destinationEventBonus or 0) > 0 then
			bonusText ..= string.format("  現場判断 +%d", payload.destinationEventBonus)
		end
		if (payload.sideRequestBonus or 0) > 0 then
			bonusText ..= string.format("  追加便 +%d", payload.sideRequestBonus)
		end
		if (payload.walkingBonus or 0) > 0 then
			bonusText ..= string.format("  🚶 徒歩 +%d", payload.walkingBonus)
		end
		if (payload.neighborhoodCallbackBonus or 0) > 0 then
			bonusText ..= string.format("  つながり +%d", payload.neighborhoodCallbackBonus)
		end
		if (payload.oddityBonus or 0) > 0 then
			bonusText ..= string.format("  +%d", payload.oddityBonus)
		end

		local unlockText = ""
		if payload.districtUnlocked then
			unlockText = "  🌉 川沿い地区 解放！"
		elseif payload.specialJobsUnlocked then
			unlockText = "  🟣 深夜特別便 解放！"
		elseif payload.warehouseUnlocked then
			unlockText = "  🏭 倉庫街 解放！"
		end

		local extraText = ""
		if (payload.weatherBonus or 0) > 0 then
			extraText ..= string.format("  天候+%d", payload.weatherBonus)
		end
		if (payload.nightConditionBonus or 0) > 0 then
			extraText ..= string.format("  🎆 今夜+%d", payload.nightConditionBonus)
		end
		if (payload.coopBonus or 0) > 0 then
			extraText ..= string.format("  協力+%d", payload.coopBonus)
		end
		if (payload.neighborhoodTip or 0) > 0 then
			extraText ..= string.format("  🌙 ご近所チップ +%d", payload.neighborhoodTip)
		end
		if (payload.shiftBonus or 0) > 0 then
			extraText ..= string.format("  夜勤+%d", payload.shiftBonus)
		end
		if (payload.neighborhoodKindnessGained or 0) > 0 then
			extraText ..= string.format(
				"  🤝 街の信頼 +%d（合計%d）",
				payload.neighborhoodKindnessGained,
				payload.neighborhoodKindness or 0
			)
		end

		shiftProgress = payload.shiftProgress or shiftProgress
		shiftTarget = payload.shiftTarget or shiftTarget
		currentRankName = payload.rankName or currentRankName
		if payload.oddityId then
			showToast("配達完了")
		else
			showToast(string.format("配達完了！ +%d Coins%s%s%s", payload.reward or 0, bonusText, extraText, unlockText))
		end

		blockingTravelObjectiveActive = false
		destinationEventObjectiveActive = false
		activeJobWeatherName = nil
		activeJobWeatherMultiplier = nil
		currentHouseName = nil
		currentDisplayName = nil
		currentDistrictName = nil
		currentJobTypeName = nil
		currentJobTypeId = nil
		expiresAt = nil

		if payload.hasNextStops then
			targetLabel.Text = "追加配達先を選ぼう"
			jobLabel.Text = "バッグ内の次の配達先を選択"
		else
			targetLabel.Text = "配達所で次の荷物を受け取ろう"
			jobLabel.Text = "通常便 / 速達便 / 遠距離便 / 深夜特別便"
		end
		jobLabel.TextColor3 = Color3.fromRGB(157, 190, 225)
		timerLabel.Text = ""
		clearWaypoint()
		updateStats()
	elseif action == "BikeMode" then
		bikeActive = payload.active == true
		updateStats()
		if bikeActive then
			showToast("🚲 自転車ON。速く着いて時間ボーナスを狙おう。")
		else
			showToast("🚶 徒歩モード。時間内に届ければ徒歩手当あり。")
		end
	elseif action == "SpeedUpgraded" then
		showToast(string.format("速度Lv.%d に強化！", payload.level or 0))
	elseif action == "AssistReward" then
		showToast(string.format("🤝 %s の配達を手伝った！ +%d Coins", payload.playerName or "誰か", payload.reward or 0))
	elseif action == "DestinationEventObjective" then
		destinationEventObjectiveActive = true
		targetLabel.Text = "指定された場所へ届ける"
		if currentHighlight then currentHighlight.Enabled = false end
		if currentBillboard then currentBillboard.Enabled = false end
	elseif action == "WeatherChanged" then
		currentWeatherName = payload.weatherName or "晴れ"
		currentWeatherMultiplier = payload.rewardMultiplier or 1
		updateWeatherVisual()
		updateStats()
		if currentHouseName then
			showToast(string.format(
				"%sになった。今の依頼は受注時倍率のまま。次の依頼は x%.2f",
				currentWeatherName,
				currentWeatherMultiplier
			))
		elseif currentWeatherMultiplier > 1 then
			showToast(string.format("%sになった。次の依頼は報酬 x%.2f", currentWeatherName, currentWeatherMultiplier))
		end
	elseif action == "ShopOpened" then
		shopFrame.Visible = true
		deliveryEvent:FireServer("RequestShopState")
	elseif action == "ShopState" then
		shopCoins.Text = string.format("Coins %d", payload.coins or 0)
		if (payload.speedCost or 0) > 0 then
			speedButton.Text = string.format("🚲 速度 Lv.%d → Lv.%d  /  %d Coins", payload.speedLevel or 0, (payload.speedLevel or 0) + 1, payload.speedCost)
		else
			speedButton.Text = "🚲 速度強化 MAX"
		end
		if payload.bagNextName then
			bagButton.Text = string.format("📦 バッグ %s → %s  /  %d Coins  ・  荷物枠 %d→%d", payload.bagStyleName or "-", payload.bagNextName, payload.bagCost or 0, payload.bagCapacity or 1, payload.bagNextCapacity or 1)
		else
			bagButton.Text = string.format("📦 バッグ %s  /  荷物枠 %d MAX", payload.bagStyleName or "-", payload.bagCapacity or 1)
		end
		if payload.bikeNextName then
			bikeStyleButton.Text = string.format("🎨 自転車 %s → %s  /  %d Coins", payload.bikeStyleName or "-", payload.bikeNextName, payload.bikeCost or 0)
		else
			bikeStyleButton.Text = string.format("🎨 自転車 %s  /  MAX", payload.bikeStyleName or "-")
		end
	elseif action == "CosmeticPurchased" then
		showToast(string.format("✨ %s を解放！", payload.name or "コスメ"))
	elseif action == "Welcome" then
		currentRankName = payload.rankName or currentRankName
		shiftProgress = payload.shiftProgress or 0
		shiftTarget = payload.shiftTarget or 6
		currentWeatherName = payload.weatherName or currentWeatherName
		currentWeatherMultiplier = payload.weatherMultiplier or currentWeatherMultiplier
		updateWeatherVisual()
		if (payload.deliveries or 0) == 0 then
			showToast("最初は黄色い床で配達を受注。5件で川沿い地区が開くよ。")
		elseif (payload.speedLevel or 0) > 0 then
			showToast(string.format("おかえり！ %s / 速度Lv.%d", currentRankName, payload.speedLevel))
		end
		updateStats()
	elseif action == "Message" then
		showToast(payload.text or "")
	end
end)

deliveryEvent:FireServer("RequestState")

RunService.RenderStepped:Connect(function()
	if currentWeatherName == "雨" then
		local t = os.clock()
		local width = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 400
		local height = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700
		for index, line in ipairs(rainLines) do
			local speed = 260 + (index % 5) * 36
			local y = ((t * speed) + index * 83) % (height + 80) - 40
			local x = ((index * 97) + math.floor(t * 18) * 7) % math.max(width, 1)
			line.Position = UDim2.fromOffset(x, y)
		end
	end

	if expiresAt and currentHouseName then
		local remaining = math.max(0, math.ceil(expiresAt - workspace:GetServerTimeNow()))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local distance = root and currentTargetPart and math.floor((root.Position - currentTargetPart.Position).Magnitude) or nil
		local objectiveActive = blockingTravelObjectiveActive or destinationEventObjectiveActive
		if objectiveActive then
			if currentHighlight then currentHighlight.Enabled = false end
			if currentBillboard then currentBillboard.Enabled = false end
		elseif distance and (
			player:GetAttribute("NightDeliveryNavSoft") == true
			or player:GetAttribute("NightDeliveryNightNavSoft") == true
		) then
			local visible = distance <= 70
			if currentHighlight then currentHighlight.Enabled = visible end
			if currentBillboard then currentBillboard.Enabled = visible end
		elseif distance then
			if currentHighlight then currentHighlight.Enabled = true end
			if currentBillboard then currentBillboard.Enabled = true end
		end
		local distanceText = (not objectiveActive and distance) and string.format("  •  距離 %d", distance) or ""

		timerLabel.Text = string.format("残り %d秒%s", remaining, distanceText)

		if remaining <= 0 then
			timerLabel.Text = "時間切れ" .. distanceText .. "  •  基本報酬"
		end
	end
end)

local function layoutCoreHud()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local width = camera.ViewportSize.X
	local narrow = width < 650
	local cardWidth = math.max(130, math.min(narrow and 172 or 220, math.floor((width - 30) / 2)))
	panel.Size = UDim2.fromOffset(cardWidth, 72)
	statusPanel.Size = UDim2.fromOffset(cardWidth, 76)
	panel.Position = UDim2.fromOffset(8, 10)
	statusPanel.Position = UDim2.new(1, -8, 0, 10)
	statusTitle.TextSize = narrow and 11 or 13
	statsLabel.TextSize = narrow and 10 or 12
	shiftLabel.TextSize = narrow and 10 or 12
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCoreHud)
end
layoutCoreHud()
