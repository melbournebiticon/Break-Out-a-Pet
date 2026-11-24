--!strict
-- EventData.luau
-- Numbers for Lucky/Rainbow Cage events and 7-day Daily Rewards.

export type DailyRewardEntry = {
	Day: number,
	Money: number,
	BonusPetZone: string?,
	Label: string,
}

local EventData = {
	EventIntervalSeconds = 180,
	EventDurationSeconds = 90,
	RainbowCageChance = 0.2,
	ExtraGuardSpeedMultiplier = 1.15,

	LootTables = {
		Lucky = {
			turtle = 25,
			bangus = 20,
			golden_pig = 18,
			ninja_cat = 14,
			alimango = 13,
			tarsier = 5,
			agila = 3,
			phoenix = 2,
		},
		Rainbow = {
			tikbalang = 55,
			bakunawa = 45,
		},
	},

	DailyRewards = {
		{ Day = 1, Money = 500, BonusPetZone = nil, Label = "$500" },
		{ Day = 2, Money = 1500, BonusPetZone = nil, Label = "$1.5K" },
		{ Day = 3, Money = 4000, BonusPetZone = "Zone1", Label = "$4K + Pet" },
		{ Day = 4, Money = 10000, BonusPetZone = nil, Label = "$10K" },
		{ Day = 5, Money = 25000, BonusPetZone = "Zone2", Label = "$25K + Pet" },
		{ Day = 6, Money = 75000, BonusPetZone = nil, Label = "$75K" },
		{ Day = 7, Money = 250000, BonusPetZone = "Zone3", Label = "$250K + Rare Pet!" },
	} :: { DailyRewardEntry },
}

return EventData
