-- Dispatch selection lives ahead of the existing JobAssigned / route-choice UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("NightDeliveryEvent")
local JOB_COUNTER_INTERACTION_RANGE = 14
local gui = Instance.new("ScreenGui")
gui.Name = "NightDeliveryDispatch"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(8, 12, 21)
shade.BackgroundTransparency = 0.22
shade.Visible = false
shade.Parent = gui

local board = Instance.new("Frame")
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
board.Size = UDim2.fromOffset(410, 390)
board.BackgroundColor3 = Color3.fromRGB(20, 27, 40)
board.Parent = shade
local boardCorner = Instance.new("UICorner")
boardCorner.CornerRadius = UDim.new(0, 15)
boardCorner.Parent = board
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(410, 390)
limit.Parent = board

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -98, 0, 56)
header.Position = UDim2.fromOffset(12, 5)
header.BackgroundTransparency = 1
header.TextColor3 = Color3.fromRGB(255, 212, 132)
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.TextWrapped = true
header.Text = "DISPATCH BOARD  •  Choose a job"
header.Parent = board

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseOffers"
closeButton.Size = UDim2.fromOffset(72, 38)
closeButton.Position = UDim2.new(1, -82, 0, 12)
closeButton.BackgroundColor3 = Color3.fromRGB(52, 62, 79)
closeButton.TextColor3 = Color3.fromRGB(246, 239, 225)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Text = "戻る ×"
closeButton.Parent = board
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local cards = Instance.new("Frame")
cards.Size = UDim2.new(1, -22, 1, -72)
cards.Position = UDim2.fromOffset(11, 64)
cards.BackgroundTransparency = 1
cards.Parent = board
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 7)
layout.Parent = cards

local currentSerial = nil
local accepting = false
local resize
local function hide()
	shade.Visible = false
	currentSerial = nil
	accepting = false
end

local function closeOffers()
	if not shade.Visible or not currentSerial or accepting then return end
	local serial = currentSerial
	hide()
	event:FireServer("CloseJobOffers", {serial = serial})
end
closeButton.Activated:Connect(closeOffers)

local function label(parent, value, position, size, fontSize, bold)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	text.TextColor3 = Color3.fromRGB(230, 236, 247)
	text.TextSize = fontSize
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = value
	text.Parent = parent
	return text
end

local function show(payload)
	if player:GetAttribute("NightDeliveryHouseName") or player:GetAttribute("JobOffersActive") == false then return end
	if type(payload.offers) ~= "table" or #payload.offers == 0 then return end
	if currentSerial == payload.serial and accepting then return end
	currentSerial = payload.serial
	accepting = false
	header.Text = payload.lastDelivery and "LAST DELIVERY\nChoose your final job." or "DISPATCH BOARD  •  Choose a job"
	for _, child in ipairs(cards:GetChildren()) do
		if child ~= layout then child:Destroy() end
	end
	local count = math.min(3, #payload.offers)
	for index = 1, count do
		local offer = payload.offers[index]
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 96)
		card.BackgroundColor3 = Color3.fromRGB(34, 44, 61)
		card.LayoutOrder = index
		card.Parent = cards
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = card
		label(card, tostring(offer.location or "Residential"), UDim2.fromOffset(11, 5), UDim2.new(1, -115, 0, 22), 15, true)
		local rewardText = string.format("%d Coins", tonumber(offer.baseReward) or 0)
		if (tonumber(offer.cargoReward) or 0) > 0 then
			rewardText ..= string.format(" + 条件%d", tonumber(offer.cargoReward) or 0)
		end
		label(card, string.format("%s  •  %s", rewardText, tostring(offer.distance or "Near")),
			UDim2.fromOffset(11, 31), UDim2.new(1, -115, 0, 20), 13, true)
		local detailText = string.format("%s  •  %s", tostring(offer.cargo or "Normal"), tostring(offer.difficulty or "Easy"))
		if (tonumber(offer.walkingBonus) or 0) > 0 then
			detailText ..= string.format("  •  徒歩+%d", tonumber(offer.walkingBonus) or 0)
		end
		label(card, detailText,
			UDim2.fromOffset(11, 56), UDim2.new(1, -115, 0, 20), 12, false)
		local accept = Instance.new("TextButton")
		accept.Size = UDim2.new(0, 90, 0, 44)
		accept.Position = UDim2.new(1, -101, 0.5, -22)
		accept.BackgroundColor3 = Color3.fromRGB(240, 183, 89)
		accept.TextColor3 = Color3.fromRGB(18, 24, 34)
		accept.Font = Enum.Font.GothamBold
		accept.TextSize = 13
		accept.Text = "ACCEPT"
		accept.Parent = card
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 7)
		buttonCorner.Parent = accept
		accept.Activated:Connect(function()
			if accepting or currentSerial ~= payload.serial then return end
			accepting = true
			accept.Text = "..."
			event:FireServer("AcceptJobOffer", {offerId = offer.id})
			-- A failed delivery of the remote may be retried at the Depot; no free reroll.
			task.delay(2, function()
				if currentSerial == payload.serial and player:GetAttribute("JobOffersActive") == true then
					accepting = false
					accept.Text = "ACCEPT"
				end
			end)
		end)
	end
	shade.Visible = true
	resize()
end

resize = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local height = math.min(390, math.max(250, viewport.Y - 48))
	board.Size = UDim2.fromOffset(math.min(410, math.max(240, viewport.X - 24)), height)
	-- Fit all three buttons on small portrait screens without a scroll view.
	local cardHeight = math.floor((height - 72 - 14) / 3)
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("Frame") then child.Size = UDim2.new(1, 0, 0, cardHeight) end
	end
end

-- Walking away only cancels the preview; the server still validates proximity on accept.
local distanceCheck = 0
RunService.Heartbeat:Connect(function(dt)
	if not shade.Visible or accepting then return end
	distanceCheck += dt
	if distanceCheck < 0.5 then return end
	distanceCheck = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("NightDeliveryWorld")
	local depot = world and world:FindFirstChild("Depot")
	local pad = depot and depot:FindFirstChild("JobCounter", true)
	if root and pad and (root.Position - pad.Position).Magnitude > JOB_COUNTER_INTERACTION_RANGE then closeOffers() end
end)

local function requestPending()
	if player:GetAttribute("JobOffersActive") == true then
		event:FireServer("RequestJobOffers")
	else
		hide()
	end
end

player:GetAttributeChangedSignal("JobOffersActive"):Connect(requestPending)
event.OnClientEvent:Connect(function(action, payload)
	if action == "JobOffers" then show(type(payload) == "table" and payload or {})
	elseif action == "JobOfferRejected" and shade.Visible then
		accepting = false
		header.Text = (player:GetAttribute("NightShiftPhase") == "FinalRun" and "LAST DELIVERY\n" or "DISPATCH BOARD\n")
			.. tostring(type(payload) == "table" and payload.reason or "Depotで仕事を選ぼう。")
		for _, card in ipairs(cards:GetChildren()) do
			if card:IsA("Frame") then
				local button = card:FindFirstChildOfClass("TextButton")
				if button then button.Text = "ACCEPT" end
			end
		end
	elseif action == "JobAssigned" or action == "NightShiftComplete" then hide() end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end
resize()
task.defer(requestPending)
