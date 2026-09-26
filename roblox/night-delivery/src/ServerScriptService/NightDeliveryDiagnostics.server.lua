-- Night Delivery startup diagnostics.
-- Read-only structural checks that make Studio QA faster after Rojo sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HOUSE_TYPES = require(script.Parent:WaitForChild("NightDeliveryHouseTypes"))

if not RunService:IsStudio() then
	return
end

local REMOTE_NAME = "NightDeliveryEvent"
local WORLD_NAME = "NightDeliveryWorld"
local EXPECTED_HOUSE_COUNT = 16
local WAIT_SECONDS = 20

local failures = {}
local warnings = {}
local checkCount = 0

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function note(condition, message)
	checkCount += 1
	if not condition then
		table.insert(warnings, message)
	end
	return condition
end

local function waitForWorld()
	local deadline = os.clock() + WAIT_SECONDS
	repeat
		local world = workspace:FindFirstChild(WORLD_NAME)
		local houses = world and world:FindFirstChild("Houses")
		if world and houses and #houses:GetChildren() >= EXPECTED_HOUSE_COUNT then
			return world, houses
		end
		task.wait(0.2)
	until os.clock() >= deadline
	local world = workspace:FindFirstChild(WORLD_NAME)
	return world, world and world:FindFirstChild("Houses") or nil
end

local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, WAIT_SECONDS)
check(remote ~= nil, "ReplicatedStorage.NightDeliveryEvent が見つからない")
if remote then
	check(remote:IsA("RemoteEvent"), "NightDeliveryEvent が RemoteEvent ではない")
end

local world, houses = waitForWorld()
if not check(world ~= nil, "NightDeliveryWorld が生成されていない") then
	warn("[NightDelivery QA] FAIL: NightDeliveryWorld が生成されていない")
	return
end
if not check(houses ~= nil, "NightDeliveryWorld.Houses が見つからない") then
	warn("[NightDelivery QA] FAIL: Houses フォルダが見つからない")
	return
end

local houseChildren = houses:GetChildren()
check(#houseChildren == EXPECTED_HOUSE_COUNT, string.format(
	"配達先数が %d ではなく %d",
	EXPECTED_HOUSE_COUNT,
	#houseChildren
))

local allowedDistricts = {
	central = true,
	riverside = true,
	warehouse = true,
}
local seenHouseNames = {}
local seenHouseTypes = {}
local challengeCounts = {normal = 0, light = 0, heavy = 0}

for _, house in ipairs(houseChildren) do
	check(house:IsA("Model"), house.Name .. " が Model ではない")
	if seenHouseNames[house.Name] then
		table.insert(failures, "配達先名が重複: " .. house.Name)
	else
		seenHouseNames[house.Name] = true
	end

	local displayName = house:GetAttribute("DisplayName")
	local districtId = house:GetAttribute("DistrictId")
	local houseType = house:GetAttribute("HouseType") or "Normal"
	local definition = HOUSE_TYPES.Definitions[houseType]
	check(type(displayName) == "string" and displayName ~= "", house.Name .. " の DisplayName がない")
	check(allowedDistricts[districtId] == true, house.Name .. " の DistrictId が不正: " .. tostring(districtId))
	check(definition ~= nil, house.Name .. " の HouseType が不正: " .. tostring(houseType))
	if definition then
		local tier = definition.challengeTier or "normal"
		challengeCounts[tier] = (challengeCounts[tier] or 0) + 1
		seenHouseTypes[houseType] = true
	end

	local point = house:FindFirstChild("DeliveryPoint")
	check(point ~= nil and point:IsA("BasePart"), house.Name .. " に DeliveryPoint がない")
	if point and point:IsA("BasePart") then
		local prompt = point:FindFirstChild("DeliverPrompt")
		check(prompt ~= nil and prompt:IsA("ProximityPrompt"), house.Name .. " に DeliverPrompt がない")
		if houseType == "Normal" then
			note(math.abs(point.Position.Y) <= 3, house.Name .. " の通常配達 DeliveryPoint 高さが怪しい: " .. tostring(point.Position.Y))
		end
	end
end

check(challengeCounts.normal == 9, "通常配達先が9軒ではなく " .. tostring(challengeCounts.normal))
check(challengeCounts.light == 4, "軽Obbyが4軒ではなく " .. tostring(challengeCounts.light))
check(challengeCounts.heavy == 3, "本格Obbyが3軒ではなく " .. tostring(challengeCounts.heavy))

local themeChallengeType = world:GetAttribute("ThemeChallengeType")
check(type(themeChallengeType) == "string" and themeChallengeType ~= "", "ThemeChallengeType 属性がない")
if type(themeChallengeType) == "string" and themeChallengeType ~= "" then
	check(seenHouseTypes[themeChallengeType] == true,
		"舞台専用Obbyが生成されていない: " .. themeChallengeType)
end

local depot = world:FindFirstChild("Depot")
check(depot ~= nil and depot:IsA("Model"), "Depot が見つからない")
if depot then
	local jobCounter = depot:FindFirstChild("JobCounter")
	local bikeStand = depot:FindFirstChild("BikeStand")
	local upgradeShop = depot:FindFirstChild("UpgradeShop")

	check(jobCounter ~= nil and jobCounter:IsA("BasePart"), "Depot.JobCounter がない")
	check(bikeStand ~= nil and bikeStand:IsA("BasePart"), "Depot.BikeStand がない")
	check(upgradeShop ~= nil and upgradeShop:IsA("BasePart"), "Depot.UpgradeShop がない")

	if jobCounter then
		check(jobCounter:FindFirstChild("AcceptJobPrompt") ~= nil, "AcceptJobPrompt がない")
	end
	if bikeStand then
		check(bikeStand:FindFirstChild("BikeModePrompt") ~= nil, "BikeModePrompt がない")
	end
	if upgradeShop then
		check(upgradeShop:FindFirstChild("UpgradeShopPrompt") ~= nil, "UpgradeShopPrompt がない")
	end
end

for _, roadName in ipairs({"MainRoad", "CrossRoad", "NorthRoad", "RiversideRoad", "WarehouseRoad"}) do
	local road = world:FindFirstChild(roadName)
	check(road ~= nil and road:IsA("BasePart"), roadName .. " が見つからない")
end

check(world:GetAttribute("ThemeId") ~= nil, "World ThemeId 属性がない")
check(world:GetAttribute("ThemeName") ~= nil, "World ThemeName 属性がない")
check(world:GetAttribute("InitialWeather") ~= nil, "World InitialWeather 属性がない")

world:SetAttribute("QACheckCount", checkCount)
world:SetAttribute("QAFailureCount", #failures)
world:SetAttribute("QAWarningCount", #warnings)
world:SetAttribute("QAPassed", #failures == 0)

if #failures == 0 then
	print(string.format(
		"[NightDelivery QA] PASS | checks=%d | houses=%d | warnings=%d | theme=%s",
		checkCount,
		#houseChildren,
		#warnings,
		tostring(world:GetAttribute("ThemeName") or "?")
	))
else
	warn(string.format("[NightDelivery QA] FAIL | %d failures / %d checks", #failures, checkCount))
	for _, message in ipairs(failures) do
		warn("[NightDelivery QA] " .. message)
	end
end

for _, message in ipairs(warnings) do
	warn("[NightDelivery QA] WARN: " .. message)
end
