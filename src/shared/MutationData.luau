--!strict
-- MutationData.luau
-- Pet mutations rolled when opening a cage on the server.

local RunService = game:GetService("RunService")

export type MutationInfo = {
	Name: string,
	IncomeMultiplier: number,
	Chance: number, -- percentage out of 100
	Color: Color3,
	Material: Enum.Material,
}

local Mutations: { [string]: MutationInfo } = {
	Golden = {
		Name = "Golden",
		IncomeMultiplier = 2,
		Chance = 5.0,
		Color = Color3.fromRGB(255, 215, 40),
		Material = Enum.Material.Metal,
	},
	Neon = {
		Name = "Neon",
		IncomeMultiplier = 3,
		Chance = 1.5,
		Color = Color3.fromRGB(0, 255, 200),
		Material = Enum.Material.Neon,
	},
	Shadow = {
		Name = "Shadow",
		IncomeMultiplier = 5,
		Chance = 0.5,
		Color = Color3.fromRGB(35, 20, 55),
		Material = Enum.Material.ForceField,
	},
}

local Order: { string } = { "Shadow", "Neon", "Golden" }
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

function MutationData.RollMutation(): string?
	if RunService:IsClient() then
		error("MutationData.RollMutation must only be called from the server")
	end
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	for _, mutName in Order do
		local info = Mutations[mutName]
		cumulative += info.Chance
		if roll <= cumulative then
			return mutName
		end
	end
	return nil
end

return MutationData
