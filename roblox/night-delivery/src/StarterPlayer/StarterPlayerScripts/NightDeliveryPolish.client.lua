-- Night Delivery Release Candidate client polish layer
-- Navigation compass, order modifier UI, session missions, onboarding and delivery results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local deliveryEvent = ReplicatedStorage:WaitForChild("NightDeliveryEvent")
local DogAppearance = require(ReplicatedStorage:WaitForChild("NightDeliveryDogAppearance"))

local currentTarget = nil
local currentHouseName = nil
local currentDisplayName = nil
local currentJobTypeId = nil
local currentJobTypeName = nil
local orderStartedAt = nil
local orderExpiresAt = nil
local currentModifier = nil
local pendingRouteSerial = nil
local modifierRequestGeneration = 0
local eventObjectivePart = nil
local eventObjectiveSerial = nil
local eventObjectiveReady = false
local eventObjectiveNavTitle = nil
local eventHazardTriggered = false
local travelEventPart = nil
local travelObstacle = nil
local travelEventSerial = nil
local travelEventBlocking = false
local travelEventExpiresAt = nil
local travelEventResolving = false
local travelEventBaseBody = ""
local travelEventReward = 0
local travelEventMessageSerial = 0
local resultSerial = 0
local rumorSerial = 0

local gui = Instance.new("ScreenGui")
gui.Name = "NightDeliveryReleaseUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(122, 142, 175)
	stroke.Transparency = transparency or 0.4
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
end

local function makeLabel(parent, size, position, text, textSize, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = Color3.fromRGB(234, 240, 248)
	label.TextSize = textSize or 14
	label.Font = font or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

-- Top-center navigation. It deliberately occupies the empty center of the HUD,
-- leaving the v4 left/right panels untouched.
local navFrame = Instance.new("Frame")
navFrame.Name = "Navigation"
navFrame.Size = UDim2.fromOffset(300, 64)
navFrame.AnchorPoint = Vector2.new(0.5, 0)
navFrame.Position = UDim2.new(0.5, 0, 0, 12)
navFrame.BackgroundColor3 = Color3.fromRGB(18, 23, 33)
navFrame.BackgroundTransparency = 0.16
navFrame.Visible = false
navFrame.Parent = gui
addCorner(navFrame, 14)
addStroke(navFrame, Color3.fromRGB(110, 164, 214), 0.28, 1.2)

local navConstraint = Instance.new("UISizeConstraint")
navConstraint.MinSize = Vector2.new(230, 58)
navConstraint.MaxSize = Vector2.new(340, 68)
navConstraint.Parent = navFrame

local arrow = makeLabel(navFrame, UDim2.fromOffset(54, 54), UDim2.fromOffset(8, 5), "▲", 31, Enum.Font.GothamBold)
arrow.TextXAlignment = Enum.TextXAlignment.Center
arrow.TextColor3 = Color3.fromRGB(255, 212, 104)

local navTitle = makeLabel(navFrame, UDim2.new(1, -68, 0, 28), UDim2.fromOffset(65, 6), "配達先", 14, Enum.Font.GothamBold)
navTitle.TextColor3 = Color3.fromRGB(245, 248, 255)

local navDistance = makeLabel(navFrame, UDim2.new(1, -68, 0, 24), UDim2.fromOffset(65, 33), "", 12, Enum.Font.Gotham)
navDistance.TextColor3 = Color3.fromRGB(160, 185, 212)

local nightBadge = Instance.new("Frame")
nightBadge.Name = "NightConditionBadge"
nightBadge.Size = UDim2.fromOffset(250, 52)
nightBadge.AnchorPoint = Vector2.new(1, 0)
nightBadge.Position = UDim2.new(1, -14, 0, 12)
nightBadge.BackgroundColor3 = Color3.fromRGB(22, 28, 39)
nightBadge.BackgroundTransparency = 0.12
nightBadge.Visible = false
nightBadge.Parent = gui
addCorner(nightBadge, 10)
addStroke(nightBadge, Color3.fromRGB(118, 159, 196), 0.5, 1)
local nightName = makeLabel(nightBadge, UDim2.new(1, -18, 0, 22), UDim2.fromOffset(9, 4), "", 12, Enum.Font.GothamBold)
local nightDescription = makeLabel(nightBadge, UDim2.new(1, -18, 0, 22), UDim2.fromOffset(9, 26), "", 10, Enum.Font.Gotham)
nightDescription.TextColor3 = Color3.fromRGB(182, 198, 218)

-- A compact shift clock sits below the top HUD; the center remains navigation space.
local shiftHud = Instance.new("TextLabel")
shiftHud.Name = "NightShiftHud"
shiftHud.Size = UDim2.fromOffset(152, 38)
shiftHud.Position = UDim2.fromOffset(10, 82)
shiftHud.BackgroundColor3 = Color3.fromRGB(20, 26, 37)
shiftHud.BackgroundTransparency = 0.12
shiftHud.TextColor3 = Color3.fromRGB(255, 220, 144)
shiftHud.Font = Enum.Font.GothamBold
shiftHud.TextSize = 12
shiftHud.Visible = false
shiftHud.ZIndex = 25
shiftHud.Parent = gui
addCorner(shiftHud, 9)

local shiftBanner = makeLabel(gui, UDim2.new(0.8, 0, 0, 50), UDim2.new(0.1, 0, 0.27, 0), "", 24, Enum.Font.GothamBlack)
shiftBanner.TextXAlignment = Enum.TextXAlignment.Center
shiftBanner.TextColor3 = Color3.fromRGB(255, 211, 120)
shiftBanner.TextStrokeTransparency = 0.2
shiftBanner.ZIndex = 85
shiftBanner.Visible = false
local bannerSerial = 0
local function announceShift(message)
	bannerSerial += 1
	local serial = bannerSerial
	shiftBanner.Text = message
	shiftBanner.Visible = true
	task.delay(2.3, function()
		if serial == bannerSerial then shiftBanner.Visible = false end
	end)
end

local shiftResult = Instance.new("Frame")
shiftResult.Name = "NightShiftResult"
shiftResult.Size = UDim2.fromOffset(340, 340)
shiftResult.AnchorPoint = Vector2.new(0.5, 0.5)
shiftResult.Position = UDim2.fromScale(0.5, 0.5)
shiftResult.BackgroundColor3 = Color3.fromRGB(19, 25, 36)
shiftResult.Visible = false
shiftResult.ZIndex = 90
shiftResult.Parent = gui
addCorner(shiftResult, 16)
addStroke(shiftResult, Color3.fromRGB(255, 209, 113), 0.1, 2)
local shiftText = makeLabel(shiftResult, UDim2.new(1, -24, 1, -86), UDim2.fromOffset(12, 10), "", 16, Enum.Font.GothamBold)
shiftText.TextWrapped = true
shiftText.TextYAlignment = Enum.TextYAlignment.Top
shiftText.ZIndex = 91
local shiftClose = Instance.new("TextButton")
shiftClose.Size = UDim2.new(1, -32, 0, 50)
shiftClose.Position = UDim2.new(0, 16, 1, -62)
shiftClose.Text = "次の夜勤へ（配達所で受注）"
shiftClose.TextSize = 15
shiftClose.Font = Enum.Font.GothamBold
shiftClose.BackgroundColor3 = Color3.fromRGB(186, 137, 65)
shiftClose.TextColor3 = Color3.fromRGB(18, 24, 34)
shiftClose.ZIndex = 91
shiftClose.Parent = shiftResult
addCorner(shiftClose, 10)
local shiftAcknowledgePending = false
shiftClose.Activated:Connect(function()
	if shiftAcknowledgePending then return end
	shiftAcknowledgePending = true
	shiftClose.Active = false
	shiftClose.Text = "確認中..."
	deliveryEvent:FireServer("AcknowledgeNightShift")
	task.delay(2, function()
		if shiftAcknowledgePending and player:GetAttribute("NightShiftResultPending") == true then
			shiftAcknowledgePending = false
			shiftClose.Active = true
			shiftClose.Text = "次の夜勤へ（配達所で受注）"
		end
	end)
end)
player:GetAttributeChangedSignal("NightShiftResultPending"):Connect(function()
	if shiftAcknowledgePending and player:GetAttribute("NightShiftResultPending") == false then
		shiftAcknowledgePending = false
		shiftResult.Visible = false
		shiftClose.Active = true
		shiftClose.Text = "次の夜勤へ（配達所で受注）"
	end
end)

local phaseTimes = {EarlyNight = "20:30", MidNight = "22:30", LateNight = "0:00", FinalRun = "1:30"}
local phaseTitles = {MidNight = "MID NIGHT", LateNight = "LATE NIGHT", FinalRun = "LAST DELIVERY"}
local lastPhase = nil
local function updateShiftHud()
	local active = player:GetAttribute("NightShiftActive") == true
	shiftHud.Visible = active
	if not active then return end
	local count = player:GetAttribute("NightShiftDeliveries") or 0
	local target = player:GetAttribute("NightShiftTarget") or 6
	local phase = player:GetAttribute("NightShiftPhase") or "EarlyNight"
	shiftHud.Text = string.format("SHIFT %d / %d   %s", math.min(count + 1, target), target, phaseTimes[phase] or "20:30")
	if lastPhase and phase ~= lastPhase and phaseTitles[phase] then
		announceShift(phaseTitles[phase] .. "  " .. (phaseTimes[phase] or ""))
	end
	lastPhase = phase
end
for _, name in ipairs({"NightShiftActive", "NightShiftDeliveries", "NightShiftTarget", "NightShiftPhase"}) do
	player:GetAttributeChangedSignal(name):Connect(updateShiftHud)
end
updateShiftHud()

-- Session mission card.
local missionFrame = Instance.new("Frame")
missionFrame.Name = "SessionMission"
missionFrame.Size = UDim2.fromOffset(255, 82)
missionFrame.AnchorPoint = Vector2.new(1, 1)
missionFrame.Position = UDim2.new(1, -14, 1, -54)
missionFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
missionFrame.BackgroundTransparency = 0.13
missionFrame.Parent = gui
addCorner(missionFrame, 12)
addStroke(missionFrame, Color3.fromRGB(112, 128, 155), 0.5, 1)

local missionHeader = makeLabel(missionFrame, UDim2.new(1, -18, 0, 24), UDim2.fromOffset(10, 6), "セッション目標", 12, Enum.Font.GothamBold)
missionHeader.TextColor3 = Color3.fromRGB(168, 183, 209)

local missionName = makeLabel(missionFrame, UDim2.new(1, -18, 0, 24), UDim2.fromOffset(10, 27), "読み込み中...", 14, Enum.Font.GothamBold)
local missionProgress = makeLabel(missionFrame, UDim2.new(1, -18, 0, 20), UDim2.fromOffset(10, 52), "", 12, Enum.Font.Gotham)
missionProgress.TextColor3 = Color3.fromRGB(255, 215, 126)

local missionScale = Instance.new("UIScale")
missionScale.Scale = 1
missionScale.Parent = missionFrame

-- Active order modifier. This is intentionally compact and only appears during a delivery.
local modifierFrame = Instance.new("Frame")
modifierFrame.Name = "OrderModifier"
modifierFrame.Size = UDim2.fromOffset(270, 72)
modifierFrame.AnchorPoint = Vector2.new(0, 1)
modifierFrame.Position = UDim2.new(0, 14, 1, -54)
modifierFrame.BackgroundColor3 = Color3.fromRGB(29, 24, 39)
modifierFrame.BackgroundTransparency = 0.1
modifierFrame.Visible = false
modifierFrame.Parent = gui
addCorner(modifierFrame, 12)
addStroke(modifierFrame, Color3.fromRGB(167, 121, 215), 0.3, 1.2)

local modifierTitle = makeLabel(modifierFrame, UDim2.new(1, -18, 0, 27), UDim2.fromOffset(10, 7), "通常依頼", 14, Enum.Font.GothamBold)
modifierTitle.TextColor3 = Color3.fromRGB(225, 190, 255)
local modifierDescription = makeLabel(modifierFrame, UDim2.new(1, -18, 0, 31), UDim2.fromOffset(10, 34), "", 12, Enum.Font.Gotham)
modifierDescription.TextWrapped = true
modifierDescription.TextColor3 = Color3.fromRGB(204, 208, 222)

-- Result splash. It is short-lived so it does not interrupt the next job.
local resultFrame = Instance.new("Frame")
resultFrame.Name = "DeliveryResult"
resultFrame.Size = UDim2.fromOffset(360, 190)
resultFrame.AnchorPoint = Vector2.new(0.5, 0.5)
resultFrame.Position = UDim2.fromScale(0.5, 0.5)
resultFrame.BackgroundColor3 = Color3.fromRGB(17, 21, 31)
resultFrame.BackgroundTransparency = 1
resultFrame.Visible = false
resultFrame.ZIndex = 40
resultFrame.Parent = gui
addCorner(resultFrame, 18)
local resultStroke = addStroke(resultFrame, Color3.fromRGB(255, 211, 107), 1, 2)

local resultGrade = makeLabel(resultFrame, UDim2.new(1, -24, 0, 70), UDim2.fromOffset(12, 10), "S", 52, Enum.Font.GothamBlack)
resultGrade.TextXAlignment = Enum.TextXAlignment.Center
resultGrade.TextTransparency = 1
resultGrade.ZIndex = 41

local resultTitle = makeLabel(resultFrame, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 76), "配達完了", 18, Enum.Font.GothamBold)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
resultTitle.TextTransparency = 1
resultTitle.ZIndex = 41

local resultBreakdown = makeLabel(resultFrame, UDim2.new(1, -30, 0, 66), UDim2.fromOffset(15, 108), "", 13, Enum.Font.Gotham)
resultBreakdown.TextXAlignment = Enum.TextXAlignment.Center
resultBreakdown.TextYAlignment = Enum.TextYAlignment.Top
resultBreakdown.TextWrapped = true
resultBreakdown.TextTransparency = 1
resultBreakdown.ZIndex = 41

local resultScale = Instance.new("UIScale")
resultScale.Scale = 0.88
resultScale.Parent = resultFrame

-- First-session introduction. Keep it visible until the player starts a job or closes it.
local introFrame = Instance.new("Frame")
introFrame.Name = "Intro"
introFrame.Size = UDim2.fromOffset(440, 154)
introFrame.AnchorPoint = Vector2.new(0.5, 1)
introFrame.Position = UDim2.new(0.5, 0, 1, -46)
introFrame.BackgroundColor3 = Color3.fromRGB(17, 23, 34)
introFrame.BackgroundTransparency = 0.06
introFrame.Visible = false
introFrame.ZIndex = 30
introFrame.Parent = gui
addCorner(introFrame, 14)
addStroke(introFrame, Color3.fromRGB(98, 150, 197), 0.35, 1.2)

local introTitle = makeLabel(introFrame, UDim2.new(1, -54, 0, 26), UDim2.fromOffset(12, 8), "最初の配達：やることは3つ", 16, Enum.Font.GothamBold)
introTitle.TextColor3 = Color3.fromRGB(173, 215, 255)

local introClose = Instance.new("TextButton")
introClose.Name = "CloseIntro"
introClose.Size = UDim2.fromOffset(28, 28)
introClose.Position = UDim2.new(1, -36, 0, 4)
introClose.BackgroundTransparency = 1
introClose.Text = "×"
introClose.TextColor3 = Color3.fromRGB(185, 198, 216)
introClose.TextSize = 22
introClose.Font = Enum.Font.Gotham
introClose.ZIndex = 31
introClose.Parent = introFrame
introClose.Activated:Connect(function()
	introFrame.Visible = false
end)

local introBody = makeLabel(
	introFrame,
	UDim2.new(1, -24, 0, 94),
	UDim2.fromOffset(12, 38),
	"① 黄色い受付で受注 → 矢印を追って玄関へ\n② PC: WASDで移動・Eで操作 / スマホ: 左スティック・画面ボタン\n③ 制限時間はボーナス用。時間切れでも配達OK\n自転車は受付横のスタンドで切替（PC: B）",
	13,
	Enum.Font.Gotham
)
introBody.TextWrapped = true
introBody.TextYAlignment = Enum.TextYAlignment.Top
introBody.TextColor3 = Color3.fromRGB(220, 228, 239)

local introHint = makeLabel(introFrame, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 132), "配達3件で最初のセッション報酬", 11, Enum.Font.Gotham)
introHint.TextColor3 = Color3.fromRGB(255, 208, 116)

-- Route choice pauses the order timer until the player picks a plan.
local routeChoiceFrame = Instance.new("Frame")
routeChoiceFrame.Name = "RouteChoice"
routeChoiceFrame.Size = UDim2.fromOffset(430, 190)
routeChoiceFrame.AnchorPoint = Vector2.new(0.5, 0.5)
routeChoiceFrame.Position = UDim2.fromScale(0.5, 0.5)
routeChoiceFrame.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
routeChoiceFrame.BackgroundTransparency = 0.04
routeChoiceFrame.Visible = false
routeChoiceFrame.ZIndex = 80
routeChoiceFrame.Parent = gui
addCorner(routeChoiceFrame, 16)
addStroke(routeChoiceFrame, Color3.fromRGB(110, 164, 214), 0.25, 1.4)

local routeChoiceTitle = makeLabel(routeChoiceFrame, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 10), "どのルートで届ける？", 18, Enum.Font.GothamBold)
routeChoiceTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
routeChoiceTitle.ZIndex = 81

local routeChoiceHint = makeLabel(routeChoiceFrame, UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 42), "選んだルートで制限時間と追加報酬が変わるよ。", 12, Enum.Font.Gotham)
routeChoiceHint.TextColor3 = Color3.fromRGB(190, 204, 224)
routeChoiceHint.ZIndex = 81

local lanternRouteButton = Instance.new("TextButton")
lanternRouteButton.Name = "LanternRoute"
lanternRouteButton.Size = UDim2.new(0.5, -18, 0, 90)
lanternRouteButton.Position = UDim2.fromOffset(12, 82)
lanternRouteButton.BackgroundColor3 = Color3.fromRGB(54, 71, 83)
lanternRouteButton.Text = "街灯の道\n時間に余裕\n追加報酬なし"
lanternRouteButton.TextColor3 = Color3.fromRGB(238, 244, 250)
lanternRouteButton.TextSize = 14
lanternRouteButton.TextWrapped = true
lanternRouteButton.Font = Enum.Font.GothamBold
lanternRouteButton.ZIndex = 81
lanternRouteButton.Parent = routeChoiceFrame
addCorner(lanternRouteButton, 10)

local shortcutRouteButton = Instance.new("TextButton")
shortcutRouteButton.Name = "ShortcutRoute"
shortcutRouteButton.Size = UDim2.new(0.5, -18, 0, 90)
shortcutRouteButton.Position = UDim2.new(0.5, 6, 0, 82)
shortcutRouteButton.BackgroundColor3 = Color3.fromRGB(103, 70, 51)
shortcutRouteButton.Text = "裏路地の近道\n制限時間短め\n成功で追加報酬"
shortcutRouteButton.TextColor3 = Color3.fromRGB(255, 239, 219)
shortcutRouteButton.TextSize = 14
shortcutRouteButton.TextWrapped = true
shortcutRouteButton.Font = Enum.Font.GothamBold
shortcutRouteButton.ZIndex = 81
shortcutRouteButton.Parent = routeChoiceFrame
addCorner(shortcutRouteButton, 10)

local function submitRouteChoice(routeId)
	if not routeChoiceFrame.Visible or not pendingRouteSerial then
		return
	end
	lanternRouteButton.Active = false
	shortcutRouteButton.Active = false
	deliveryEvent:FireServer("ChooseRoute", {
		jobSerial = pendingRouteSerial,
		routeId = routeId,
	})
end

lanternRouteButton.Activated:Connect(function()
	submitRouteChoice("lantern")
end)
shortcutRouteButton.Activated:Connect(function()
	submitRouteChoice("shortcut")
end)

-- Modifier details are informational only. A delayed response must never
-- prevent the player from choosing a route and starting the delivery.
local function requestOrderModifier(jobSerial)
	modifierRequestGeneration += 1
	local generation = modifierRequestGeneration

	local function request(attempt)
		if generation ~= modifierRequestGeneration
			or tonumber(pendingRouteSerial) ~= tonumber(jobSerial)
			or currentModifier then
			return
		end
		deliveryEvent:FireServer("PolishRequestOrderModifier", {
			jobSerial = jobSerial,
		})
		if attempt < 3 then
			task.delay(0.45, function()
				request(attempt + 1)
			end)
		end
	end

	request(1)
end

-- Story clue card appears after a delivery milestone.
local rumorFrame = Instance.new("Frame")
rumorFrame.Name = "NeighborhoodRumor"
rumorFrame.Size = UDim2.fromOffset(440, 144)
rumorFrame.AnchorPoint = Vector2.new(0.5, 0)
rumorFrame.Position = UDim2.new(0.5, 0, 0, 12)
rumorFrame.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
rumorFrame.BackgroundTransparency = 1
rumorFrame.Visible = false
rumorFrame.ZIndex = 50
rumorFrame.Parent = gui
addCorner(rumorFrame, 14)
local rumorStroke = addStroke(rumorFrame, Color3.fromRGB(255, 207, 120), 1, 1.4)

local rumorKicker = makeLabel(rumorFrame, UDim2.new(1, -58, 0, 20), UDim2.fromOffset(12, 7), "街のうわさ", 11, Enum.Font.GothamBold)
rumorKicker.TextColor3 = Color3.fromRGB(255, 207, 120)
rumorKicker.ZIndex = 51

local rumorClose = Instance.new("TextButton")
rumorClose.Name = "CloseRumor"
rumorClose.Size = UDim2.fromOffset(28, 28)
rumorClose.Position = UDim2.new(1, -36, 0, 4)
rumorClose.BackgroundTransparency = 1
rumorClose.Text = "×"
rumorClose.TextColor3 = Color3.fromRGB(185, 198, 216)
rumorClose.TextSize = 22
rumorClose.Font = Enum.Font.Gotham
rumorClose.ZIndex = 52
rumorClose.Parent = rumorFrame

local rumorTitle = makeLabel(rumorFrame, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 29), "", 16, Enum.Font.GothamBold)
rumorTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
rumorTitle.ZIndex = 51

local rumorBody = makeLabel(rumorFrame, UDim2.new(1, -24, 0, 62), UDim2.fromOffset(12, 55), "", 13, Enum.Font.Gotham)
rumorBody.TextWrapped = true
rumorBody.TextYAlignment = Enum.TextYAlignment.Top
rumorBody.TextColor3 = Color3.fromRGB(220, 228, 239)
rumorBody.ZIndex = 51

local rumorReward = makeLabel(rumorFrame, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 120), "", 11, Enum.Font.GothamMedium)
rumorReward.TextColor3 = Color3.fromRGB(255, 215, 126)
rumorReward.ZIndex = 51

rumorClose.Activated:Connect(function()
	rumorSerial += 1
	rumorFrame.Visible = false
end)

local townRevealShown = false
local townRevealActive = false

local townReveal = Instance.new("Frame")
townReveal.Name = "TownReveal"
townReveal.Size = UDim2.fromScale(1, 1)
townReveal.Position = UDim2.fromScale(0, 0)
townReveal.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
townReveal.BackgroundTransparency = 1
townReveal.Visible = false
townReveal.ZIndex = 60
townReveal.Parent = gui

local townKicker = makeLabel(townReveal, UDim2.new(1, -40, 0, 28), UDim2.new(0, 20, 0.5, -74), "今夜の街", 14, Enum.Font.GothamBold)
townKicker.TextXAlignment = Enum.TextXAlignment.Center
townKicker.TextColor3 = Color3.fromRGB(177, 191, 211)
townKicker.TextTransparency = 1
townKicker.ZIndex = 61

local townTitle = makeLabel(townReveal, UDim2.new(1, -40, 0, 58), UDim2.new(0, 20, 0.5, -42), "", 34, Enum.Font.GothamBlack)
townTitle.TextXAlignment = Enum.TextXAlignment.Center
townTitle.TextColor3 = Color3.fromRGB(244, 247, 252)
townTitle.TextTransparency = 1
townTitle.ZIndex = 61

local townSubtitle = makeLabel(townReveal, UDim2.new(1, -56, 0, 42), UDim2.new(0, 28, 0.5, 24), "", 13, Enum.Font.Gotham)
townSubtitle.TextXAlignment = Enum.TextXAlignment.Center
townSubtitle.TextWrapped = true
townSubtitle.TextColor3 = Color3.fromRGB(178, 191, 207)
townSubtitle.TextTransparency = 1
townSubtitle.ZIndex = 61

local themeSubtitles = {
	japanese = "静かな住宅街。狭い道と玄関灯を頼りに走れ。",
	western = "広い通りとポーチの灯り。距離を読んで最短を狙え。",
	showa = "古い街灯と電柱が残る夜。路地を見落とすな。",
	luxury = "広い道路と大きな邸宅。門の先が配達地点だ。",
	harbor = "雨と海風の港町。濡れた路面の向こうへ急げ。",
	mountain = "霧の山間集落。灯りの少ない道を慎重に進め。",
	danchi = "似た建物が並ぶ団地。棟と位置をよく見ろ。",
}

local function showTownReveal()
	if townRevealShown then
		return
	end
	townRevealShown = true

	local world = workspace:FindFirstChild("NightDeliveryWorld") or workspace:WaitForChild("NightDeliveryWorld", 12)
	if not world then
		return
	end

	local themeName = world:GetAttribute("ThemeName") or "夜の街"
	local themeId = world:GetAttribute("ThemeId") or ""
	townTitle.Text = tostring(themeName)
	townSubtitle.Text = themeSubtitles[themeId] or "今夜も街のどこかで、荷物を待つ家がある。"

	townRevealActive = true
	townReveal.Visible = true
	townReveal.BackgroundTransparency = 1
	townKicker.TextTransparency = 1
	townTitle.TextTransparency = 1
	townSubtitle.TextTransparency = 1

	TweenService:Create(townReveal, TweenInfo.new(0.4), {BackgroundTransparency = 0.28}):Play()
	TweenService:Create(townKicker, TweenInfo.new(0.42), {TextTransparency = 0}):Play()
	TweenService:Create(townTitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	TweenService:Create(townSubtitle, TweenInfo.new(0.55), {TextTransparency = 0}):Play()

	task.delay(2.35, function()
		TweenService:Create(townKicker, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(townTitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(townSubtitle, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
		local fade = TweenService:Create(townReveal, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		fade:Play()
		fade.Completed:Wait()
		townReveal.Visible = false
		townRevealActive = false
	end)
end

local function showIntro()
	introFrame.Visible = true
	introFrame.BackgroundTransparency = 1
	introFrame.Position = UDim2.new(0.5, 0, 1, 20)
	TweenService:Create(introFrame, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.06,
		Position = UDim2.new(0.5, 0, 1, -46),
	}):Play()
end

local function showRumor(payload)
	rumorSerial += 1
	local serial = rumorSerial
	local chapter = math.clamp(tonumber(payload.chapter) or 1, 1, tonumber(payload.total) or 4)
	local total = math.max(1, tonumber(payload.total) or 4)

	rumorKicker.Text = string.format("街のうわさ  %d / %d", chapter, total)
	rumorTitle.Text = tostring(payload.title or "新しい手がかり")
	rumorBody.Text = tostring(payload.text or "")
	local reward = math.max(0, tonumber(payload.reward) or 0)
	rumorReward.Text = reward > 0 and string.format("全てのうわさを解明！ +%d Coins", reward) or "配達を続けると、街の謎が少しずつ見えてくる。"

	rumorFrame.Visible = true
	rumorFrame.BackgroundTransparency = 1
	rumorFrame.Position = UDim2.new(0.5, 0, 0, -12)
	rumorStroke.Transparency = 1
	for _, label in ipairs({rumorKicker, rumorTitle, rumorBody, rumorReward}) do
		label.TextTransparency = 1
	end

	TweenService:Create(rumorFrame, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.06,
		Position = UDim2.new(0.5, 0, 0, 12),
	}):Play()
	TweenService:Create(rumorStroke, TweenInfo.new(0.24), {Transparency = 0.15}):Play()
	for _, label in ipairs({rumorKicker, rumorTitle, rumorBody, rumorReward}) do
		TweenService:Create(label, TweenInfo.new(0.24), {TextTransparency = 0}):Play()
	end

	task.delay(8, function()
		if serial ~= rumorSerial then
			return
		end
		TweenService:Create(rumorFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(rumorStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		for _, label in ipairs({rumorKicker, rumorTitle, rumorBody, rumorReward}) do
			TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		end
		task.wait(0.32)
		if serial == rumorSerial then
			rumorFrame.Visible = false
		end
	end)
end

local residentSerial = 0
local residentFrame = Instance.new("Frame")
residentFrame.Name = "ResidentDialogue"
residentFrame.Size = UDim2.fromOffset(420, 94)
residentFrame.AnchorPoint = Vector2.new(0.5, 1)
residentFrame.Position = UDim2.new(0.5, 0, 1, -22)
residentFrame.BackgroundColor3 = Color3.fromRGB(20, 29, 35)
residentFrame.BackgroundTransparency = 1
residentFrame.Visible = false
residentFrame.ZIndex = 45
residentFrame.Parent = gui
addCorner(residentFrame, 13)
local residentStroke = addStroke(residentFrame, Color3.fromRGB(131, 205, 174), 1, 1.3)
local residentNameLabel = makeLabel(residentFrame, UDim2.new(1, -26, 0, 24), UDim2.fromOffset(14, 10), "", 14, Enum.Font.GothamBold)
residentNameLabel.TextColor3 = Color3.fromRGB(154, 220, 185)
residentNameLabel.ZIndex = 46
local residentLineLabel = makeLabel(residentFrame, UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 38), "", 13, Enum.Font.Gotham)
residentLineLabel.TextWrapped = true
residentLineLabel.TextYAlignment = Enum.TextYAlignment.Top
residentLineLabel.ZIndex = 46

local function showResident(payload)
	residentSerial += 1
	local serial = residentSerial
	local callbackTitle = tostring(payload.neighborhoodCallbackTitle or "")
	if callbackTitle ~= "" then
		residentNameLabel.Text = string.format("%s  ・  %s", tostring(payload.residentName or "住人"), callbackTitle)
		residentNameLabel.TextColor3 = Color3.fromRGB(255, 213, 130)
		residentStroke.Color = Color3.fromRGB(237, 184, 94)
	else
		residentNameLabel.Text = tostring(payload.residentName or "住人")
		residentNameLabel.TextColor3 = Color3.fromRGB(154, 220, 185)
		residentStroke.Color = Color3.fromRGB(131, 205, 174)
	end
	residentLineLabel.Text = tostring(payload.residentReaction or "配達ありがとう。")
	residentFrame.Visible = true
	residentFrame.BackgroundTransparency = 1
	residentStroke.Transparency = 1
	TweenService:Create(residentFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.06}):Play()
	TweenService:Create(residentStroke, TweenInfo.new(0.2), {Transparency = 0.18}):Play()
	for _, label in ipairs({residentNameLabel, residentLineLabel}) do
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
	end
	task.delay(5, function()
		if serial ~= residentSerial then
			return
		end
		TweenService:Create(residentFrame, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
		TweenService:Create(residentStroke, TweenInfo.new(0.25), {Transparency = 1}):Play()
		for _, label in ipairs({residentNameLabel, residentLineLabel}) do
			TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		end
		task.wait(0.27)
		if serial == residentSerial then
			residentFrame.Visible = false
		end
	end)
end

local destinationEventFrame = Instance.new("Frame")
destinationEventFrame.Name = "DestinationEventChoice"
destinationEventFrame.Size = UDim2.fromOffset(430, 176)
destinationEventFrame.AnchorPoint = Vector2.new(0.5, 0.5)
destinationEventFrame.Position = UDim2.new(0.5, 0, 0.52, 0)
destinationEventFrame.BackgroundColor3 = Color3.fromRGB(25, 31, 42)
destinationEventFrame.Visible = false
destinationEventFrame.ZIndex = 70
destinationEventFrame.Parent = gui
addCorner(destinationEventFrame, 14)
addStroke(destinationEventFrame, Color3.fromRGB(255, 205, 119), 0.18, 1.5)
local destinationEventTitle = makeLabel(destinationEventFrame, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 10), "", 16, Enum.Font.GothamBold)
destinationEventTitle.ZIndex = 71
local destinationEventBody = makeLabel(destinationEventFrame, UDim2.new(1, -24, 0, 48), UDim2.fromOffset(12, 40), "", 13, Enum.Font.Gotham)
destinationEventBody.TextWrapped = true
destinationEventBody.TextYAlignment = Enum.TextYAlignment.Top
destinationEventBody.ZIndex = 71

local function makeEventChoiceButton(name, xOffset, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0.46, 0, 0, 44)
	button.Position = UDim2.new(xOffset, 0, 1, -54)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(245, 248, 255)
	button.TextSize = 13
	button.Font = Enum.Font.GothamBold
	button.TextWrapped = true
	button.ZIndex = 71
	button.Parent = destinationEventFrame
	addCorner(button, 10)
	return button
end

local quickEventButton = makeEventChoiceButton("QuickChoice", 0.04, Color3.fromRGB(57, 86, 113))
local carefulEventButton = makeEventChoiceButton("CarefulChoice", 0.50, Color3.fromRGB(54, 112, 91))
local destinationEventSerial = nil
local destinationChoicePending = false

local function submitDestinationEvent(choice)
	if not destinationEventSerial or destinationChoicePending then
		return
	end
	local jobSerial = destinationEventSerial
	destinationChoicePending = true
	quickEventButton.Active = false
	carefulEventButton.Active = false
	deliveryEvent:FireServer("ResolveDestinationEvent", {
		jobSerial = jobSerial,
		choice = choice,
	})
	task.delay(1.5, function()
		if destinationChoicePending and destinationEventSerial == jobSerial
			and destinationEventFrame.Visible then
			destinationChoicePending = false
			quickEventButton.Active = true
			carefulEventButton.Active = true
		end
	end)
end

quickEventButton.Activated:Connect(function()
	submitDestinationEvent("quick")
end)
carefulEventButton.Activated:Connect(function()
	submitDestinationEvent("careful")
end)

local eventObjectiveFrame = Instance.new("Frame")
eventObjectiveFrame.Name = "DestinationEventObjective"
eventObjectiveFrame.Size = UDim2.fromOffset(410, 116)
eventObjectiveFrame.AnchorPoint = Vector2.new(0.5, 1)
eventObjectiveFrame.Position = UDim2.new(0.5, 0, 1, -34)
eventObjectiveFrame.BackgroundColor3 = Color3.fromRGB(22, 31, 38)
eventObjectiveFrame.BackgroundTransparency = 0.05
eventObjectiveFrame.Visible = false
eventObjectiveFrame.ZIndex = 72
eventObjectiveFrame.Parent = gui
addCorner(eventObjectiveFrame, 13)
addStroke(eventObjectiveFrame, Color3.fromRGB(126, 220, 178), 0.16, 1.4)

local eventObjectiveTitle = makeLabel(eventObjectiveFrame, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), "届ける場所が変わった", 14, Enum.Font.GothamBold)
eventObjectiveTitle.TextColor3 = Color3.fromRGB(151, 230, 193)
eventObjectiveTitle.ZIndex = 73
local eventObjectiveBody = makeLabel(eventObjectiveFrame, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 34), "", 12, Enum.Font.Gotham)
eventObjectiveBody.TextWrapped = true
eventObjectiveBody.ZIndex = 73

local eventObjectiveButton = Instance.new("TextButton")
eventObjectiveButton.Name = "CompleteEventObjective"
eventObjectiveButton.Size = UDim2.new(1, -24, 0, 34)
eventObjectiveButton.Position = UDim2.new(0, 12, 1, -42)
eventObjectiveButton.BackgroundColor3 = Color3.fromRGB(54, 112, 91)
eventObjectiveButton.TextColor3 = Color3.fromRGB(245, 248, 255)
eventObjectiveButton.TextSize = 12
eventObjectiveButton.Font = Enum.Font.GothamBold
eventObjectiveButton.Text = "指定位置へ移動しよう"
eventObjectiveButton.Active = false
eventObjectiveButton.AutoButtonColor = false
eventObjectiveButton.ZIndex = 73
eventObjectiveButton.Parent = eventObjectiveFrame
addCorner(eventObjectiveButton, 9)

local function clearEventObjective()
	eventHazardTriggered = false
	if eventObjectivePart then
		if currentTarget == eventObjectivePart then
			currentTarget = nil
		end
		eventObjectivePart:Destroy()
		eventObjectivePart = nil
	end
	eventObjectiveSerial = nil
	eventObjectiveReady = false
	eventObjectiveNavTitle = nil
	eventObjectiveFrame.Visible = false
end

local function showEventObjective(payload)
	clearEventObjective()
	if typeof(payload.position) ~= "Vector3" then
		return
	end

	eventObjectiveSerial = tonumber(payload.jobSerial)
	eventHazardTriggered = false
	local part = Instance.new("Part")
	part.Name = "LocalDestinationEventObjective"
	part.Size = Vector3.new(4.5, 0.28, 4.5)
	part.Position = payload.position + Vector3.new(0, 0.14, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(111, 225, 170)
	part.Transparency = 0.18
	part.Parent = workspace
	eventObjectivePart = part

	local marker = Instance.new("BillboardGui")
	marker.Name = "EventObjectiveMarker"
	marker.Size = UDim2.fromOffset(190, 42)
	marker.StudsOffset = Vector3.new(0, 3.2, 0)
	marker.AlwaysOnTop = true
	marker.Adornee = part
	marker.Parent = part
	local markerText = makeLabel(marker, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), "ここに届ける", 13, Enum.Font.GothamBold)
	markerText.TextXAlignment = Enum.TextXAlignment.Center
	markerText.TextColor3 = Color3.fromRGB(236, 255, 246)

	currentTarget = part
	eventObjectiveNavTitle = tostring(payload.label or "指定された場所へ届ける")
	navTitle.Text = eventObjectiveNavTitle
	navFrame.Visible = true
	eventObjectiveTitle.Text = tostring(payload.label or "届ける場所が変わった")
	eventObjectiveTitle.TextColor3 = Color3.fromRGB(151, 230, 193)
	eventObjectiveBody.Text = (tonumber(payload.reward) or 0) > 0
		and string.format("緑の目印まで移動して届けよう。成功で +%d Coins", tonumber(payload.reward) or 0)
		or "緑の目印まで移動して、最後に荷物を置こう。"
	eventObjectiveButton.Text = "指定位置へ移動しよう"
	eventObjectiveButton.Active = false
	eventObjectiveButton.AutoButtonColor = false
	eventObjectiveFrame.Visible = true

	if tostring(payload.eventId or "") == "work" and eventAppearance then
		for _, descendant in ipairs(eventAppearance:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("NightDeliveryObstacle") == true then
				descendant.CanCollide = true
			end
		end
	end
end

eventObjectiveButton.Activated:Connect(function()
	if not eventObjectiveSerial or not eventObjectiveReady then
		return
	end
	eventObjectiveButton.Active = false
	eventObjectiveButton.AutoButtonColor = false
	eventObjectiveButton.Text = "配達を確認中..."
	deliveryEvent:FireServer("CompleteDestinationEventObjective", {
		jobSerial = eventObjectiveSerial,
	})
end)

local sideOfferSerial = 0
local sideOfferHouseName = nil
local sideOfferFrame = Instance.new("Frame")
sideOfferFrame.Name = "SideJobOffer"
sideOfferFrame.Size = UDim2.fromOffset(420, 148)
sideOfferFrame.AnchorPoint = Vector2.new(0.5, 0)
sideOfferFrame.Position = UDim2.new(0.5, 0, 0, 86)
sideOfferFrame.BackgroundColor3 = Color3.fromRGB(24, 35, 42)
sideOfferFrame.Visible = false
sideOfferFrame.ZIndex = 60
sideOfferFrame.Parent = gui
addCorner(sideOfferFrame, 13)
addStroke(sideOfferFrame, Color3.fromRGB(104, 206, 175), 0.18, 1.4)
local sideOfferTitle = makeLabel(sideOfferFrame, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), "近くの追加依頼", 15, Enum.Font.GothamBold)
sideOfferTitle.TextColor3 = Color3.fromRGB(139, 226, 190)
sideOfferTitle.ZIndex = 61
local sideOfferBody = makeLabel(sideOfferFrame, UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 34), "", 12, Enum.Font.Gotham)
sideOfferBody.TextWrapped = true
sideOfferBody.ZIndex = 61
local sideOfferAccept = makeEventChoiceButton("AcceptSideJob", 0.04, Color3.fromRGB(54, 112, 91))
sideOfferAccept.Parent = sideOfferFrame
sideOfferAccept.Text = "受ける"
local sideOfferIgnore = makeEventChoiceButton("IgnoreSideJob", 0.50, Color3.fromRGB(57, 67, 82))
sideOfferIgnore.Parent = sideOfferFrame
sideOfferIgnore.Text = "見送る"

local nextStopFrame = Instance.new("Frame")
nextStopFrame.Name = "NextStopChoice"
nextStopFrame.Size = UDim2.fromOffset(420, 220)
nextStopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
nextStopFrame.Position = UDim2.new(0.5, 0, 0.52, 0)
nextStopFrame.BackgroundColor3 = Color3.fromRGB(25, 31, 42)
nextStopFrame.Visible = false
nextStopFrame.ZIndex = 65
nextStopFrame.Parent = gui
addCorner(nextStopFrame, 14)
addStroke(nextStopFrame, Color3.fromRGB(119, 180, 231), 0.18, 1.4)
local nextStopTitle = makeLabel(nextStopFrame, UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 8), "次はどの家へ？", 16, Enum.Font.GothamBold)
nextStopTitle.ZIndex = 66
local nextStopButtons = {}

local function sendSideJobResponse(accept)
	if not sideOfferHouseName then return end
	deliveryEvent:FireServer(accept and "AcceptSideJob" or "IgnoreSideJob", {
		jobSerial = pendingRouteSerial,
		houseName = sideOfferHouseName,
	})
	sideOfferFrame.Visible = false
	sideOfferHouseName = nil
end
sideOfferAccept.Activated:Connect(function() sendSideJobResponse(true) end)
sideOfferIgnore.Activated:Connect(function() sendSideJobResponse(false) end)

local function showNextStops(payload)
	for _, button in ipairs(nextStopButtons) do button:Destroy() end
	nextStopButtons = {}
	local stops = type(payload.stops) == "table" and payload.stops or {}
	for index, stop in ipairs(stops) do
		local selectedHouseName = tostring(stop.houseName or "")
		local button = Instance.new("TextButton")
		button.Name = "StopChoice" .. index
		button.Size = UDim2.new(1, -24, 0, 46)
		button.Position = UDim2.fromOffset(12, 48 + (index - 1) * 52)
		button.BackgroundColor3 = Color3.fromRGB(48, 69, 90)
		button.TextColor3 = Color3.fromRGB(245, 248, 255)
		button.TextSize = 13
		button.Font = Enum.Font.GothamBold
		button.TextWrapped = true
		button.Active = true
		button.ZIndex = 66
		button.Text = string.format("%s  ・  %d studs  ・  +%d Coins", tostring(stop.displayName or "配達先"), tonumber(stop.distance) or 0, tonumber(stop.reward) or 0)
		button.Parent = nextStopFrame
		addCorner(button, 9)
		button.Activated:Connect(function()
			if not button.Active then return end
			for _, choiceButton in ipairs(nextStopButtons) do choiceButton.Active = false end
			local previousText = button.Text
			button.Text = "確認中..."
			deliveryEvent:FireServer("ChooseNextStop", {
				jobSerial = tonumber(payload.jobSerial),
				houseName = selectedHouseName,
			})
			task.delay(1.5, function()
				if nextStopFrame.Visible and button.Parent then
					if tonumber(player:GetAttribute("NightDeliveryJobSerial")) == tonumber(payload.jobSerial)
						and not player:GetAttribute("NightDeliveryHouseName") then
						button.Text = previousText
						for _, choiceButton in ipairs(nextStopButtons) do choiceButton.Active = true end
					else
						nextStopFrame.Visible = false
					end
				end
			end)
		end)
		table.insert(nextStopButtons, button)
	end
	nextStopFrame.Size = UDim2.fromOffset(420, 54 + (#stops * 52))
	nextStopFrame.Visible = #stops > 0
end

local function showRareAnomaly(payload)
	showRumor({
		chapter = 1,
		total = 1,
		title = tostring(payload.title or "地図にない呼び声"),
		text = tostring(payload.text or "配達を終えたはずの家から、もう一度だけ明かりが点いた。"),
		reward = 0,
	})
	rumorKicker.Text = "めったに起きない異変"
	rumorReward.Text = "次の夜には、何も起きないかもしれない。"
end

local eventAppearance = nil
local hiddenResidentParts = {}

local function clearEventAppearance()
	for instance, previousValue in pairs(hiddenResidentParts) do
		if instance and instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = previousValue
			elseif instance:IsA("BillboardGui") then
				instance.Enabled = previousValue
			end
		end
	end
	table.clear(hiddenResidentParts)
	if eventAppearance then
		eventAppearance:Destroy()
		eventAppearance = nil
	end
end

local function addLocalEventPart(parent, name, size, position, color, shape, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = color
	part.Transparency = transparency or 0
	part.Material = Enum.Material.SmoothPlastic
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

local function addEventBillboard(part, textValue, textColor)
	local marker = Instance.new("BillboardGui")
	marker.Name = "EventWarning"
	marker.Size = UDim2.fromOffset(190, 38)
	marker.StudsOffset = Vector3.new(0, 2.5, 0)
	marker.AlwaysOnTop = true
	marker.Adornee = part
	marker.Parent = part

	local label = makeLabel(marker, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), textValue, 12, Enum.Font.GothamBold)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextColor3 = textColor or Color3.fromRGB(255, 230, 190)
	return marker
end

local function showEventAppearance(eventId)
	clearEventAppearance()
	local world = workspace:FindFirstChild("NightDeliveryWorld")
	local houses = world and world:FindFirstChild("Houses")
	local house = houses and houses:FindFirstChild(currentHouseName or "")
	local point = house and house:FindFirstChild("DeliveryPoint")
	if not house or not point then return end

	eventAppearance = Instance.new("Model")
	eventAppearance.Name = "LocalDeliveryEvent"
	eventAppearance.Parent = workspace
	if eventId == "absent" then
		for _, descendant in ipairs(house:GetDescendants()) do
			if descendant.Name:match("^Resident") then
				if descendant:IsA("BasePart") then
					hiddenResidentParts[descendant] = descendant.LocalTransparencyModifier
					descendant.LocalTransparencyModifier = 1
				elseif descendant:IsA("BillboardGui") then
					hiddenResidentParts[descendant] = descendant.Enabled
					descendant.Enabled = false
				end
			end
		end
		addLocalEventPart(eventAppearance, "ParcelLocker", Vector3.new(2.2, 1.6, 1.4), point.Position + Vector3.new(3.4, 1.05, -0.4), Color3.fromRGB(102, 127, 151))
		addLocalEventPart(eventAppearance, "LockerSlot", Vector3.new(1.2, 0.55, 0.12), point.Position + Vector3.new(3.4, 1.1, -1.16), Color3.fromRGB(37, 47, 58), Enum.PartType.Block)
	elseif eventId == "dog" then
		local dogGroundPosition = point.Position + Vector3.new(6.5, 0.05, 0)
		local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local dogLookTarget = characterRoot and characterRoot.Position or point.Position
		local _, dogBody = DogAppearance.create(eventAppearance, dogGroundPosition, dogLookTarget)
		local alertZone = addLocalEventPart(
			eventAppearance,
			"DogAlertZone",
			Vector3.new(0.08, 6, 6),
			point.Position + Vector3.new(6.5, 0.08, 0),
			Color3.fromRGB(220, 88, 76),
			Enum.PartType.Cylinder,
			0.72
		)
		alertZone.Orientation = Vector3.new(0, 0, 90)
		alertZone.Material = Enum.Material.Neon
		addEventBillboard(dogBody, "⚠ 吠える犬！ 赤い範囲に注意", Color3.fromRGB(255, 190, 170))
	elseif eventId == "work" then
		local barrier = addLocalEventPart(
			eventAppearance,
			"WorkBarrierMain",
			Vector3.new(0.8, 2.4, 8),
			point.Position + Vector3.new(-4.0, 1.2, 1.5),
			Color3.fromRGB(225, 137, 56)
		)
		barrier:SetAttribute("NightDeliveryObstacle", true)
		local guard = addLocalEventPart(
			eventAppearance,
			"WorkBarrierGuard",
			Vector3.new(5.0, 2.4, 0.8),
			point.Position + Vector3.new(-1.8, 1.2, 5.1),
			Color3.fromRGB(226, 170, 62)
		)
		guard:SetAttribute("NightDeliveryObstacle", true)
		addEventBillboard(barrier, "正面通行止め", Color3.fromRGB(255, 222, 151))
		for _, position in ipairs({
			point.Position + Vector3.new(-3.6, 0.85, -3.0),
			point.Position + Vector3.new(-3.6, 0.85, 5.8),
			point.Position + Vector3.new(0.8, 0.85, 4.8),
		}) do
			addLocalEventPart(eventAppearance, "WorkCone", Vector3.new(0.8, 1.2, 0.8), position, Color3.fromRGB(239, 116, 60), Enum.PartType.Block)
		end
	end
end

local function setTarget(houseName, displayName)
	currentTarget = nil
	currentHouseName = houseName
	currentDisplayName = displayName

	local world = workspace:FindFirstChild("NightDeliveryWorld") or workspace:WaitForChild("NightDeliveryWorld", 10)
	local houses = world and world:FindFirstChild("Houses")
	local house = houses and houses:FindFirstChild(houseName)
	local body = house and house:FindFirstChild("Body")
	local deliveryPoint = house and house:FindFirstChild("DeliveryPoint")
	if body then
		currentTarget = deliveryPoint or body
		navTitle.Text = displayName or houseName or "配達先"
		navFrame.Visible = true
	end
end

local function clearTarget()
	currentTarget = nil
	currentHouseName = nil
	currentDisplayName = nil
	navFrame.Visible = false
end

-- The core NightDelivery.client.lua owns the only interactive route chooser.
-- This polish layer still mirrors job state and requests the authoritative cargo
-- modifier, but it must never expose a second ChooseRoute UI.
local lastRecoveredRouteKey = nil

local function ensureRouteChoiceFromAttributes()
	local jobSerial = tonumber(player:GetAttribute("NightDeliveryJobSerial"))
	local houseName = tostring(player:GetAttribute("NightDeliveryHouseName") or "")
	local startedAt = tonumber(player:GetAttribute("NightDeliveryOrderStartedAt"))

	if not jobSerial or jobSerial <= 0 or houseName == "" then
		return
	end

	-- Once the server confirms a route, the timer attribute exists and the
	-- route chooser should stay closed.
	if startedAt then
		if tonumber(pendingRouteSerial) == jobSerial then
			routeChoiceFrame.Visible = false
		end
		return
	end

	pendingRouteSerial = jobSerial

	if currentHouseName ~= houseName or not currentTarget or not currentTarget.Parent then
		local world = workspace:FindFirstChild("NightDeliveryWorld")
		local houses = world and world:FindFirstChild("Houses")
		local house = houses and houses:FindFirstChild(houseName)
		local displayName = house and house:GetAttribute("DisplayName") or houseName
		setTarget(houseName, displayName)
	end

	-- Route selection is intentionally invisible here. Core UI recovers it from
	-- the same Player attributes, while this layer only keeps navigation/modifier state.
	routeChoiceFrame.Visible = false

	local recoveryKey = string.format("%d:%s", jobSerial, houseName)
	if recoveryKey ~= lastRecoveredRouteKey then
		lastRecoveredRouteKey = recoveryKey
		requestOrderModifier(jobSerial)
	end
end

player:GetAttributeChangedSignal("NightDeliveryJobSerial"):Connect(function()
	task.defer(ensureRouteChoiceFromAttributes)
end)
player:GetAttributeChangedSignal("NightDeliveryHouseName"):Connect(function()
	task.defer(ensureRouteChoiceFromAttributes)
end)
player:GetAttributeChangedSignal("NightDeliveryOrderStartedAt"):Connect(function()
	task.defer(ensureRouteChoiceFromAttributes)
end)
task.defer(ensureRouteChoiceFromAttributes)

local travelEventFrame = Instance.new("Frame")
travelEventFrame.Name = "TravelEvent"
travelEventFrame.Size = UDim2.fromOffset(370, 92)
travelEventFrame.AnchorPoint = Vector2.new(0.5, 0)
travelEventFrame.Position = UDim2.new(0.5, 0, 0, 154)
travelEventFrame.BackgroundColor3 = Color3.fromRGB(24, 31, 42)
travelEventFrame.BackgroundTransparency = 0.04
travelEventFrame.Visible = false
travelEventFrame.ZIndex = 58
travelEventFrame.Parent = gui
addCorner(travelEventFrame, 13)
local travelEventStroke = addStroke(travelEventFrame, Color3.fromRGB(237, 184, 94), 0.2, 1.4)

local travelEventTitle = makeLabel(
	travelEventFrame,
	UDim2.new(1, -24, 0, 24),
	UDim2.fromOffset(12, 8),
	"道中イベント",
	14,
	Enum.Font.GothamBold
)
travelEventTitle.TextColor3 = Color3.fromRGB(255, 213, 130)
travelEventTitle.ZIndex = 59

local travelEventBody = makeLabel(
	travelEventFrame,
	UDim2.new(1, -24, 0, 48),
	UDim2.fromOffset(12, 35),
	"",
	11,
	Enum.Font.Gotham
)
travelEventBody.TextWrapped = true
travelEventBody.TextYAlignment = Enum.TextYAlignment.Top
travelEventBody.ZIndex = 59

local function clearTravelEvent(restoreTarget, hideFrame)
	if travelEventPart then
		if currentTarget == travelEventPart then
			currentTarget = nil
		end
		travelEventPart:Destroy()
		travelEventPart = nil
	end
	if travelObstacle then
		travelObstacle:Destroy()
		travelObstacle = nil
	end
	travelEventSerial = nil
	travelEventBlocking = false
	travelEventExpiresAt = nil
	travelEventResolving = false
	travelEventBaseBody = ""
	travelEventReward = 0
	if hideFrame ~= false then
		travelEventFrame.Visible = false
	end
	if restoreTarget then
		if eventObjectivePart and eventObjectivePart.Parent then
			currentTarget = eventObjectivePart
			navTitle.Text = eventObjectiveNavTitle or "指定された場所へ届ける"
			navFrame.Visible = true
		elseif currentHouseName then
			setTarget(currentHouseName, currentDisplayName)
		end
	end
end

local function makeTravelMarker(position, eventId)
	local part = Instance.new("Part")
	part.Name = "LocalTravelEventObjective"
	part.Size = Vector3.new(4.4, 0.24, 4.4)
	part.Position = position + Vector3.new(0, 0.12, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.16
	part.Color = eventId == "roadblock"
		and Color3.fromRGB(244, 184, 76)
		or (eventId == "lost_item" and Color3.fromRGB(103, 184, 235) or Color3.fromRGB(119, 224, 167))
	part.Parent = workspace

	local marker = Instance.new("BillboardGui")
	marker.Name = "TravelEventMarker"
	marker.Size = UDim2.fromOffset(190, 42)
	marker.StudsOffset = Vector3.new(0, 3.0, 0)
	marker.AlwaysOnTop = true
	marker.Adornee = part
	marker.Parent = part
	local markerLabel = makeLabel(
		marker,
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		eventId == "roadblock" and "迂回ポイント" or (eventId == "lost_item" and "落とし物" or "手伝う"),
		13,
		Enum.Font.GothamBold
	)
	markerLabel.TextXAlignment = Enum.TextXAlignment.Center
	markerLabel.TextColor3 = Color3.fromRGB(247, 251, 255)
	return part
end

local function showTravelEvent(payload)
	clearTravelEvent(false, true)
	if typeof(payload.position) ~= "Vector3" then
		return
	end

	local eventId = tostring(payload.id or "")
	travelEventSerial = tonumber(payload.jobSerial)
	travelEventBlocking = payload.blocking == true
	travelEventExpiresAt = tonumber(payload.expiresAt)
	travelEventResolving = false
	travelEventBaseBody = tostring(payload.body or "")
	travelEventReward = math.max(0, tonumber(payload.reward) or 0)
	travelEventPart = makeTravelMarker(payload.position, eventId)

	if travelEventBlocking and typeof(payload.obstaclePosition) == "Vector3" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local targetPosition = currentTarget and currentTarget.Position or payload.position
		local origin = root and root.Position or payload.obstaclePosition
		local direction = targetPosition - origin
		local flatDirection = Vector3.new(direction.X, 0, direction.Z)
		if flatDirection.Magnitude < 0.01 then
			flatDirection = Vector3.new(0, 0, -1)
		else
			flatDirection = flatDirection.Unit
		end

		local barrier = Instance.new("Part")
		barrier.Name = "LocalTravelRoadblock"
		barrier.Size = Vector3.new(12, 2.5, 0.8)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanTouch = false
		barrier.CanQuery = false
		barrier.Material = Enum.Material.Metal
		barrier.Color = Color3.fromRGB(224, 137, 58)
		barrier.CFrame = CFrame.lookAt(
			payload.obstaclePosition + Vector3.new(0, 1.25, 0),
			payload.obstaclePosition + Vector3.new(0, 1.25, 0) + flatDirection
		)
		barrier.Parent = workspace
		travelObstacle = barrier

		local warning = Instance.new("BillboardGui")
		warning.Size = UDim2.fromOffset(180, 38)
		warning.StudsOffset = Vector3.new(0, 2.4, 0)
		warning.AlwaysOnTop = true
		warning.Adornee = barrier
		warning.Parent = barrier
		local warningLabel = makeLabel(warning, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), "通行止め", 13, Enum.Font.GothamBold)
		warningLabel.TextXAlignment = Enum.TextXAlignment.Center
		warningLabel.TextColor3 = Color3.fromRGB(255, 226, 168)

		currentTarget = travelEventPart
		navTitle.Text = "迂回ポイントへ"
		navFrame.Visible = true
	end

	travelEventTitle.Text = tostring(payload.title or "道中イベント")
	if travelEventBlocking then
		travelEventBody.Text = string.format("%s  解決すると +%d Coins", travelEventBaseBody, travelEventReward)
	else
		travelEventBody.Text = string.format("%s  寄り道成功で +%d Coins", travelEventBaseBody, travelEventReward)
	end
	travelEventFrame.Visible = true
end

local function showTravelEventOutcome(titleText, bodyText, restoreTarget)
	travelEventMessageSerial += 1
	local serial = travelEventMessageSerial
	clearTravelEvent(restoreTarget, false)
	travelEventTitle.Text = titleText
	travelEventBody.Text = bodyText
	travelEventFrame.Visible = true
	task.delay(1.7, function()
		if serial == travelEventMessageSerial then
			travelEventFrame.Visible = false
		end
	end)
end

local function updateMissionCard(missions)
	if type(missions) ~= "table" then
		return
	end

	local nextMission = nil
	for _, mission in ipairs(missions) do
		if not mission.completed then
			nextMission = mission
			break
		end
	end

	if not nextMission then
		missionHeader.Text = "今夜の目標"
		missionName.Text = "セッション目標 COMPLETE"
		missionProgress.Text = "15件達成。ここからは自己ベストの夜。"
		missionName.TextColor3 = Color3.fromRGB(255, 215, 126)
		return
	end

	missionName.Text = nextMission.name
	missionName.TextColor3 = Color3.fromRGB(236, 241, 248)
	missionProgress.Text = string.format("%d / %d件  ・  達成 +%d Coins", nextMission.progress or 0, nextMission.target or 0, nextMission.reward or 0)
end

local gradeColors = {
	S = Color3.fromRGB(255, 213, 96),
	A = Color3.fromRGB(116, 211, 172),
	B = Color3.fromRGB(111, 171, 222),
	C = Color3.fromRGB(180, 184, 194),
}

local function showResult(payload)
	resultSerial += 1
	local serial = resultSerial
	local grade = tostring(payload.grade or "C")
	local color = gradeColors[grade] or gradeColors.C

	resultFrame.Visible = true
	resultFrame.BackgroundTransparency = 1
	resultScale.Scale = 0.86
	resultStroke.Transparency = 1
	resultStroke.Color = color
	resultGrade.Text = grade
	resultGrade.TextColor3 = color
	resultGrade.TextTransparency = 1
	resultTitle.TextTransparency = 1
	resultBreakdown.TextTransparency = 1

	local lines = {}
	table.insert(lines, string.format("評価ボーナス +%d", payload.gradeBonus or 0))
	if (payload.modifierBonus or 0) > 0 then
		table.insert(lines, string.format("%s 成功 +%d", payload.modifierTitle or "特殊依頼", payload.modifierBonus))
	elseif payload.modifierId and payload.modifierId ~= "none" then
		table.insert(lines, string.format("%s は条件未達", payload.modifierTitle or "特殊依頼"))
	end
	if (payload.missionBonus or 0) > 0 then
		table.insert(lines, string.format("セッション目標 +%d", payload.missionBonus))
	end
	if #lines == 0 then
		table.insert(lines, "次はもっと速く届けよう")
	end
	resultBreakdown.Text = table.concat(lines, "  /  ")

	TweenService:Create(resultFrame, TweenInfo.new(0.18), {BackgroundTransparency = 0.05}):Play()
	TweenService:Create(resultScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(resultStroke, TweenInfo.new(0.2), {Transparency = 0.15}):Play()
	TweenService:Create(resultGrade, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
	TweenService:Create(resultTitle, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
	TweenService:Create(resultBreakdown, TweenInfo.new(0.18), {TextTransparency = 0}):Play()

	if type(payload.missions) == "table" then
		updateMissionCard(payload.missions)
		TweenService:Create(missionScale, TweenInfo.new(0.12), {Scale = 1.07}):Play()
		task.delay(0.14, function()
			TweenService:Create(missionScale, TweenInfo.new(0.18), {Scale = 1}):Play()
		end)
	end

	task.delay(2.25, function()
		if serial ~= resultSerial then
			return
		end
		local fade = TweenService:Create(resultFrame, TweenInfo.new(0.28), {BackgroundTransparency = 1})
		TweenService:Create(resultStroke, TweenInfo.new(0.28), {Transparency = 1}):Play()
		TweenService:Create(resultGrade, TweenInfo.new(0.22), {TextTransparency = 1}):Play()
		TweenService:Create(resultTitle, TweenInfo.new(0.22), {TextTransparency = 1}):Play()
		TweenService:Create(resultBreakdown, TweenInfo.new(0.22), {TextTransparency = 1}):Play()
		fade:Play()
		fade.Completed:Wait()
		if serial == resultSerial then
			resultFrame.Visible = false
		end
	end)
end

local function showModifier(payload)
	currentModifier = payload
	modifierFrame.Visible = true
	modifierTitle.Text = payload.title or "通常依頼"
	modifierDescription.Text = payload.description or ""
	if (payload.reward or 0) > 0 then
		modifierDescription.Text ..= string.format("  成功 +%d", payload.reward)
	end

	modifierFrame.BackgroundTransparency = 1
	modifierFrame.Position = UDim2.new(0, -20, 1, -54)
	TweenService:Create(modifierFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.1,
		Position = UDim2.new(0, 14, 1, -54),
	}):Play()
end

local function hideModifier()
	currentModifier = nil
	modifierFrame.Visible = false
end

local function getFlatDirectionAngle(camera, targetPosition, originPosition)
	local direction = targetPosition - originPosition
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		return 0
	end
	flatDirection = flatDirection.Unit

	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatLook.Magnitude < 0.01 or flatRight.Magnitude < 0.01 then
		return 0
	end
	flatLook = flatLook.Unit
	flatRight = flatRight.Unit

	local forwardDot = flatDirection:Dot(flatLook)
	local rightDot = flatDirection:Dot(flatRight)
	return math.deg(math.atan2(rightDot, forwardDot))
end

deliveryEvent.OnClientEvent:Connect(function(action, payload)
	payload = type(payload) == "table" and payload or {}

	if action == "JobAssigned" then
		nextStopFrame.Visible = false
		clearTravelEvent(false, true)
		clearEventObjective()
		currentJobTypeId = payload.jobTypeId or "standard"
		currentJobTypeName = payload.jobTypeName or "配達"
		orderStartedAt = workspace:GetServerTimeNow()
		orderExpiresAt = payload.expiresAt
		local targetName = payload.displayName
		if payload.houseType and payload.houseType ~= "Normal" then
			targetName = tostring(targetName or "配達先") .. "（" .. tostring(payload.houseTypeLabel or "Obby") .. "）"
		end
		setTarget(payload.houseName, targetName)
		modifierTitle.Text = "ルートを選択中..."
		modifierDescription.Text = "荷物条件は確認中。ルート決定後に制限時間が始まります。"
		modifierFrame.Visible = false
		currentModifier = nil
		pendingRouteSerial = payload.jobSerial
		-- Core gameplay UI is the sole route-choice owner.
		routeChoiceFrame.Visible = false
		requestOrderModifier(payload.jobSerial)
		if payload.lastDelivery then announceShift("LAST DELIVERY  今夜最後の配達") end

		if introFrame.Visible then
			introFrame.Visible = false
		end
		if townRevealActive then
			townReveal.Visible = false
			townRevealActive = false
		end
	elseif action == "NightShiftProgress" then
		if (payload.combo or 0) >= 2 then
			announceShift(string.format("PERFECT x%d%s", payload.combo, (payload.comboBonus or 0) > 0 and "  BONUS!" or ""))
		end
	elseif action == "NightShiftComplete" then
		local elapsed = math.max(0, math.floor(tonumber(payload.bestTime) or 0))
		local body = string.format(
			"NIGHT SHIFT COMPLETE  #%d\n\nDeliveries     %d\nPerfect         %d    Good %d    Poor %d\nEvents Solved   %d    Destination %d\nOddities       %d\nKindness +%d    Best Time %d:%02d\nMax Combo      %d\nCoins Earned    %d\n\nSHIFT RANK  %s",
			tonumber(payload.number) or 1, tonumber(payload.deliveries) or 0,
			tonumber(payload.perfect) or 0, tonumber(payload.good) or 0, tonumber(payload.poor) or 0,
			tonumber(payload.events) or 0, tonumber(payload.destinationSuccess) or 0,
			tonumber(payload.oddities) or 0,
			tonumber(payload.kindness) or 0, math.floor(elapsed / 60), elapsed % 60,
			tonumber(payload.maxCombo) or 0, tonumber(payload.coins) or 0, tostring(payload.rank or "C")
		)
		task.delay(2.5, function()
			if player:GetAttribute("NightShiftActive") ~= true then
				shiftText.Text = body
				shiftResult.Visible = true
			end
		end)
	elseif action == "JobRouteChosen" then
		if tonumber(payload.jobSerial) ~= tonumber(pendingRouteSerial) then
			return
		end
		routeChoiceFrame.Visible = false
		orderStartedAt = workspace:GetServerTimeNow()
		orderExpiresAt = payload.expiresAt
		modifierFrame.Visible = true
	elseif action == "Delivered" then
		clearTravelEvent(false, true)
		clearEventObjective()
		clearEventAppearance()
		showResident(payload)
		clearTarget()
		hideModifier()
		destinationEventFrame.Visible = false
		sideOfferFrame.Visible = false
		if not payload.hasNextStops then
			nextStopFrame.Visible = false
		end
		currentJobTypeId = nil
		currentJobTypeName = nil
		orderStartedAt = nil
		orderExpiresAt = nil
		pendingRouteSerial = nil
		modifierRequestGeneration += 1
		routeChoiceFrame.Visible = false
	elseif action == "TravelEventStarted" then
		if tonumber(payload.jobSerial) == tonumber(pendingRouteSerial) then
			showTravelEvent(payload)
		end
	elseif action == "TravelEventResolved" then
		if tonumber(payload.jobSerial) == tonumber(travelEventSerial) then
			local followUpText = tostring(payload.followUpText or "")
			local outcomeText = string.format("+%d Coins  配達を続けよう。", tonumber(payload.reward) or 0)
			local outcomeTitle = "道中イベント解決"
			if followUpText ~= "" then
				outcomeTitle = tostring(payload.followUpTitle or "街のつながり")
				outcomeText ..= "  " .. followUpText
			end
			showTravelEventOutcome(
				outcomeTitle,
				outcomeText,
				true
			)
		end
	elseif action == "TravelEventExpired" then
		if tonumber(payload.jobSerial) == tonumber(travelEventSerial) then
			if payload.reason == "destination_reached" then
				clearTravelEvent(true, true)
			elseif payload.blocking == true then
				showTravelEventOutcome(
					"通行止め解除",
					"工事車両が移動した。通常ルートで配達を続けよう。",
					true
				)
			else
				showTravelEventOutcome(
					"寄り道を見送った",
					"配達を優先。目的地へ向かおう。",
					true
				)
			end
		end
	elseif action == "SideJobOffer" then
		sideOfferSerial += 1
		local serial = sideOfferSerial
		sideOfferHouseName = tostring(payload.houseName or "")
		sideOfferTitle.Text = string.format("近くの追加依頼  ・  %s", tostring(payload.cargoType or "追加便"))
		sideOfferBody.Text = string.format("%sまで %d studs  /  成功で +%d Coins  /  受注期限 %d秒  /  バッグ枠 %s",
			tostring(payload.displayName or "近くの家"), tonumber(payload.distance) or 0,
			tonumber(payload.reward) or 0, tonumber(payload.expiresIn) or 35,
			tostring(payload.bagCapacity or ""))
		sideOfferFrame.Visible = true
		task.delay(tonumber(payload.expiresIn) or 35, function()
			if serial == sideOfferSerial then
				sideOfferFrame.Visible = false
				sideOfferHouseName = nil
			end
		end)
	elseif action == "SideJobAccepted" then
		sideOfferFrame.Visible = false
		modifierTitle.Text = "追加依頼をバッグに積んだ"
		modifierDescription.Text = string.format("%s  ・  +%d Coins", tostring(payload.displayName or "追加便"), tonumber(payload.reward) or 180)
		modifierFrame.Visible = true
	elseif action == "NextStopOptions" then
		showNextStops(payload)
	elseif action == "DestinationEvent" then
		destinationChoicePending = false
		sideOfferSerial += 1
		sideOfferFrame.Visible = false
		sideOfferHouseName = nil
		clearEventObjective()
		showEventAppearance(tostring(payload.id or ""))
		destinationEventSerial = tonumber(payload.jobSerial)
		destinationEventTitle.Text = tostring(payload.title or "配達先で小さな問題")
		destinationEventBody.Text = tostring(payload.body or "届け方を選ぼう。")
		quickEventButton.Text = tostring(payload.quickLabel or "そのまま届ける")
		carefulEventButton.Text = tostring(payload.carefulLabel or "丁寧に届ける")
		quickEventButton.Active = true
		carefulEventButton.Active = true
		destinationEventFrame.Visible = true
	elseif action == "DestinationEventObjective" then
		destinationChoicePending = false
		destinationEventSerial = nil
		destinationEventFrame.Visible = false
		showEventObjective(payload)
	elseif action == "DestinationEventHazard" then
		if tonumber(payload.jobSerial) == tonumber(eventObjectiveSerial) then
			eventHazardTriggered = true
			eventObjectiveTitle.Text = "犬が吠えた！"
			eventObjectiveTitle.TextColor3 = Color3.fromRGB(255, 154, 136)
			eventObjectiveBody.Text = tostring(payload.text or "警戒範囲に入り、現場判断ボーナスを失った。")
			if eventObjectivePart then
				TweenService:Create(eventObjectivePart, TweenInfo.new(0.16), {Color = Color3.fromRGB(235, 105, 87)}):Play()
			end
		end
	elseif action == "NightConditionChanged" then
		nightBadge.Visible = true
		nightName.Text = "今夜: " .. tostring(payload.name or "静かな夜")
		nightDescription.Text = tostring(payload.description or "")
		if not currentHouseName then
			modifierTitle.Text = "今夜: " .. tostring(payload.name or "静かな夜")
			modifierDescription.Text = tostring(payload.description or "")
			modifierFrame.Visible = true
			task.delay(5, function()
				if not currentHouseName then
					modifierFrame.Visible = false
				end
			end)
		end
	elseif action == "RareAnomaly" then
		showRareAnomaly(payload)
		if currentHouseName then
			local jobSerial = tonumber(player:GetAttribute("NightDeliveryJobSerial"))
			navTitle.Text = "宛名が読めない..."
			task.delay(1.1, function()
				if currentHouseName and tonumber(player:GetAttribute("NightDeliveryJobSerial")) == jobSerial then
					if eventObjectivePart and eventObjectivePart.Parent then
						navTitle.Text = eventObjectiveNavTitle or "指定された場所へ届ける"
					elseif travelEventBlocking and travelEventPart and travelEventPart.Parent then
						navTitle.Text = "迂回ポイントへ"
					else
						navTitle.Text = currentDisplayName or currentHouseName
					end
				end
			end)
		end
	elseif action == "Welcome" then
		if payload.nightConditionName then
			nightBadge.Visible = true
			nightName.Text = "今夜: " .. tostring(payload.nightConditionName)
			nightDescription.Text = tostring(payload.nightConditionDescription or "")
		end
		showTownReveal()
		if (payload.deliveries or 0) == 0 then
			task.delay(3.15, function()
				if not currentHouseName and not introFrame.Visible then
					showIntro()
				end
			end)
		end
		deliveryEvent:FireServer("PolishRequestState")
	elseif action == "PolishSessionState" then
		updateMissionCard(payload.missions)
	elseif action == "RumorUnlocked" then
		showRumor(payload)
	elseif action == "PolishOrderModifier" then
		if tonumber(payload.jobSerial) == tonumber(pendingRouteSerial) then
			showModifier(payload)
		end
	elseif action == "PolishDeliveryResult" then
		showResult(payload)
	end
end)

deliveryEvent:FireServer("PolishRequestState")

RunService.RenderStepped:Connect(function()
	if not currentTarget or not currentTarget.Parent then
		if navFrame.Visible and not currentHouseName then
			navFrame.Visible = false
		end
		return
	end

	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return
	end

	if travelEventPart and travelEventPart.Parent and travelEventSerial and not travelEventResolving then
		local travelDistance = (travelEventPart.Position - root.Position).Magnitude
		if travelDistance <= 8 then
			travelEventResolving = true
			deliveryEvent:FireServer("ResolveTravelEvent", {
				jobSerial = travelEventSerial,
			})
		end
	end
	if travelEventFrame.Visible and travelEventExpiresAt and travelEventSerial then
		local eventRemaining = math.max(0, math.ceil(travelEventExpiresAt - workspace:GetServerTimeNow()))
		if travelEventBaseBody ~= "" then
			travelEventBody.Text = string.format("%s  +%d Coins  残り%d秒", travelEventBaseBody, travelEventReward, eventRemaining)
		end
	end

	local distance = (currentTarget.Position - root.Position).Magnitude
	if eventObjectivePart and eventObjectiveFrame.Visible then
		eventObjectiveReady = distance <= 9
		eventObjectiveButton.Active = eventObjectiveReady
		eventObjectiveButton.AutoButtonColor = eventObjectiveReady
		if eventObjectiveReady then
			eventObjectiveButton.Text = "ここに届ける"
		else
			eventObjectiveButton.Text = string.format("指定位置まであと %d studs", math.max(0, math.floor(distance)))
		end
	end
	local navSoft = (
		player:GetAttribute("NightDeliveryNavSoft") == true
		or player:GetAttribute("NightDeliveryNightNavSoft") == true
	) and distance > 70
	navFrame.Visible = not navSoft
	local angle = getFlatDirectionAngle(camera, currentTarget.Position, root.Position)
	arrow.Rotation = angle

	if distance < 18 then
		arrow.TextColor3 = Color3.fromRGB(111, 225, 170)
		navDistance.TextColor3 = Color3.fromRGB(119, 225, 174)
		navDistance.Text = string.format("到着目前  ・  %d studs", math.floor(distance))
	elseif distance < 55 then
		arrow.TextColor3 = Color3.fromRGB(255, 221, 119)
		navDistance.TextColor3 = Color3.fromRGB(196, 210, 226)
		navDistance.Text = string.format("%d studs  ・  もう少し", math.floor(distance))
	else
		arrow.TextColor3 = Color3.fromRGB(255, 212, 104)
		navDistance.TextColor3 = Color3.fromRGB(160, 185, 212)
		navDistance.Text = string.format("%d studs  ・  %s", math.floor(distance), currentJobTypeName or "配達")
	end
end)

-- Compact the add-on HUD a little more on narrow phones.
local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local narrow = viewport.X < 650

	if narrow then
		navFrame.Size = UDim2.fromOffset(236, 58)
		nightBadge.Size = UDim2.new(0, 205, 0, 48)
		nightBadge.Position = UDim2.new(1, -10, 0, 78)
		sideOfferFrame.Position = UDim2.new(0.5, 0, 0, 132)
		travelEventFrame.Position = UDim2.new(0.5, 0, 0, 204)
		nightName.TextSize = 11
		nightDescription.TextSize = 9
		missionFrame.Size = UDim2.fromOffset(210, 76)
		missionName.TextSize = 12
		missionProgress.TextSize = 10
		modifierFrame.Size = UDim2.fromOffset(218, 66)
		modifierTitle.TextSize = 12
		modifierDescription.TextSize = 10
		resultFrame.Size = UDim2.new(0.86, 0, 0, 180)
		shiftResult.Size = UDim2.new(0.9, 0, 0, 340)
		shiftText.TextSize = 13
		shiftHud.Size = UDim2.fromOffset(150, 38)
		destinationEventFrame.Size = UDim2.new(0.92, 0, 0, 180)
		eventObjectiveFrame.Size = UDim2.new(0.92, 0, 0, 116)
		travelEventFrame.Size = UDim2.new(0.92, 0, 0, 96)
		sideOfferFrame.Size = UDim2.new(0.92, 0, 0, 148)
		nextStopFrame.Size = UDim2.new(0.92, 0, 0, 54 + (#nextStopButtons * 52))
		quickEventButton.TextSize = 11
		carefulEventButton.TextSize = 11
		residentFrame.Size = UDim2.new(0.92, 0, 0, 92)
		residentLineLabel.TextSize = 12
		routeChoiceFrame.Size = UDim2.new(0.92, 0, 0, 200)
		lanternRouteButton.TextSize = 12
		shortcutRouteButton.TextSize = 12
		rumorFrame.Size = UDim2.new(0.92, 0, 0, 166)
		rumorTitle.TextSize = 14
		rumorBody.TextSize = 12
		introFrame.Size = UDim2.new(0.92, 0, 0, 166)
		introBody.TextSize = 12
		introTitle.TextSize = 15
		townTitle.TextSize = 27
		townKicker.TextSize = 12
		townSubtitle.TextSize = 11
	else
		navFrame.Size = UDim2.fromOffset(300, 64)
		nightBadge.Size = UDim2.fromOffset(250, 52)
		nightBadge.Position = UDim2.new(1, -14, 0, 12)
		sideOfferFrame.Position = UDim2.new(0.5, 0, 0, 86)
		travelEventFrame.Position = UDim2.new(0.5, 0, 0, 154)
		nightName.TextSize = 12
		nightDescription.TextSize = 10
		missionFrame.Size = UDim2.fromOffset(255, 82)
		missionName.TextSize = 14
		missionProgress.TextSize = 12
		modifierFrame.Size = UDim2.fromOffset(270, 72)
		modifierTitle.TextSize = 14
		modifierDescription.TextSize = 12
		resultFrame.Size = UDim2.fromOffset(360, 190)
		shiftResult.Size = UDim2.fromOffset(340, 340)
		shiftText.TextSize = 16
		destinationEventFrame.Size = UDim2.fromOffset(430, 176)
		eventObjectiveFrame.Size = UDim2.fromOffset(410, 116)
		travelEventFrame.Size = UDim2.fromOffset(370, 92)
		sideOfferFrame.Size = UDim2.fromOffset(420, 148)
		nextStopFrame.Size = UDim2.fromOffset(420, 54 + (#nextStopButtons * 52))
		quickEventButton.TextSize = 13
		carefulEventButton.TextSize = 13
		residentFrame.Size = UDim2.fromOffset(420, 94)
		residentLineLabel.TextSize = 13
		routeChoiceFrame.Size = UDim2.fromOffset(430, 190)
		lanternRouteButton.TextSize = 14
		shortcutRouteButton.TextSize = 14
		rumorFrame.Size = UDim2.fromOffset(440, 144)
		rumorTitle.TextSize = 16
		rumorBody.TextSize = 13
		introFrame.Size = UDim2.fromOffset(440, 154)
		introBody.TextSize = 13
		introTitle.TextSize = 16
		townTitle.TextSize = 34
		townKicker.TextSize = 14
		townSubtitle.TextSize = 13
	end
end

updateResponsiveScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateResponsiveScale)

print("Night Delivery RC client polish loaded")
