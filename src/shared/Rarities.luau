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
		CarrySpeedMultiplier = 1.0,
		SortOrder = 1,
	},
	Rare = {
		Name = "Rare",
		Color = Color3.fromRGB(60, 140, 255),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 2,
	},
	Epic = {
		Name = "Epic",
		Color = Color3.fromRGB(170, 70, 255),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 3,
	},
	Legendary = {
		Name = "Legendary",
		Color = Color3.fromRGB(255, 185, 35),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 4,
	},
	Mythic = {
		Name = "Mythic",
		Color = Color3.fromRGB(255, 55, 95),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 5,
	},
	Secret = {
		Name = "Secret",
		Color = Color3.fromRGB(0, 240, 220),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 6,
	},
	SemiTitanic = {
		Name = "SemiTitanic",
		Color = Color3.fromRGB(255, 145, 35),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 7,
	},
	Titanic = {
		Name = "Titanic",
		Color = Color3.fromRGB(255, 45, 75),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 8,
	},
	Godly = {
		Name = "Godly",
		Color = Color3.fromRGB(165, 255, 255),
		CarrySpeedMultiplier = 1.0,
		SortOrder = 9,
	},
}

local Order: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "SemiTitanic", "Titanic", "Godly" }

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
