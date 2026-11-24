--!strict
-- CageLoot.luau
-- 100% Tatak Pinoy weighted loot tables across all 6 Zones (each zone sums to 100).
-- IMPORTANT: Roll() and RollFromTable() must only be called from the SERVER.

local RunService = game:GetService("RunService")
local PetData = require(script.Parent.PetData)
local EventData = require(script.Parent.EventData)

local Zones: { [string]: { [string]: number } } = {
	-- Zone 1: Bukid & Sabungan (Total = 100)
	Zone1 = {
		chicken = 28,
		duckling = 20,
		puspin = 16,
		aspin = 16,
		bunny = 10,
		kalabaw = 10,
	},
	-- Zone 2: Palengke & Tiangge (Total = 100)
	Zone2 = {
		aspin = 20,
		turtle = 18,
		puspin = 14,
		chicken = 12,
		bangus = 12,
		golden_pig = 10,
		alimango = 8,
		ninja_cat = 6,
	},
	-- Zone 3: Hacienda Compound (Total = 100)
	Zone3 = {
		turtle = 18,
		golden_pig = 18,
		aspin = 14,
		bayawak = 14,
		ninja_cat = 12,
		kalabaw = 8,
		tarsier = 6,
		chameleon = 6,
		pawikan = 4,
	},
	-- Zone 4: Bohol & Palawan Gubat (Total = 100)
	Zone4 = {
		golden_pig = 18,
		tarsier = 16,
		pilandok = 16,
		ninja_cat = 14,
		chameleon = 10,
		agila = 10,
		butanding = 10,
		phoenix = 6,
	},
	-- Zone 5: Bulkang Mayon Ridge (Total = 100)
	Zone5 = {
		tarsier = 18,
		agila = 18,
		phoenix = 14,
		tamaraw = 14,
		chameleon = 10,
		butanding = 10,
		sigbin = 10,
		minokawa = 6,
	},
	-- Zone 6: Intramuros Royal Vault (Total = 100)
	Zone6 = {
		tamaraw = 18,
		agila = 16,
		phoenix = 16,
		sarimanok = 14,
		sigbin = 14,
		minokawa = 12,
		tikbalang = 6,
		bakunawa = 4,
	},
	-- Zone 7: Mythical Sanctuary (Total = 100)
	Zone7 = {
		hamster = 10,
		raccoon = 20,
		panda = 22,
		octopus = 18,
		diamond_capybara = 12,
		wolf = 10,
		mini_dragon = 8,
	},
	-- Zone 8: Celestial Vault (Total = 100)
	Zone8 = {
		panda = 15,
		octopus = 15,
		diamond_capybara = 22,
		wolf = 18,
		mini_dragon = 18,
		shadow_kitsune = 7,
		rainbow_unicorn = 5,
	},
}

for zoneName, table_ in Zones do
	for petId, weight in table_ do
		assert(PetData.Get(petId) ~= nil, `CageLoot {zoneName}: unknown pet "{petId}"`)
		assert(weight > 0, `CageLoot {zoneName}: weight for "{petId}" must be > 0`)
	end
end

local rng = Random.new()

local CageLoot = {}
CageLoot.Zones = Zones

function CageLoot.RollWeights(weights: { [string]: number }): string
	if RunService:IsClient() then
		error("CageLoot.RollWeights must only be called from the server")
	end

	local total = 0
	for _, weight in weights do
		total += weight
	end

	local pick = rng:NextNumber() * total
	local running = 0
	for petId, weight in weights do
		running += weight
		if pick <= running then
			return petId
		end
	end

	error("CageLoot failed to pick a pet")
end

function CageLoot.Roll(zoneName: string): string
	if RunService:IsClient() then
		error("CageLoot.Roll must only be called from the server")
	end

	local zone = Zones[zoneName]
	if not zone then
		error(`Unknown zone: {zoneName}`)
	end

	return CageLoot.RollWeights(zone)
end

function CageLoot.RollFromTable(tableName: string): string
	if RunService:IsClient() then
		error("CageLoot.RollFromTable must only be called from the server")
	end

	local customTable = (EventData.LootTables :: { [string]: { [string]: number } })[tableName]
	if customTable then
		return CageLoot.RollWeights(customTable)
	end

	return CageLoot.Roll(tableName)
end

return CageLoot
