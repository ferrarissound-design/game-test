-- Night Delivery client
-- Put this LocalScript in StarterPlayer > StarterPlayerScripts
-- if you are not using Rojo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local deliveryEvent = ReplicatedStorage:WaitForChild("NightDeliveryEvent")

local currentHouseName = nil
local expiresAt = nil
local currentHighlight = nil
local currentBillboard = nil

local gui = Instance.new("ScreenGui")
gui.Name = "NightDeliveryUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "DeliveryPanel"
panel.Size = UDim2.fromOffset(330, 112)
panel.Position = UDim2.new(0.5, -165, 0, 22)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

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
title.Position = UDim2.fromOffset(12, 10)
title.BackgroundTransparency = 1
title.Text = "🌙 静かな夜間配達"
title.TextColor3 = Color3.fromRGB(232, 241, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -24, 0, 28)
targetLabel.Position = UDim2.fromOffset(12, 42)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "配達所で荷物を受け取ろう"
targetLabel.TextColor3 = Color3.fromRGB(210, 219, 232)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 17
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -24, 0, 24)
timerLabel.Position = UDim2.fromOffset(12, 76)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 219, 138)
timerLabel.Font = Enum.Font.GothamMedium
timerLabel.TextSize = 16
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = panel

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(360, 54)
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

local function showToast(text)
	toast.Text = text
	TweenService:Create(toast, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.14,
		TextTransparency = 0,
	}):Play()

	task.delay(2.5, function()
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
	billboard.Size = UDim2.fromOffset(170, 46)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = body
	billboard.Parent = body
	currentBillboard = billboard

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	label.BackgroundTransparency = 0.12
	label.Text = "📦 配達先"
	label.TextColor3 = Color3.fromRGB(255, 236, 170)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
end

deliveryEvent.OnClientEvent:Connect(function(action, payload)
	if action == "JobAssigned" then
		currentHouseName = payload.houseName
		expiresAt = payload.expiresAt
		targetLabel.Text = "配達先: " .. currentHouseName
		setWaypoint(currentHouseName)
		showToast("荷物を受け取った。黄色く光る家へ届けよう。")
	elseif action == "Delivered" then
		showToast(string.format("配達完了！ +%d Coins", payload.reward))
		currentHouseName = nil
		expiresAt = nil
		targetLabel.Text = "配達所で次の荷物を受け取ろう"
		timerLabel.Text = ""
		clearWaypoint()
	elseif action == "Message" then
		showToast(payload.text or "")
	end
end)

RunService.RenderStepped:Connect(function()
	if expiresAt and currentHouseName then
		local remaining = math.max(0, math.ceil(expiresAt - workspace:GetServerTimeNow()))
		timerLabel.Text = string.format("残り %d秒  •  早いほどボーナス", remaining)

		if remaining <= 0 then
			timerLabel.Text = "時間切れでも配達OK  •  基本報酬のみ"
		end
	end
end)
