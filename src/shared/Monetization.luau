--!strict
-- Monetization.luau
-- GamePass and Developer Product IDs. Set to 0 as placeholders until configured in Creator Hub.

local Monetization = {
	GamePasses = {
		DoubleMoney = {
			Id = 0,
			Name = "2x Money",
			Description = "Earn double money from all placed & equipped pets!",
			Multiplier = 2,
		},
		VipSpeed = {
			Id = 0,
			Name = "VIP Speed",
			Description = "+10% permanent walk speed boost!",
			SpeedMultiplier = 1.10,
		},
		ExtraSlots = {
			Id = 0,
			Name = "+2 Pet Slots",
			Description = "Unlock 2 extra pet slots on your base plot!",
			ExtraSlots = 2,
		},
	},
	Products = {
		LuckyCage = {
			Id = 0,
			Name = "Lucky Next Cage",
			Description = "Your next opened cage uses the Lucky Cage loot table!",
		},
		MoneyPackSmall = {
			Id = 0,
			Name = "Starter Cash Pack",
			Description = "Instant cash boost (5 mins of income, min $2,500)!",
			IncomeSeconds = 300,
			MinAmount = 2500,
		},
		MoneyPackLarge = {
			Id = 0,
			Name = "Mega Cash Pack",
			Description = "Huge cash boost (30 mins of income, min $25,000)!",
			IncomeSeconds = 1800,
			MinAmount = 25000,
		},
	},
}

return Monetization
