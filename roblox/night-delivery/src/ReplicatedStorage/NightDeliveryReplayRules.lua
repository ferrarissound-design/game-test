-- Bounded, additive progress. IDs match the world's actual seven themes and three oddities.
local Rules = {}
Rules.Themes = {
	{id = "japanese", name = "日本住宅街"}, {id = "western", name = "西洋住宅街"},
	{id = "showa", name = "昭和住宅街"}, {id = "luxury", name = "高級住宅街"},
	{id = "harbor", name = "雨の港町"}, {id = "mountain", name = "山間集落"},
	{id = "danchi", name = "団地エリア"},
}
Rules.Oddities = {
	{id = "silent_house", name = "SILENT HOUSE"},
	{id = "unknown_recipient", name = "UNKNOWN RECIPIENT"},
	{id = "repeat_address", name = "REPEAT ADDRESS"},
}
Rules.Ranks = {
	{wins = 0, name = "新人配達員", reward = "配達員の記録"},
	{wins = 2, name = "夜勤見習い", reward = "自転車アクセント：ブルー"},
	{wins = 5, name = "夜道の配達員", reward = "自転車アクセント：アンバー"},
	{wins = 12, name = "ベテラン", reward = "自転車アクセント：ゴールド"},
	{wins = 25, name = "NIGHT COURIER", reward = "NIGHT COURIERの称号"},
}

function Rules.rank(wins)
	wins = math.max(0, math.floor(tonumber(wins) or 0))
	local index = 1
	for i, entry in ipairs(Rules.Ranks) do
		if wins >= entry.wins then index = i end
	end
	return index, Rules.Ranks[index], Rules.Ranks[index + 1]
end

local function cleanMap(raw, entries, field)
	local clean = {}
	if type(raw) ~= "table" then return clean end
	for _, entry in ipairs(entries) do
		local value = raw[entry.id]
		if field == "theme" and type(value) == "table" then
			if value.visited == true or value.completed == true then
				clean[entry.id] = {visited = true, completed = value.completed == true}
			end
		elseif field == "oddity" and value == true then
			clean[entry.id] = true
		end
	end
	return clean
end

function Rules.cleanThemes(raw) return cleanMap(raw, Rules.Themes, "theme") end
function Rules.cleanOddities(raw) return cleanMap(raw, Rules.Oddities, "oddity") end

function Rules.markTheme(raw, id, completed)
	local progress = Rules.cleanThemes(raw)
	for _, theme in ipairs(Rules.Themes) do
		if theme.id == id then
			local old = progress[id]
			progress[id] = {visited = true, completed = completed == true or (old and old.completed == true) or false}
			return progress
		end
	end
	return progress
end

function Rules.markOddity(raw, id)
	local progress = Rules.cleanOddities(raw)
	for _, oddity in ipairs(Rules.Oddities) do
		if oddity.id == id then progress[id] = true; break end
	end
	return progress
end

function Rules.completedCount(raw)
	local progress, count = Rules.cleanThemes(raw), 0
	for _, theme in ipairs(Rules.Themes) do
		if progress[theme.id] and progress[theme.id].completed then count += 1 end
	end
	return count
end

return Rules
