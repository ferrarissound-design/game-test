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

local currentTarget = nil
local currentHouseName = nil
local currentDisplayName = nil
local currentJobTypeId = nil
local currentJobTypeName = nil
local orderStartedAt = nil
local orderExpiresAt = nil
local currentModifier = nil
local resultSerial = 0

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

local missionHeader = makeLabel(missionFrame, UDim2.new(1, -18, 0, 24), UDim2.fromOffset(10, 6), "今夜の目標", 12, Enum.Font.GothamBold)
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
		currentJobTypeId = payload.jobTypeId or "standard"
		currentJobTypeName = payload.jobTypeName or "配達"
		orderStartedAt = workspace:GetServerTimeNow()
		orderExpiresAt = payload.expiresAt
		setTarget(payload.houseName, payload.displayName)
		modifierTitle.Text = "依頼条件を確認中..."
		modifierDescription.Text = ""
		modifierFrame.Visible = true

		deliveryEvent:FireServer("PolishJobSeen", {
			jobTypeId = currentJobTypeId,
			houseName = payload.houseName,
			jobSerial = payload.jobSerial,
		})

		if introFrame.Visible then
			introFrame.Visible = false
		end
		if townRevealActive then
			townReveal.Visible = false
			townRevealActive = false
		end
	elseif action == "Delivered" then
		deliveryEvent:FireServer("PolishDeliveryComplete", {
			houseName = currentHouseName,
		})
		clearTarget()
		hideModifier()
		currentJobTypeId = nil
		currentJobTypeName = nil
		orderStartedAt = nil
		orderExpiresAt = nil
	elseif action == "Welcome" then
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
	elseif action == "PolishOrderModifier" then
		showModifier(payload)
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

	local distance = (currentTarget.Position - root.Position).Magnitude
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
		missionFrame.Size = UDim2.fromOffset(210, 76)
		missionName.TextSize = 12
		missionProgress.TextSize = 10
		modifierFrame.Size = UDim2.fromOffset(218, 66)
		modifierTitle.TextSize = 12
		modifierDescription.TextSize = 10
		resultFrame.Size = UDim2.new(0.86, 0, 0, 180)
		introFrame.Size = UDim2.new(0.92, 0, 0, 166)
		introBody.TextSize = 12
		introTitle.TextSize = 15
		townTitle.TextSize = 27
		townKicker.TextSize = 12
		townSubtitle.TextSize = 11
	else
		navFrame.Size = UDim2.fromOffset(300, 64)
		missionFrame.Size = UDim2.fromOffset(255, 82)
		missionName.TextSize = 14
		missionProgress.TextSize = 12
		modifierFrame.Size = UDim2.fromOffset(270, 72)
		modifierTitle.TextSize = 14
		modifierDescription.TextSize = 12
		resultFrame.Size = UDim2.fromOffset(360, 190)
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
