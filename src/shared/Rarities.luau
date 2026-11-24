--!strict
-- Rarities.luau
-- All rarity info lives here (Common -> Secret).

export type RarityInfo = {
	Name: string,
	Color: Color3,
	CarrySpeedMultiplier: number,
	SortOrder: number,
}

local Data: { [string]: RarityInfo } = {
	Common = {
		Name = "Common",
		Color = Color3.fromRGB(180, 180, 180),
		CarrySpeedMultiplier = 0.95,
		SortOrder = 1,
	},
	Rare = {
		Name = "Rare",
		Color = Color3.fromRGB(60, 140, 255),
		CarrySpeedMultiplier = 0.85,
		SortOrder = 2,
	},
	Epic = {
		Name = "Epic",
		Color = Color3.fromRGB(170, 70, 255),
		CarrySpeedMultiplier = 0.75,
		SortOrder = 3,
	},
	Legendary = {
		Name = "Legendary",
		Color = Color3.fromRGB(255, 185, 35),
		CarrySpeedMultiplier = 0.65,
		SortOrder = 4,
	},
	Mythic = {
		Name = "Mythic",
		Color = Color3.fromRGB(255, 55, 95),
		CarrySpeedMultiplier = 0.55,
		SortOrder = 5,
	},
	Secret = {
		Name = "Secret",
		Color = Color3.fromRGB(0, 240, 220),
		CarrySpeedMultiplier = 0.50,
		SortOrder = 6,
	},
}

local Order: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local Rarities = {}
Rarities.Data = Data
Rarities.Order = Order

function Rarities.Get(name: string): RarityInfo
	local info = Data[name]
	if not info then
		error(`Unknown rarity: {name}`)
	end
	return info
end

return Rarities
