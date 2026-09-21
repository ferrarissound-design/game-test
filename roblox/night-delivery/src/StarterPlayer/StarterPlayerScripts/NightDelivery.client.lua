-- Night Delivery v3
-- StarterPlayer/StarterPlayerScripts/NightDelivery.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local deliveryEvent = ReplicatedStorage:WaitForChild("NightDeliveryEvent")

local RIVERSIDE_UNLOCK_DELIVERIES = 5
local SPECIAL_JOB_UNLOCK_DELIVERIES = 8

local currentHouseName = nil
local currentDisplayName = nil
local currentDistrictName = nil
local currentJobTypeName = nil
local currentJobTypeId = nil
local expiresAt = nil
local currentHighlight = nil
local currentBillboard = nil
local bikeActive = false

local gui = Instance.new("ScreenGui")
gui.Name = "NightDeliveryUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "DeliveryPanel"
panel.Size = UDim2.fromOffset(360, 176)
panel.Position = UDim2.new(0.5, -180, 0, 18)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 176)
sizeConstraint.MaxSize = Vector2.new(380, 176)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(97, 140, 180)
stroke.Transparency = 0.35
stroke.Thickness = 1.4
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 28)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "🌙 静かな夜間配達"
title.TextColor3 = Color3.fromRGB(232, 241, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -24, 0, 25)
targetLabel.Position = UDim2.fromOffset(12, 39)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "配達所で荷物を受け取ろう"
targetLabel.TextColor3 = Color3.fromRGB(210, 219, 232)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 17
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = panel

local jobLabel = Instance.new("TextLabel")
jobLabel.Size = UDim2.new(1, -24, 0, 22)
jobLabel.Position = UDim2.fromOffset(12, 66)
jobLabel.BackgroundTransparency = 1
jobLabel.Text = "通常便 / 速達便 / 遠距離便"
jobLabel.TextColor3 = Color3.fromRGB(157, 190, 225)
jobLabel.Font = Enum.Font.GothamMedium
jobLabel.TextSize = 15
jobLabel.TextXAlignment = Enum.TextXAlignment.Left
jobLabel.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -24, 0, 22)
timerLabel.Position = UDim2.fromOffset(12, 90)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 219, 138)
timerLabel.Font = Enum.Font.GothamMedium
timerLabel.TextSize = 15
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = panel

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -24, 0, 23)
statsLabel.Position = UDim2.fromOffset(12, 117)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "Coins 0  •  配達 0  •  🚲 OFF"
statsLabel.TextColor3 = Color3.fromRGB(190, 206, 220)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 14
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Parent = panel

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -24, 0, 22)
progressLabel.Position = UDim2.fromOffset(12, 143)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "川沿い地区まであと5件"
progressLabel.TextColor3 = Color3.fromRGB(145, 207, 184)
progressLabel.Font = Enum.Font.GothamMedium
progressLabel.TextSize = 14
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = panel

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(360, 58)
toast.Position = UDim2.new(0.5, -180, 1, -92)
toast.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(245, 248, 255)
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 17
toast.TextWrapped = true
toast.BorderSizePixel = 0
toast.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = toast

local guide = Instance.new("TextLabel")
guide.Size = UDim2.fromOffset(330, 46)
guide.Position = UDim2.new(0.5, -165, 1, -148)
guide.BackgroundColor3 = Color3.fromRGB(28, 34, 44)
guide.BackgroundTransparency = 0.18
guide.TextColor3 = Color3.fromRGB(215, 226, 238)
guide.Font = Enum.Font.Gotham
guide.TextSize = 14
guide.TextWrapped = true
guide.Text = "配達所: 受注 / 青い床: 自転車 / 紫の床: 速度強化"
guide.BorderSizePixel = 0
guide.Parent = gui

local guideCorner = Instance.new("UICorner")
guideCorner.CornerRadius = UDim.new(0, 10)
guideCorner.Parent = guide

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
	billboard.Size = UDim2.fromOffset(185, 48)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = body
	billboard.Parent = body
	currentBillboard = billboard

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	label.BackgroundTransparency = 0.1
	label.Text = "📦 " .. (currentDisplayName or "配達先")
	label.TextColor3 = Color3.fromRGB(255, 236, 170)
	label.TextScaled = true
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
	local bikeText = bikeActive and "🚲 ON" or "🚲 OFF"

	statsLabel.Text = string.format("Coins %d  •  配達 %d  •  %s", coinText, deliveryText, bikeText)

	if deliveryText < RIVERSIDE_UNLOCK_DELIVERIES then
		local remaining = RIVERSIDE_UNLOCK_DELIVERIES - deliveryText
		progressLabel.Text = string.format("🌉 川沿い地区まであと%d件", remaining)
		progressLabel.TextColor3 = Color3.fromRGB(145, 207, 184)
	elseif deliveryText < SPECIAL_JOB_UNLOCK_DELIVERIES then
		local remaining = SPECIAL_JOB_UNLOCK_DELIVERIES - deliveryText
		progressLabel.Text = string.format("🌉 川沿い地区 解放済み  •  特別便まであと%d件", remaining)
		progressLabel.TextColor3 = Color3.fromRGB(151, 201, 230)
	else
		progressLabel.Text = "🌉 川沿い地区 解放済み  •  🟣 深夜特別便 解放済み"
		progressLabel.TextColor3 = Color3.fromRGB(197, 157, 238)
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
		currentHouseName = payload.houseName
		currentDisplayName = payload.displayName
		currentDistrictName = payload.districtName
		currentJobTypeName = payload.jobTypeName
		currentJobTypeId = payload.jobTypeId
		expiresAt = payload.expiresAt

		targetLabel.Text = "配達先: " .. (currentDisplayName or currentHouseName)
		jobLabel.Text = string.format(
			"%s  •  %s  •  基本報酬 %d",
			currentDistrictName or "住宅街",
			currentJobTypeName or "配達",
			payload.baseReward or 0
		)
		jobLabel.TextColor3 = currentJobTypeId == "special"
			and Color3.fromRGB(214, 156, 255)
			or Color3.fromRGB(157, 190, 225)

		setWaypoint(currentHouseName)
		if currentJobTypeId == "special" then
			showToast("🟣 深夜特別便！ 高報酬のレア依頼だ。")
		else
			showToast("荷物を受け取った。黄色く光る家へ届けよう。")
		end
	elseif action == "Delivered" then
		local bonusText = ""
		if (payload.streakBonus or 0) > 0 then
			bonusText = string.format("  連続 +%d", payload.streakBonus)
		end

		local unlockText = ""
		if payload.districtUnlocked then
			unlockText = "  🌉 川沿い地区 解放！"
		elseif payload.specialJobsUnlocked then
			unlockText = "  🟣 深夜特別便 解放！"
		end

		showToast(string.format("配達完了！ +%d Coins%s%s", payload.reward or 0, bonusText, unlockText))

		currentHouseName = nil
		currentDisplayName = nil
		currentDistrictName = nil
		currentJobTypeName = nil
		currentJobTypeId = nil
		expiresAt = nil

		targetLabel.Text = "配達所で次の荷物を受け取ろう"
		jobLabel.Text = "通常便 / 速達便 / 遠距離便 / 深夜特別便"
		jobLabel.TextColor3 = Color3.fromRGB(157, 190, 225)
		timerLabel.Text = ""
		clearWaypoint()
	elseif action == "BikeMode" then
		bikeActive = payload.active == true
		updateStats()
		if bikeActive then
			showToast("🚲 自転車モードON。移動速度アップ！")
		else
			showToast("自転車モードOFF。")
		end
	elseif action == "SpeedUpgraded" then
		showToast(string.format("速度Lv.%d に強化！", payload.level or 0))
	elseif action == "Welcome" then
		if (payload.speedLevel or 0) > 0 then
			showToast(string.format("おかえり！ 速度Lv.%d", payload.speedLevel))
		end
		updateStats()
	elseif action == "Message" then
		showToast(payload.text or "")
	end
end)

RunService.RenderStepped:Connect(function()
	if expiresAt and currentHouseName then
		local remaining = math.max(0, math.ceil(expiresAt - workspace:GetServerTimeNow()))
		timerLabel.Text = string.format("残り %d秒  •  早いほどボーナス", remaining)

		if remaining <= 0 then
			timerLabel.Text = "時間切れ  •  基本報酬で配達可能"
		end
	end
end)
