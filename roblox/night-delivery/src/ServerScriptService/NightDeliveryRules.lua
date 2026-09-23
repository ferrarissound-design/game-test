-- Rules shared by the Night Delivery server systems.
-- Keep event probabilities and their player-facing copy together for easy balancing.
local Rules = {}

Rules.DestinationEventChance = 0.22
Rules.RareAnomalyChance = 0.004

Rules.DestinationEvents = {
	{
		id = "absent",
		weight = 1,
		title = "受取人が不在",
		body = "玄関先に置くか、雨よけのある置き配場所を探せる。",
		quickLabel = "玄関に置く",
		carefulLabel = "置き配場所を探す",
		quickBonus = 0,
		carefulBonus = 55,
	},
	{
		id = "dog",
		weight = 1,
		title = "玄関に犬がいる",
		body = "驚かせないよう静かに回るか、少し離れた場所に置ける。",
		quickLabel = "離れて置く",
		carefulLabel = "静かに届ける",
		quickBonus = 0,
		carefulBonus = 45,
	},
	{
		id = "work",
		weight = 1,
		title = "正面が工事中",
		body = "近道を使うか、明るい脇道から回るか選ぼう。",
		quickLabel = "近道を使う",
		carefulLabel = "明るい脇道を回る",
		quickBonus = 50,
		carefulBonus = 20,
	},
}

Rules.NightConditions = {
	{id = "quiet", name = "静かな夜", description = "街灯の道が明るい。", weight = 4},
	{id = "fog", name = "霧の夜", description = "視界が狭まり、遠くのナビ表示が薄くなる。", weight = 2},
	{id = "blackout", name = "停電の夜", description = "街灯が弱まり、近くの家を目印に進もう。", weight = 1},
	{id = "festival", name = "夏祭りの夜", description = "人通りで自転車が少しゆっくり。配達報酬 +10%。", weight = 2},
	{id = "tip", name = "チップの夜", description = "ご近所チップが増える。", weight = 2},
	{id = "roadwork", name = "工事の夜", description = "裏路地ルートの報酬が増える。", weight = 2},
}

function Rules.chooseWeighted(entries, lastId)
	local total = 0
	for _, entry in ipairs(entries) do
		if entry.id ~= lastId then
			total += entry.weight or 1
		end
	end
	if total <= 0 then
		return entries[1]
	end

	local roll = math.random() * total
	local cursor = 0
	for _, entry in ipairs(entries) do
		if entry.id ~= lastId then
			cursor += entry.weight or 1
			if roll <= cursor then
				return entry
			end
		end
	end
	return entries[1]
end

return Rules
