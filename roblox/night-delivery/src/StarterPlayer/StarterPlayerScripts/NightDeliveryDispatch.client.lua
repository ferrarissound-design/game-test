-- Dispatch selection lives ahead of the existing JobAssigned / route-choice UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("NightDeliveryEvent")
local SHIFT_RULES = require(ReplicatedStorage:WaitForChild("NightDeliveryShiftRules"))
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
board.Size = UDim2.fromOffset(410, 520)
board.BackgroundColor3 = Color3.fromRGB(20, 27, 40)
board.Parent = shade
local boardCorner = Instance.new("UICorner")
boardCorner.CornerRadius = UDim.new(0, 15)
boardCorner.Parent = board
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(410, 520)
limit.Parent = board

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -98, 0, 56)
header.Position = UDim2.fromOffset(12, 5)
header.BackgroundTransparency = 1
header.TextColor3 = Color3.fromRGB(255, 212, 132)
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.TextWrapped = true
header.Text = "DISPATCH BOARD\n配達を選ぼう"
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

local equipmentPanel = Instance.new("Frame")
equipmentPanel.Size = UDim2.new(1, -22, 0, 100)
equipmentPanel.Position = UDim2.fromOffset(11, 64)
equipmentPanel.BackgroundTransparency = 1
equipmentPanel.Parent = board

local cards = Instance.new("ScrollingFrame")
cards.Size = UDim2.new(1, -22, 1, -180)
cards.Position = UDim2.fromOffset(11, 170)
cards.BackgroundTransparency = 1
cards.BorderSizePixel = 0
cards.ScrollBarThickness = 5
cards.AutomaticCanvasSize = Enum.AutomaticSize.Y
cards.CanvasSize = UDim2.fromOffset(0, 0)
cards.ScrollingDirection = Enum.ScrollingDirection.Y
cards.Parent = board
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 7)
layout.Parent = cards

local currentSerial = nil
local accepting = false
local selectedEquipment = SHIFT_RULES.DefaultEquipment
local equipmentLocked = false
local equipmentButtons = {}
local fitLabels = {}
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

local DISTANCE_LABELS = {
	Near = "近い",
	Far = "遠い",
}

local DIFFICULTY_LABELS = {
	Easy = "★☆☆ かんたん",
	Normal = "★★☆ ふつう",
	Difficult = "★★★ むずかしい",
	Story = "★ おはなし",
}

local function localizedDistance(value)
	return DISTANCE_LABELS[tostring(value)] or tostring(value or "近い")
end

local function localizedDifficulty(value)
	return DIFFICULTY_LABELS[tostring(value)] or tostring(value or "かんたん")
end

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

local equipmentHint = label(equipmentPanel, "", UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 48), 12, false)
equipmentHint.TextWrapped = true
equipmentHint.TextTruncate = Enum.TextTruncate.None
local function refreshEquipment()
	local entry = SHIFT_RULES.equipment(selectedEquipment) or SHIFT_RULES.equipment(SHIFT_RULES.DefaultEquipment)
	equipmentHint.Text = (equipmentLocked and "夜勤中は固定：" or "最初の受注で確定：") .. entry.description
	for id, button in pairs(equipmentButtons) do
		button.BackgroundColor3 = id == selectedEquipment and Color3.fromRGB(93, 128, 99) or Color3.fromRGB(48, 59, 77)
		button.Text = (id == selectedEquipment and "✓ " or "") .. SHIFT_RULES.equipment(id).name
		button.Active = not equipmentLocked and not accepting
		button.AutoButtonColor = button.Active
	end
	for text, cargoId in pairs(fitLabels) do
		text.Text = entry.cargo[cargoId] and ("装備が有効：" .. entry.name) or ""
	end
end
for index, entry in ipairs(SHIFT_RULES.Equipment) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1 / 3, -4, 0, 44)
	button.Position = UDim2.new((index - 1) / 3, 2, 0, 0)
	button.TextSize = 12
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(245, 243, 229)
	button.Parent = equipmentPanel
	equipmentButtons[entry.id] = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Activated:Connect(function()
		if equipmentLocked or accepting then return end
		selectedEquipment = entry.id
		refreshEquipment()
	end)
end

local function show(payload)
	if player:GetAttribute("NightDeliveryHouseName") or player:GetAttribute("JobOffersActive") == false then return end
	if type(payload.offers) ~= "table" or #payload.offers == 0 then return end
	if currentSerial == payload.serial and accepting then return end
	local samePreview = currentSerial == payload.serial
	equipmentLocked = payload.equipmentLocked == true
	if equipmentLocked or not samePreview then
		selectedEquipment = SHIFT_RULES.equipment(payload.equipmentId) and payload.equipmentId or SHIFT_RULES.DefaultEquipment
	end
	currentSerial = payload.serial
	accepting = false
	header.Text = payload.lastDelivery and "LAST DELIVERY\n最後の配達を選ぼう" or "DISPATCH BOARD\n配達を選ぼう"
	for _, child in ipairs(cards:GetChildren()) do
		if child ~= layout then child:Destroy() end
	end
	table.clear(fitLabels)
	if not samePreview then cards.CanvasPosition = Vector2.new(0, 0) end
	local count = math.min(3, #payload.offers)
	for index = 1, count do
		local offer = payload.offers[index]
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 116)
		card.BackgroundColor3 = Color3.fromRGB(34, 44, 61)
		card.LayoutOrder = index
		card.Parent = cards
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = card
		label(card, tostring(offer.location or "住宅街"), UDim2.fromOffset(11, 5), UDim2.new(1, -115, 0, 22), 15, true)
		local rewardText = string.format("%d コイン", tonumber(offer.baseReward) or 0)
		if (tonumber(offer.cargoReward) or 0) > 0 then
			rewardText ..= string.format(" + 条件%d", tonumber(offer.cargoReward) or 0)
		end
		label(card, string.format("%s  •  %s", rewardText, localizedDistance(offer.distance)),
			UDim2.fromOffset(11, 31), UDim2.new(1, -115, 0, 20), 13, true)
		local detailText = string.format("%s  •  %s", tostring(offer.cargo or "通常"), localizedDifficulty(offer.difficulty))
		if (tonumber(offer.walkingBonus) or 0) > 0 then
			detailText ..= string.format("  •  徒歩+%d", tonumber(offer.walkingBonus) or 0)
		end
		label(card, detailText,
			UDim2.fromOffset(11, 56), UDim2.new(1, -115, 0, 20), 12, false)
		local fit = label(card, "", UDim2.fromOffset(11, 84), UDim2.new(1, -20, 0, 22), 12, true)
		fit.TextColor3 = Color3.fromRGB(165, 218, 164)
		fitLabels[fit] = tostring(offer.cargoId or "none")
		local accept = Instance.new("TextButton")
		accept.Size = UDim2.new(0, 90, 0, 44)
		accept.Position = UDim2.new(1, -101, 0.5, -22)
		accept.BackgroundColor3 = Color3.fromRGB(240, 183, 89)
		accept.TextColor3 = Color3.fromRGB(18, 24, 34)
		accept.Font = Enum.Font.GothamBold
		accept.TextSize = 13
		accept.Text = "これにする"
		accept.Parent = card
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 7)
		buttonCorner.Parent = accept
		accept.Activated:Connect(function()
			if accepting or currentSerial ~= payload.serial then return end
			accepting = true
			refreshEquipment()
			accept.Text = "..."
			event:FireServer("AcceptJobOffer", {offerId = offer.id, equipmentId = selectedEquipment})
			-- A failed delivery of the remote may be retried at the Depot; no free reroll.
			task.delay(2, function()
				if currentSerial == payload.serial and player:GetAttribute("JobOffersActive") == true then
					accepting = false
					refreshEquipment()
					accept.Text = "これにする"
				end
			end)
		end)
	end
	refreshEquipment()
	shade.Visible = true
	resize()
end

resize = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local height = math.min(520, math.max(250, viewport.Y - 48))
	board.Size = UDim2.fromOffset(math.min(410, math.max(240, viewport.X - 24)), height)
	-- Fixed touch targets; short screens scroll the offers instead of shrinking them.
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
		refreshEquipment()
		header.Text = (player:GetAttribute("NightShiftPhase") == "FinalRun" and "LAST DELIVERY\n" or "DISPATCH BOARD\n")
			.. tostring(type(payload) == "table" and payload.reason or "Depotで仕事を選ぼう。")
		for _, card in ipairs(cards:GetChildren()) do
			if card:IsA("Frame") then
				local button = card:FindFirstChildOfClass("TextButton")
				if button then button.Text = "これにする" end
			end
		end
	elseif action == "JobAssigned" or action == "NightShiftComplete" then hide() end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end
resize()
task.defer(requestPending)
