--!strict
-- MutationData.luau
-- Pet mutations rolled when opening a cage on the server.

local RunService = game:GetService("RunService")

export type MutationInfo = {
	Name: string,
	IncomeMultiplier: number,
	ScaleMultiplier: number?,
	MinScale: number?,
	MaxScale: number?,
	Chance: number, -- percentage out of 100
	Color: Color3,
	Material: Enum.Material,
}

local Mutations: { [string]: MutationInfo } = {
	Golden = {
		Name = "Golden",
		IncomeMultiplier = 2,
		MinScale = 1.0,
		MaxScale = 2.9,
		Chance = 5.0,
		Color = Color3.fromRGB(255, 215, 40),
		Material = Enum.Material.Metal,
	},
	Neon = {
		Name = "Neon",
		IncomeMultiplier = 3,
		MinScale = 1.0,
		MaxScale = 2.9,
		Chance = 1.5,
		Color = Color3.fromRGB(0, 255, 200),
		Material = Enum.Material.Neon,
	},
	Shadow = {
		Name = "Shadow",
		IncomeMultiplier = 5,
		MinScale = 1.0,
		MaxScale = 2.9,
		Chance = 0.5,
		Color = Color3.fromRGB(35, 20, 55),
		Material = Enum.Material.ForceField,
	},
	Celestial = {
		Name = "Celestial",
		IncomeMultiplier = 8,
		MinScale = 1.0,
		MaxScale = 2.9,
		Chance = 0.50,
		Color = Color3.fromRGB(120, 245, 255),
		Material = Enum.Material.Neon,
	},
	Fiesta = {
		Name = "Fiesta",
		IncomeMultiplier = 6,
		MinScale = 1.2,
		MaxScale = 2.9,
		Chance = 0.85,
		Color = Color3.fromRGB(255, 85, 195),
		Material = Enum.Material.Neon,
	},
	Semi = {
		Name = "Semi",
		IncomeMultiplier = 12,
		MinScale = 3.0,
		MaxScale = 3.9,
		Chance = 0.40,
		Color = Color3.fromRGB(70, 205, 245),
		Material = Enum.Material.SmoothPlastic,
	},
	Huge = {
		Name = "Huge",
		IncomeMultiplier = 18,
		MinScale = 4.0,
		MaxScale = 4.9,
		Chance = 0.30,
		Color = Color3.fromRGB(60, 230, 180),
		Material = Enum.Material.SmoothPlastic,
	},
	["Semi-Titanic"] = {
		Name = "Semi-Titanic",
		IncomeMultiplier = 30,
		MinScale = 5.0,
		MaxScale = 6.9,
		Chance = 0.18,
		Color = Color3.fromRGB(255, 145, 35),
		Material = Enum.Material.SmoothPlastic,
	},
	Titanic = {
		Name = "Titanic",
		IncomeMultiplier = 60,
		MinScale = 7.0,
		MaxScale = 9.5,
		Chance = 0.08,
		Color = Color3.fromRGB(255, 45, 75),
		Material = Enum.Material.SmoothPlastic,
	},
	["Semi-Godly"] = {
		Name = "Semi-Godly",
		IncomeMultiplier = 120,
		MinScale = 9.8,
		MaxScale = 10.9,
		Chance = 0.035,
		Color = Color3.fromRGB(215, 95, 255),
		Material = Enum.Material.Neon,
	},
	Godly = {
		Name = "Godly",
		IncomeMultiplier = 250,
		MinScale = 11.0,
		MaxScale = 12.5,
		Chance = 0.015,
		Color = Color3.fromRGB(255, 235, 120),
		Material = Enum.Material.Neon,
	},
}

local Order: { string } = {
	"Godly",
	"Semi-Godly",
	"Titanic",
	"Semi-Titanic",
	"Huge",
	"Semi",
	"Celestial",
	"Fiesta",
	"Shadow",
	"Neon",
	"Golden",
}
local rng = Random.new()

local MutationData = {
	Mutations = Mutations,
	Order = Order,
}

function MutationData.Get(name: string?): MutationInfo?
	if not name or name == "" then
		return nil
	end
	return Mutations[name]
end

function MutationData.GetMultiplier(name: string?): number
	local info = MutationData.Get(name)
	return if info then info.IncomeMultiplier else 1
end

function MutationData.RollScale(mutation: string?, baseScale: number?): number
	local base = if typeof(baseScale) == "number" and baseScale > 0 then baseScale else 1.0
	local mutInfo = MutationData.Get(mutation)
	local minS = if mutInfo and mutInfo.MinScale then mutInfo.MinScale else 1.0
	local maxS = if mutInfo and mutInfo.MaxScale then mutInfo.MaxScale else 2.9
	-- Roll smooth randomized scale between min and max rounded to 1 decimal place (e.g. 1.7x, 4.3x, 8.2x)
	local rand = minS + rng:NextNumber() * (maxS - minS)
	return math.floor(rand * base * 10 + 0.5) / 10
end

function MutationData.GetScale(mutation: string?, baseScale: number?): number
	local base = if typeof(baseScale) == "number" and baseScale > 0 then baseScale else 1.0
	local mutInfo = MutationData.Get(mutation)
	if not mutInfo then
		return base
	end
	if mutInfo.ScaleMultiplier then
		return mutInfo.ScaleMultiplier * base
	end
	local minS = mutInfo.MinScale or 1.0
	local maxS = mutInfo.MaxScale or 2.9
	return ((minS + maxS) * 0.5) * base
end

function MutationData.RollMutation(luckMultiplier: number?): string?
	if RunService:IsClient() then
		error("MutationData.RollMutation must only be called from the server")
	end
	local mult = if typeof(luckMultiplier) == "number" and luckMultiplier > 0 then luckMultiplier else 1
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	for _, mutName in Order do
		local info = Mutations[mutName]
		cumulative += info.Chance * mult
		if roll <= cumulative then
			return mutName
		end
	end
	return nil
end

return MutationData
