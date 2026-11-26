--!strict
-- PetData.luau
-- 100% Tatak Pinoy Pet Roster. All balance numbers live HERE.

local Rarities = require(script.Parent.Rarities)

export type PetType = "Money" | "Power" | "Hybrid"

export type Ability = {
	AbilityId: string,
	Duration: number,
	Cooldown: number,
	Description: string,
}

export type Pet = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Rarity: string,
	Type: PetType,
	IncomePerSec: number,
	Ability: Ability?,
	CagePrice: number,
	Scale: number?,
}

local Pets: { [string]: Pet } = {
	-- ZONE 1: BUKID & SABUNGAN ------------------------------------
	chicken = {
		Id = "chicken",
		DisplayName = "Manok",
		Emoji = "🐔",
		Rarity = "Common",
		Type = "Money",
		IncomePerSec = 8,
		Ability = nil,
		CagePrice = 180,
	},
	duckling = {
		Id = "duckling",
		DisplayName = "Itik",
		Emoji = "🐥",
		Rarity = "Common",
		Type = "Money",
		IncomePerSec = 10,
		Ability = nil,
		CagePrice = 250,
	},
	puspin = {
		Id = "puspin",
		DisplayName = "Puspin",
		Emoji = "🐱",
		Rarity = "Common",
		Type = "Money",
		IncomePerSec = 14,
		Ability = nil,
		CagePrice = 350,
	},
	bunny = {
		Id = "bunny",
		DisplayName = "Kuneho",
		Emoji = "🐰",
		Rarity = "Common",
		Type = "Power",
		IncomePerSec = 0,
		Ability = {
			AbilityId = "high_jump",
			Duration = 0,
			Cooldown = 0,
			Description = "Jump higher while carrying this pet.",
		},
		CagePrice = 150,
	},
	aspin = {
		Id = "aspin",
		DisplayName = "Aspin",
		Emoji = "🐶",
		Rarity = "Rare",
		Type = "Money",
		IncomePerSec = 24,
		Ability = nil,
		CagePrice = 950,
	},
	kalabaw = {
		Id = "kalabaw",
		DisplayName = "Kalabaw",
		Emoji = "🐃",
		Rarity = "Rare",
		Type = "Hybrid",
		IncomePerSec = 35,
		Ability = {
			AbilityId = "fast_carry",
			Duration = 0,
			Cooldown = 0,
			Description = "Heavy Carry: carry cages faster with knockback resist.",
		},
		CagePrice = 1800,
	},

	-- ZONE 2: PALENGKE & TIANGGE ----------------------------------
	turtle = {
		Id = "turtle",
		DisplayName = "Pagong",
		Emoji = "🐢",
		Rarity = "Rare",
		Type = "Money",
		IncomePerSec = 30,
		Ability = nil,
		CagePrice = 1500,
	},
	bangus = {
		Id = "bangus",
		DisplayName = "Golden Bangus",
		Emoji = "🐟",
		Rarity = "Rare",
		Type = "Hybrid",
		IncomePerSec = 40,
		Ability = {
			AbilityId = "revive",
			Duration = 0,
			Cooldown = 60,
			Description = "Slippery: dodges the first guard catch (60s cooldown).",
		},
		CagePrice = 2500,
	},
	alimango = {
		Id = "alimango",
		DisplayName = "Alimango",
		Emoji = "🦀",
		Rarity = "Epic",
		Type = "Hybrid",
		IncomePerSec = 75,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 3,
			Cooldown = 20,
			Description = "Pinch Slow: stuns/slows nearby guards for 3s.",
		},
		CagePrice = 12000,
	},
	golden_pig = {
		Id = "golden_pig",
		DisplayName = "Golden Baboy",
		Emoji = "🐷",
		Rarity = "Epic",
		Type = "Money",
		IncomePerSec = 150,
		Ability = nil,
		CagePrice = 15000,
	},
	ninja_cat = {
		Id = "ninja_cat",
		DisplayName = "Ninja Puspin",
		Emoji = "🐈‍⬛",
		Rarity = "Epic",
		Type = "Power",
		IncomePerSec = 0,
		Ability = {
			AbilityId = "silent",
			Duration = 0,
			Cooldown = 0,
			Description = "Silent: guards notice you much later.",
		},
		CagePrice = 20000,
	},

	-- ZONE 3: HACIENDA COMPOUND -----------------------------------
	bayawak = {
		Id = "bayawak",
		DisplayName = "Bayawak",
		Emoji = "🦎",
		Rarity = "Rare",
		Type = "Hybrid",
		IncomePerSec = 50,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 5,
			Cooldown = 15,
			Description = "Sprint boost for 5 seconds, every 15 seconds.",
		},
		CagePrice = 4500,
	},
	pawikan = {
		Id = "pawikan",
		DisplayName = "Pawikan",
		Emoji = "🐢",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 900,
		Ability = {
			AbilityId = "revive",
			Duration = 0,
			Cooldown = 60,
			Description = "Guard Shield: blocks the first catch once every 60s.",
		},
		CagePrice = 140000,
	},
	tarsier = {
		Id = "tarsier",
		DisplayName = "Tarsier",
		Emoji = "🐒",
		Rarity = "Legendary",
		Type = "Money",
		IncomePerSec = 1100,
		Ability = nil,
		CagePrice = 180000,
	},
	chameleon = {
		Id = "chameleon",
		DisplayName = "Hunyanggo",
		Emoji = "🦎",
		Rarity = "Legendary",
		Type = "Power",
		IncomePerSec = 0,
		Ability = {
			AbilityId = "invisible",
			Duration = 4,
			Cooldown = 20,
			Description = "Turn invisible to guards for 4 seconds.",
		},
		CagePrice = 150000,
	},

	-- ZONE 4: BOHOL & PALAWAN GUBAT -------------------------------
	pilandok = {
		Id = "pilandok",
		DisplayName = "Pilandok",
		Emoji = "🦌",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 1200,
		Ability = {
			AbilityId = "silent",
			Duration = 0,
			Cooldown = 0,
			Description = "Mouse-Deer Stealth: guards notice you much later.",
		},
		CagePrice = 220000,
	},
	agila = {
		Id = "agila",
		DisplayName = "Philippine Eagle",
		Emoji = "🦅",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 1400,
		Ability = {
			AbilityId = "high_jump",
			Duration = 0,
			Cooldown = 0,
			Description = "Soar higher with the Philippine Eagle!",
		},
		CagePrice = 280000,
	},
	butanding = {
		Id = "butanding",
		DisplayName = "Butanding",
		Emoji = "🐋",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 1500,
		Ability = {
			AbilityId = "coin_siphon",
			Duration = 0,
			Cooldown = 0,
			Description = "Siphons a small bonus of coins every 20 seconds.",
		},
		CagePrice = 320000,
	},
	phoenix = {
		Id = "phoenix",
		DisplayName = "Ibong Adarna",
		Emoji = "🐦",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 500,
		Ability = {
			AbilityId = "revive",
			Duration = 0,
			Cooldown = 60,
			Description = "Ignores being caught once (60s cooldown).",
		},
		CagePrice = 400000,
	},

	-- ZONE 5: BULKANG MAYON RIDGE ---------------------------------
	tamaraw = {
		Id = "tamaraw",
		DisplayName = "Tamaraw",
		Emoji = "🐃",
		Rarity = "Mythic",
		Type = "Money",
		IncomePerSec = 3800,
		Ability = nil,
		CagePrice = 1100000,
	},
	sigbin = {
		Id = "sigbin",
		DisplayName = "Sigbin",
		Emoji = "🦇",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 4200,
		Ability = {
			AbilityId = "scare_dogs",
			Duration = 0,
			Cooldown = 0,
			Description = "Guard Dogs are afraid and ignore you.",
		},
		CagePrice = 1800000,
	},
	minokawa = {
		Id = "minokawa",
		DisplayName = "Minokawa",
		Emoji = "🦅",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 4800,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 3,
			Cooldown = 25,
			Description = "Freezes nearby guards for 3 seconds.",
		},
		CagePrice = 2600000,
	},

	-- ZONE 6: INTRAMUROS ROYAL VAULT ------------------------------
	sarimanok = {
		Id = "sarimanok",
		DisplayName = "Sarimanok",
		Emoji = "🦚",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 6500,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 5,
			Cooldown = 14,
			Description = "Golden Sarimanok speed burst!",
		},
		CagePrice = 4500000,
	},
	tikbalang = {
		Id = "tikbalang",
		DisplayName = "Chibi Tikbalang",
		Emoji = "🐴",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 8500,
		Ability = {
			AbilityId = "blink",
			Duration = 1,
			Cooldown = 15,
			Description = "Blink forward instantly every 15 seconds.",
		},
		CagePrice = 10000000,
	},
	bakunawa = {
		Id = "bakunawa",
		DisplayName = "Baby Bakunawa",
		Emoji = "🐉",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 11000,
		Ability = {
			AbilityId = "random_ability",
			Duration = 4,
			Cooldown = 18,
			Description = "Triggers a random active ability!",
		},
		CagePrice = 15000000,
	},

	-- ZONE 7 & 8: WORLD / MYTHICAL SANCTUARY ---------------------
	hamster = {
		Id = "hamster",
		DisplayName = "Hamster",
		Emoji = "🐹",
		Rarity = "Common",
		Type = "Money",
		IncomePerSec = 5,
		Ability = nil,
		CagePrice = 100,
	},
	raccoon = {
		Id = "raccoon",
		DisplayName = "Raccoon",
		Emoji = "🦝",
		Rarity = "Epic",
		Type = "Hybrid",
		IncomePerSec = 60,
		Ability = {
			AbilityId = "fast_carry",
			Duration = 0,
			Cooldown = 0,
			Description = "Carry cages faster.",
		},
		CagePrice = 30000,
	},
	panda = {
		Id = "panda",
		DisplayName = "Panda",
		Emoji = "🐼",
		Rarity = "Legendary",
		Type = "Money",
		IncomePerSec = 800,
		Ability = nil,
		CagePrice = 120000,
	},
	octopus = {
		Id = "octopus",
		DisplayName = "Octopus",
		Emoji = "🐙",
		Rarity = "Legendary",
		Type = "Hybrid",
		IncomePerSec = 400,
		Ability = {
			AbilityId = "coin_siphon",
			Duration = 0,
			Cooldown = 0,
			Description = "Siphons a small bonus of coins every 20 seconds.",
		},
		CagePrice = 250000,
	},
	diamond_capybara = {
		Id = "diamond_capybara",
		DisplayName = "Diamond Capybara",
		Emoji = "💎",
		Rarity = "Mythic",
		Type = "Money",
		IncomePerSec = 5000,
		Ability = nil,
		CagePrice = 1500000,
	},
	wolf = {
		Id = "wolf",
		DisplayName = "Wolf",
		Emoji = "🐺",
		Rarity = "Mythic",
		Type = "Power",
		IncomePerSec = 0,
		Ability = {
			AbilityId = "scare_dogs",
			Duration = 0,
			Cooldown = 0,
			Description = "Guard Dogs are afraid and ignore you.",
		},
		CagePrice = 2000000,
	},
	mini_dragon = {
		Id = "mini_dragon",
		DisplayName = "Mini Dragon",
		Emoji = "🐉",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 2500,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 3,
			Cooldown = 25,
			Description = "Freezes nearby guards for 3 seconds.",
		},
		CagePrice = 3000000,
	},
	shadow_kitsune = {
		Id = "shadow_kitsune",
		DisplayName = "Shadow Kitsune",
		Emoji = "🦊",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 8000,
		Ability = {
			AbilityId = "blink",
			Duration = 1,
			Cooldown = 15,
			Description = "Blink forward instantly every 15 seconds.",
		},
		CagePrice = 10000000,
	},
	rainbow_unicorn = {
		Id = "rainbow_unicorn",
		DisplayName = "Rainbow Unicorn",
		Emoji = "🦄",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 10000,
		Ability = {
			AbilityId = "random_ability",
			Duration = 4,
			Cooldown = 18,
			Description = "Triggers a random active ability!",
		},
		CagePrice = 15000000,
	},

	-- ZONE 9: VALHALLA COLISEUM -----------------------------------
	mecha_lion = {
		Id = "mecha_lion",
		DisplayName = "Mecha Lion",
		Emoji = "🦁",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 25000,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 6,
			Cooldown = 14,
			Description = "Mecha roar speed burst!",
		},
		CagePrice = 45000000,
	},
	void_phoenix = {
		Id = "void_phoenix",
		DisplayName = "Void Phoenix",
		Emoji = "🐦‍🔥",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 45000,
		Ability = {
			AbilityId = "revive",
			Duration = 0,
			Cooldown = 45,
			Description = "Revives once on catch (45s cooldown).",
		},
		CagePrice = 95000000,
	},
	semi_typhon = {
		Id = "semi_typhon",
		DisplayName = "Storm Typhon",
		Emoji = "🌪️",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 95000,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 4,
			Cooldown = 22,
			Description = "Storm-freezes guards for 4s.",
		},
		CagePrice = 220000000,
	},

	-- ZONE 10: OLYMPUS TITAN REALM --------------------------------
	semi_hydra = {
		Id = "semi_hydra",
		DisplayName = "Swamp Hydra",
		Emoji = "🐍",
		Rarity = "Secret",
		Type = "Money",
		IncomePerSec = 180000,
		Ability = nil,
		CagePrice = 480000000,
	},
	semi_golem = {
		Id = "semi_golem",
		DisplayName = "Ancient Golem",
		Emoji = "🗿",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 260000,
		Ability = {
			AbilityId = "fast_carry",
			Duration = 0,
			Cooldown = 0,
			Description = "Massive Golem strength for faster cage carry!",
		},
		CagePrice = 850000000,
	},
	titanic_kalabaw = {
		Id = "titanic_kalabaw",
		DisplayName = "Haring Kalabaw",
		Emoji = "🐃",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 550000,
		Ability = {
			AbilityId = "fast_carry",
			Duration = 0,
			Cooldown = 0,
			Description = "Royal Pinoy carabao strength!",
		},
		CagePrice = 2000000000,
	},

	-- ZONE 11: DRAGON EMPEROR CITADEL -----------------------------
	titanic_agila = {
		Id = "titanic_agila",
		DisplayName = "Haring Agila",
		Emoji = "🦅",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 900000,
		Ability = {
			AbilityId = "high_jump",
			Duration = 0,
			Cooldown = 0,
			Description = "Royal Eagle sky jump!",
		},
		CagePrice = 4500000000,
	},
	titanic_bakunawa = {
		Id = "titanic_bakunawa",
		DisplayName = "Elder Bakunawa",
		Emoji = "🐉",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 1500000,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 5,
			Cooldown = 20,
			Description = "Lunar eclipse freezes all nearby guards!",
		},
		CagePrice = 9500000000,
	},
	titanic_dragon = {
		Id = "titanic_dragon",
		DisplayName = "Celestial Dragon",
		Emoji = "🐲",
		Rarity = "Secret",
		Type = "Money",
		IncomePerSec = 2400000,
		Ability = nil,
		CagePrice = 18000000000,
	},

	-- ZONE 12: BATHALA INFINITY THRONE ----------------------------
	titanic_sarimanok = {
		Id = "titanic_sarimanok",
		DisplayName = "Bathala Sarimanok",
		Emoji = "🦚",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 4000000,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 7,
			Cooldown = 12,
			Description = "Supreme Bathala Sarimanok turbo burst!",
		},
		CagePrice = 38000000000,
	},
	godly_bathala = {
		Id = "godly_bathala",
		DisplayName = "Bathala Guardian",
		Emoji = "👑",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 8500000,
		Ability = {
			AbilityId = "silent",
			Duration = 0,
			Cooldown = 0,
			Description = "Divine stealth — Bantays cannot see you!",
		},
		CagePrice = 90000000000,
	},
	godly_astralis = {
		Id = "godly_astralis",
		DisplayName = "Astral Leviathan",
		Emoji = "🌌",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 15000000,
		Ability = {
			AbilityId = "blink",
			Duration = 1,
			Cooldown = 10,
			Description = "Cosmic warp blink every 10 seconds!",
		},
		CagePrice = 200000000000,
	},

	-- ZONES 13 TO 20: ENDGAME MULTIVERSE REALMS -------------------
	frost_wyrm = {
		Id = "frost_wyrm",
		DisplayName = "Frostbite Wyrm",
		Emoji = "❄️",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 6500000,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 5,
			Cooldown = 18,
			Description = "Blizzard breath freezes guards for 5s!",
		},
		CagePrice = 65000000000,
	},
	anubis_jackal = {
		Id = "anubis_jackal",
		DisplayName = "Pharaoh Anubis",
		Emoji = "🐺",
		Rarity = "Mythic",
		Type = "Hybrid",
		IncomePerSec = 12000000,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 6,
			Cooldown = 12,
			Description = "Desert storm speed burst!",
		},
		CagePrice = 150000000000,
	},
	kraken_lord = {
		Id = "kraken_lord",
		DisplayName = "Abyssal Kraken",
		Emoji = "🦑",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 25000000,
		Ability = {
			AbilityId = "coin_siphon",
			Duration = 0,
			Cooldown = 0,
			Description = "Deep-sea treasury siphon!",
		},
		CagePrice = 380000000000,
	},
	cyber_mecha_dragon = {
		Id = "cyber_mecha_dragon",
		DisplayName = "Cyber Dragon",
		Emoji = "🤖",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 55000000,
		Ability = {
			AbilityId = "sprint_boost",
			Duration = 7,
			Cooldown = 11,
			Description = "Hyper-thruster cyber overdrive!",
		},
		CagePrice = 950000000000,
	},
	cerberus_titan = {
		Id = "cerberus_titan",
		DisplayName = "Hades Cerberus",
		Emoji = "🐕‍🦺",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 120000000,
		Ability = {
			AbilityId = "scare_dogs",
			Duration = 0,
			Cooldown = 0,
			Description = "Underworld alpha — all dogs cower!",
		},
		CagePrice = 2500000000000,
	},
	nebula_kitsune = {
		Id = "nebula_kitsune",
		DisplayName = "Nebula Kitsune",
		Emoji = "🦊",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 280000000,
		Ability = {
			AbilityId = "blink",
			Duration = 1,
			Cooldown = 10,
			Description = "Starlight nine-tail blink!",
		},
		CagePrice = 7000000000000,
	},
	chronos_pegasus = {
		Id = "chronos_pegasus",
		DisplayName = "Chronos Pegasus",
		Emoji = "🐎",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 650000000,
		Ability = {
			AbilityId = "freeze_guards",
			Duration = 6,
			Cooldown = 15,
			Description = "Stops time for all nearby Bantays for 6s!",
		},
		CagePrice = 20000000000000,
	},
	omniverse_deity = {
		Id = "omniverse_deity",
		DisplayName = "Omniverse Seraph",
		Emoji = "✨",
		Rarity = "Secret",
		Type = "Hybrid",
		IncomePerSec = 1500000000,
		Ability = {
			AbilityId = "silent",
			Duration = 0,
			Cooldown = 0,
			Description = "Omniverse transcendence — invisible to all Bantays!",
		},
		CagePrice = 65000000000000,
	},
}

for id, pet in Pets do
	assert(pet.Id == id, `PetData key "{id}" does not match its Id "{pet.Id}"`)
	assert(Rarities.Data[pet.Rarity] ~= nil, `Pet "{id}" has unknown rarity "{pet.Rarity}"`)
end

local PetData = {}
PetData.Pets = Pets

function PetData.Get(id: string): Pet?
	return Pets[id]
end

local function sortedByPrice(list: { Pet }): { Pet }
	table.sort(list, function(a, b)
		return a.CagePrice < b.CagePrice
	end)
	return list
end

function PetData.GetAllByRarity(rarity: string): { Pet }
	local result: { Pet } = {}
	for _, pet in Pets do
		if pet.Rarity == rarity then
			table.insert(result, pet)
		end
	end
	return sortedByPrice(result)
end

function PetData.GetAllByType(petType: PetType): { Pet }
	local result: { Pet } = {}
	for _, pet in Pets do
		if pet.Type == petType then
			table.insert(result, pet)
		end
	end
	return sortedByPrice(result)
end

return PetData
