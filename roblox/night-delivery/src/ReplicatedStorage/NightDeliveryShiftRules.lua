-- Shared shift equipment descriptions and bounded personal records.
-- Equipment changes cargo conditions only; grades, money and bag capacity keep one owner.
local Rules = {}
Rules.DefaultEquipment = "thermal"
Rules.Equipment = {
	{id = "thermal", name = "保温ライナー", description = "温かい料理・冷凍便の品質期限 +10秒。配達の制限時間はそのまま。", cargo = {hot = true, frozen = true}},
	{id = "cushion", name = "緩衝パッド", description = "ワレモノのジャンプ・落下を1回だけ保護。着地までを1回と数えます。", cargo = {fragile = true}},
	{id = "checklist", name = "検品メモ", description = "高級品の追加報酬をB評価から獲得。配達の評価そのものは変わりません。", cargo = {premium = true}},
}

function Rules.equipment(id)
	for _, entry in ipairs(Rules.Equipment) do
		if entry.id == id then return entry end
	end
	return nil
end

function Rules.temperatureLimit(equipmentId, cargoId)
	local base = cargoId == "hot" and 30 or 35
	return base + (equipmentId == "thermal" and 10 or 0)
end

function Rules.requiredGrade(equipmentId, modifier)
	return equipmentId == "checklist" and modifier.id == "premium" and "B" or modifier.minGrade
end

function Rules.modifierTitle(equipmentId, modifier)
	if equipmentId == "thermal" and (modifier.id == "hot" or modifier.id == "frozen") then
		return modifier.title .. " " .. Rules.temperatureLimit(equipmentId, modifier.id) .. "秒"
	elseif equipmentId == "cushion" and modifier.id == "fragile" then
		return "ワレモノ 1回保護"
	elseif equipmentId == "checklist" and modifier.id == "premium" then
		return "高級品 B以上"
	end
	return modifier.title
end

function Rules.modifierDescription(equipmentId, modifier)
	if equipmentId == "thermal" and (modifier.id == "hot" or modifier.id == "frozen") then
		local limit = Rules.temperatureLimit(equipmentId, modifier.id)
		return modifier.id == "hot" and (limit .. "秒以内で追加報酬（保温ライナー）。配達期限は別です。")
			or (limit .. "秒を超えると品質低下（保温ライナー）。配達期限は別です。")
	elseif equipmentId == "cushion" and modifier.id == "fragile" then
		return "緩衝パッドでジャンプ・落下を1回保護。2回目で破損。追加報酬はA評価以上。"
	elseif equipmentId == "checklist" and modifier.id == "premium" then
		return "検品メモでB評価以上なら追加報酬。"
	end
	return modifier.description
end

-- Jumping followed by Freefall is one airborne episode, including after a respawn.
function Rules.observeAirborne(order, airborne)
	if airborne and not order.airborne then
		if order.equipmentId == "cushion" and not order.cushionUsed then
			order.cushionUsed = true
		else
			order.jumpDamaged = true
		end
	end
	order.airborne = airborne
end

local function bounded(value, maximum)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then return 0 end
	return math.max(0, math.min(maximum, value))
end

function Rules.cleanRecord(raw)
	raw = type(raw) == "table" and raw or {}
	local result = {
		count = math.floor(bounded(raw.count, 1000000000)),
		lastPerfect = math.floor(bounded(raw.lastPerfect, 6)),
		bestPerfect = math.floor(bounded(raw.bestPerfect, 6)),
		lastSeconds = bounded(raw.lastSeconds, 1000000000),
		bestSeconds = bounded(raw.bestSeconds, 1000000000),
	}
	if result.count == 0 or result.lastSeconds <= 0 or result.bestSeconds <= 0 then
		return {count = 0, lastPerfect = 0, bestPerfect = 0, lastSeconds = 0, bestSeconds = 0}
	end
	result.bestPerfect = math.max(result.bestPerfect, result.lastPerfect)
	result.bestSeconds = math.min(result.bestSeconds, result.lastSeconds)
	return result
end

Rules.RecordAttributes = {
	count = "NightShiftRecordCount", lastPerfect = "NightShiftLastPerfect",
	bestPerfect = "NightShiftBestPerfect", lastSeconds = "NightShiftLastSeconds",
	bestSeconds = "NightShiftBestSeconds",
}

function Rules.readRecord(player)
	local record = {}
	for key, attribute in pairs(Rules.RecordAttributes) do record[key] = player:GetAttribute(attribute) end
	return Rules.cleanRecord(record)
end

function Rules.writeRecord(player, raw)
	local record = Rules.cleanRecord(raw)
	for key, attribute in pairs(Rules.RecordAttributes) do player:SetAttribute(attribute, record[key]) end
end

function Rules.completeRecord(previous, perfect, seconds)
	previous = Rules.cleanRecord(previous)
	perfect = math.floor(bounded(perfect, 6))
	seconds = math.max(0.01, bounded(seconds, 1000000000))
	local hasPrevious = previous.count > 0
	local record = {
		count = math.min(1000000000, previous.count + 1), lastPerfect = perfect, lastSeconds = seconds,
		bestPerfect = math.max(previous.bestPerfect, perfect),
		bestSeconds = hasPrevious and math.min(previous.bestSeconds, seconds) or seconds,
	}
	local comparison = {
		hasPrevious = hasPrevious,
		perfectDelta = hasPrevious and perfect - previous.lastPerfect or 0,
		secondsSaved = hasPrevious and previous.lastSeconds - seconds or 0,
		bestPerfect = record.bestPerfect, bestSeconds = record.bestSeconds,
		newPerfectBest = hasPrevious and perfect > previous.bestPerfect,
		newTimeBest = hasPrevious and seconds < previous.bestSeconds,
	}
	return record, comparison
end

return Rules
