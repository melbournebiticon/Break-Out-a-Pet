--!strict
-- CageLoot.luau
-- 100% Tatak Pinoy weighted loot tables across all 6 Zones (each zone sums to 100).
-- IMPORTANT: Roll() and RollFromTable() must only be called from the SERVER.

local RunService = game:GetService("RunService")
local PetData = require(script.Parent.PetData)
local EventData = require(script.Parent.EventData)

local Zones: { [string]: { [string]: number } } = {
	-- Zone 1: Bukid & Sabungan (Total = 100 | 0.05% Jackpot Titanic!)
	Zone1 = {
		chicken = 28,
		duckling = 20,
		puspin = 16,
		aspin = 16,
		bunny = 10,
		kalabaw = 9.95,
		titanic_kalabaw = 0.05,
	},
	-- Zone 2: Palengke & Tiangge (Total = 100 | 0.10% Titanic!)
	Zone2 = {
		aspin = 20,
		turtle = 18,
		puspin = 14,
		chicken = 12,
		bangus = 12,
		golden_pig = 10,
		alimango = 8,
		ninja_cat = 5.9,
		titanic_kalabaw = 0.1,
	},
	-- Zone 3: Hacienda Compound (Total = 100 | 0.15% Titanic!)
	Zone3 = {
		turtle = 18,
		golden_pig = 18,
		aspin = 14,
		bayawak = 14,
		ninja_cat = 12,
		kalabaw = 8,
		tarsier = 6,
		chameleon = 6,
		pawikan = 3.85,
		titanic_kalabaw = 0.15,
	},
	-- Zone 4: Bohol & Palawan Gubat (Total = 100 | 0.25% Titanic!)
	Zone4 = {
		golden_pig = 18,
		tarsier = 16,
		pilandok = 16,
		ninja_cat = 14,
		chameleon = 10,
		agila = 10,
		butanding = 10,
		phoenix = 5.75,
		titanic_agila = 0.25,
	},
	-- Zone 5: Bulkang Mayon Ridge (Total = 100 | 0.35% Titanic!)
	Zone5 = {
		tarsier = 18,
		agila = 18,
		phoenix = 14,
		tamaraw = 14,
		chameleon = 10,
		butanding = 10,
		sigbin = 10,
		minokawa = 5.65,
		titanic_bakunawa = 0.35,
	},
	-- Zone 6: Intramuros Royal Vault (Total = 100 | 0.50% Titanic!)
	Zone6 = {
		tamaraw = 18,
		agila = 16,
		phoenix = 16,
		sarimanok = 14,
		sigbin = 14,
		minokawa = 12,
		tikbalang = 6,
		bakunawa = 3.5,
		titanic_sarimanok = 0.5,
	},
	-- Zone 7: Mythical Sanctuary (Total = 100 | 0.75% Titanic!)
	Zone7 = {
		hamster = 10,
		raccoon = 20,
		panda = 22,
		octopus = 18,
		diamond_capybara = 12,
		wolf = 10,
		mini_dragon = 7.25,
		titanic_dragon = 0.75,
	},
	-- Zone 8: Celestial Vault (Total = 100 | 1.00% Titanic!)
	Zone8 = {
		panda = 15,
		octopus = 15,
		diamond_capybara = 22,
		wolf = 18,
		mini_dragon = 18,
		shadow_kitsune = 7,
		rainbow_unicorn = 4,
		titanic_dragon = 1.0,
	},
	-- Zone 9: Valhalla Coliseum (Total = 100 | 1.50% Titanic!)
	Zone9 = {
		wolf = 20,
		mini_dragon = 22,
		shadow_kitsune = 18,
		rainbow_unicorn = 14,
		mecha_lion = 14,
		void_phoenix = 6.5,
		semi_typhon = 4,
		titanic_kalabaw = 1.5,
	},
	-- Zone 10: Olympus Titan Realm (Total = 100)
	Zone10 = {
		shadow_kitsune = 18,
		rainbow_unicorn = 16,
		mecha_lion = 20,
		void_phoenix = 18,
		semi_typhon = 14,
		semi_hydra = 8,
		semi_golem = 4,
		titanic_kalabaw = 2,
	},
	-- Zone 11: Dragon Emperor Citadel (Total = 100)
	Zone11 = {
		void_phoenix = 18,
		semi_typhon = 18,
		semi_hydra = 18,
		semi_golem = 16,
		titanic_kalabaw = 12,
		titanic_agila = 10,
		titanic_bakunawa = 5,
		titanic_dragon = 3,
	},
	-- Zone 12: Bathala Infinity Throne (Total = 100)
	Zone12 = {
		semi_golem = 16,
		titanic_kalabaw = 18,
		titanic_agila = 18,
		titanic_bakunawa = 18,
		titanic_dragon = 14,
		titanic_sarimanok = 10,
		godly_bathala = 4,
		godly_astralis = 2,
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
