--!strict
-- FusionData.luau
-- Rules, chances, and costs for fusing 3 pets of the same rarity.

export type TierRule = {
	NextRarity: string,
	SuccessChance: number, -- 0 to 1
	Cost: number,
}

local Tiers: { [string]: TierRule } = {
	Common = {
		NextRarity = "Rare",
		SuccessChance = 0.60,
		Cost = 250,
	},
	Rare = {
		NextRarity = "Epic",
		SuccessChance = 0.45,
		Cost = 2500,
	},
	Epic = {
		NextRarity = "Legendary",
		SuccessChance = 0.30,
		Cost = 25000,
	},
	Legendary = {
		NextRarity = "Mythic",
		SuccessChance = 0.20,
		Cost = 250000,
	},
}

local FusionData = {
	FuseCount = 3,
	Tiers = Tiers,
}

function FusionData.GetRule(rarity: string): TierRule?
	return Tiers[rarity]
end

return FusionData
