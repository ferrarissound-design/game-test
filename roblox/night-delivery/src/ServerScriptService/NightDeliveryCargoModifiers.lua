-- Shared server-side cargo definitions for dispatch offers and order grading.
return {
	{id = "none", weight = 36, title = "通常便", description = "いつもの配達。自分に合うルートを選ぼう。", reward = 0, minGrade = "C"},
	{id = "fragile", weight = 12, title = "ワレモノ注意", description = "ジャンプや落下で荷物が傷む。地面を安定して走ろう。", reward = 110, minGrade = "A"},
	{id = "premium", weight = 10, title = "高級品", description = "丁寧に届けよう。A評価以上で追加報酬。", reward = 140, minGrade = "A"},
	{id = "tip", weight = 8, title = "常連さん", description = "受け取ってもらえればチップ確定。", reward = 55, minGrade = "C"},
	{id = "mystery", weight = 5, title = "宛名の薄い荷物", description = "近くで住所を確認。遠くではナビが弱くなる。", reward = 180, minGrade = "A"},
	{id = "frozen", weight = 9, title = "冷凍便", description = "35秒を超えると品質が下がる。寄り道は慎重に。", reward = 100, minGrade = "C"},
	{id = "oversized", weight = 8, title = "大型荷物", description = "自転車は使えない。徒歩で安定して運ぼう。", reward = 90, minGrade = "B"},
	{id = "hot", weight = 7, title = "温かい料理", description = "30秒以内に届けると追加報酬。", reward = 100, minGrade = "C"},
	{id = "secret", weight = 5, title = "秘密便", description = "遠くでは方角ナビが表示されない。街の目印を使おう。", reward = 125, minGrade = "B"},
}
