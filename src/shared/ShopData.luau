--!strict
-- ShopData.luau
-- All shop balance numbers:
--   * Treadmill Speed Trainer Tiers (each level increases how much +Speed you gain per second on the Treadmill!)
--   * Base Pet Slots (unlocks slots 4..6)
--   * Pet Sell Multiplier

local Config = require(script.Parent.Config)
local PetData = require(script.Parent.PetData)
local MutationData = require(script.Parent.MutationData)

local ShopData = {
	Speed = {
		MaxLevel = 25,
		SpeedPerLevel = 0.8, -- kept for backward compatibility
		BaseGainPerSec = 2, -- Tier 0 = +2/s; doubles every level (Tier 6 = +100, Tier 7 = +200, Tier 8 = +400!)
		GainPerLevel = 10,
		BasePrice = 250,
		PriceGrowth = 3.2,
		TierGains = {
			[0] = 2,
			[1] = 4,
			[2] = 8,
			[3] = 15,
			[4] = 30,
			[5] = 50,
			[6] = 100, -- Level 6 = +100 Speed/sec!
			[7] = 200, -- Level 7 = +200 Speed/sec!
			[8] = 400, -- Level 8 = +400 Speed/sec!
			[9] = 800,
			[10] = 1600,
			[11] = 3200,
			[12] = 6400,
			[13] = 12800,
			[14] = 25600,
			[15] = 51200,
			[16] = 102400,
			[17] = 204800,
			[18] = 409600,
			[19] = 819200,
			[20] = 1638400,
			[21] = 3276800,
			[22] = 6553600,
			[23] = 13107200,
			[24] = 26214400,
			[25] = 52428800,
		},
		TierPrices = {
			[0] = 250,
			[1] = 900,
			[2] = 3200,
			[3] = 11000,
			[4] = 38000,
			[5] = 130000,
			[6] = 450000,
			[7] = 1500000,
			[8] = 5000000,
			[9] = 16000000,
			[10] = 55000000,
			[11] = 180000000,
			[12] = 600000000,
			[13] = 2000000000,
			[14] = 6500000000,
			[15] = 22000000000,
			[16] = 75000000000,
			[17] = 250000000000,
			[18] = 850000000000,
			[19] = 2800000000000,
			[20] = 9500000000000,
			[21] = 32000000000000,
			[22] = 110000000000000,
			[23] = 380000000000000,
			[24] = 1300000000000000,
		},
	},
	TreadmillTiers = {
		[0] = {
			Name = "Tsinelas Lakad Pad",
			PlatformColor = Color3.fromRGB(115, 78, 42),
			PlatformMat = Enum.Material.WoodPlanks,
			BeltColor = Color3.fromRGB(45, 38, 32),
			RailColor = Color3.fromRGB(145, 102, 56),
			RailMat = Enum.Material.Wood,
			AccentColor = Color3.fromRGB(0, 225, 255),
			RunSpeed = 12,
		},
		[1] = {
			Name = "Kawayan Roller",
			PlatformColor = Color3.fromRGB(135, 118, 65),
			PlatformMat = Enum.Material.WoodPlanks,
			BeltColor = Color3.fromRGB(42, 46, 36),
			RailColor = Color3.fromRGB(168, 148, 82),
			RailMat = Enum.Material.Wood,
			AccentColor = Color3.fromRGB(80, 255, 130),
			RunSpeed = 14,
		},
		[2] = {
			Name = "Palengke Karton Runner",
			PlatformColor = Color3.fromRGB(45, 115, 68),
			PlatformMat = Enum.Material.Plastic,
			BeltColor = Color3.fromRGB(28, 36, 32),
			RailColor = Color3.fromRGB(65, 165, 95),
			RailMat = Enum.Material.SmoothPlastic,
			AccentColor = Color3.fromRGB(120, 255, 95),
			RunSpeed = 16,
		},
		[3] = {
			Name = "Bakal Gym Treadmill",
			PlatformColor = Color3.fromRGB(48, 56, 72),
			PlatformMat = Enum.Material.DiamondPlate,
			BeltColor = Color3.fromRGB(24, 28, 36),
			RailColor = Color3.fromRGB(85, 95, 115),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(0, 210, 255),
			RunSpeed = 19,
		},
		[4] = {
			Name = "Sabungan Derby Runner",
			PlatformColor = Color3.fromRGB(145, 35, 35),
			PlatformMat = Enum.Material.Metal,
			BeltColor = Color3.fromRGB(32, 22, 24),
			RailColor = Color3.fromRGB(215, 55, 45),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(255, 215, 55),
			RunSpeed = 22,
		},
		[5] = {
			Name = "Jeepney Makina Belt",
			PlatformColor = Color3.fromRGB(195, 145, 30),
			PlatformMat = Enum.Material.DiamondPlate,
			BeltColor = Color3.fromRGB(30, 28, 22),
			RailColor = Color3.fromRGB(230, 185, 55),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(255, 135, 45),
			RunSpeed = 25,
		},
		[6] = {
			Name = "Turbo Hacienda Pro",
			PlatformColor = Color3.fromRGB(75, 48, 32),
			PlatformMat = Enum.Material.Marble,
			BeltColor = Color3.fromRGB(24, 22, 28),
			RailColor = Color3.fromRGB(215, 165, 75),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(255, 175, 50),
			RunSpeed = 28,
		},
		[7] = {
			Name = "Bulkang Mayon Lava Track",
			PlatformColor = Color3.fromRGB(42, 32, 32),
			PlatformMat = Enum.Material.Basalt,
			BeltColor = Color3.fromRGB(26, 18, 18),
			RailColor = Color3.fromRGB(95, 45, 38),
			RailMat = Enum.Material.Basalt,
			AccentColor = Color3.fromRGB(255, 75, 35),
			RunSpeed = 32,
		},
		[8] = {
			Name = "Kidlat Takbuhan X",
			PlatformColor = Color3.fromRGB(52, 36, 88),
			PlatformMat = Enum.Material.Metal,
			BeltColor = Color3.fromRGB(22, 18, 36),
			RailColor = Color3.fromRGB(135, 80, 225),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(215, 80, 255),
			RunSpeed = 36,
		},
		[9] = {
			Name = "Gintong Agila Strider",
			PlatformColor = Color3.fromRGB(175, 135, 35),
			PlatformMat = Enum.Material.Metal,
			BeltColor = Color3.fromRGB(32, 28, 18),
			RailColor = Color3.fromRGB(255, 205, 65),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(255, 235, 90),
			RunSpeed = 40,
		},
		[10] = {
			Name = "Bagyong Bathala Supreme",
			PlatformColor = Color3.fromRGB(35, 25, 65),
			PlatformMat = Enum.Material.Marble,
			BeltColor = Color3.fromRGB(18, 15, 32),
			RailColor = Color3.fromRGB(255, 215, 65),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 55, 145),
			RunSpeed = 46,
		},
		[11] = {
			Name = "Valhalla Thunder Track",
			PlatformColor = Color3.fromRGB(45, 58, 95),
			PlatformMat = Enum.Material.Marble,
			BeltColor = Color3.fromRGB(22, 28, 48),
			RailColor = Color3.fromRGB(120, 215, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(80, 200, 255),
			RunSpeed = 50,
		},
		[12] = {
			Name = "Olympus Titan Strider",
			PlatformColor = Color3.fromRGB(185, 145, 55),
			PlatformMat = Enum.Material.Marble,
			BeltColor = Color3.fromRGB(28, 22, 16),
			RailColor = Color3.fromRGB(255, 215, 95),
			RailMat = Enum.Material.Metal,
			AccentColor = Color3.fromRGB(255, 165, 45),
			RunSpeed = 54,
		},
		[13] = {
			Name = "Dragon Emperor Runner",
			PlatformColor = Color3.fromRGB(95, 18, 24),
			PlatformMat = Enum.Material.Basalt,
			BeltColor = Color3.fromRGB(24, 12, 14),
			RailColor = Color3.fromRGB(255, 65, 65),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 75, 45),
			RunSpeed = 58,
		},
		[14] = {
			Name = "Astral Void Treadmill",
			PlatformColor = Color3.fromRGB(28, 16, 58),
			PlatformMat = Enum.Material.ForceField,
			BeltColor = Color3.fromRGB(12, 8, 26),
			RailColor = Color3.fromRGB(190, 95, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(180, 85, 255),
			RunSpeed = 62,
		},
		[15] = {
			Name = "Phoenix Flare Accelerator",
			PlatformColor = Color3.fromRGB(125, 42, 18),
			PlatformMat = Enum.Material.Metal,
			BeltColor = Color3.fromRGB(28, 14, 10),
			RailColor = Color3.fromRGB(255, 145, 35),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 185, 45),
			RunSpeed = 66,
		},
		[16] = {
			Name = "Semi-Titanic Hyper Belt",
			PlatformColor = Color3.fromRGB(65, 35, 18),
			PlatformMat = Enum.Material.DiamondPlate,
			BeltColor = Color3.fromRGB(20, 14, 10),
			RailColor = Color3.fromRGB(255, 125, 25),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 145, 35),
			RunSpeed = 70,
		},
		[17] = {
			Name = "Titanic Crimson Engine",
			PlatformColor = Color3.fromRGB(85, 14, 28),
			PlatformMat = Enum.Material.Metal,
			BeltColor = Color3.fromRGB(22, 8, 14),
			RailColor = Color3.fromRGB(255, 45, 95),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 45, 75),
			RunSpeed = 74,
		},
		[18] = {
			Name = "Cosmic Quantum Runner",
			PlatformColor = Color3.fromRGB(18, 42, 68),
			PlatformMat = Enum.Material.Marble,
			BeltColor = Color3.fromRGB(8, 18, 32),
			RailColor = Color3.fromRGB(0, 245, 225),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(0, 255, 235),
			RunSpeed = 78,
		},
		[19] = {
			Name = "Godly Celestial Warp",
			PlatformColor = Color3.fromRGB(45, 65, 95),
			PlatformMat = Enum.Material.ForceField,
			BeltColor = Color3.fromRGB(16, 22, 38),
			RailColor = Color3.fromRGB(165, 255, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(165, 255, 255),
			RunSpeed = 82,
		},
		[20] = {
			Name = "Bathala Infinity Throne",
			PlatformColor = Color3.fromRGB(255, 215, 75),
			PlatformMat = Enum.Material.Neon,
			BeltColor = Color3.fromRGB(18, 16, 28),
			RailColor = Color3.fromRGB(255, 255, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 235, 120),
			RunSpeed = 88,
		},
		[21] = {
			Name = "Nebula Star Strider",
			PlatformColor = Color3.fromRGB(48, 22, 85),
			PlatformMat = Enum.Material.Neon,
			BeltColor = Color3.fromRGB(14, 10, 28),
			RailColor = Color3.fromRGB(235, 110, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(245, 130, 255),
			RunSpeed = 90,
		},
		[22] = {
			Name = "Supernova Overdrive",
			PlatformColor = Color3.fromRGB(215, 75, 25),
			PlatformMat = Enum.Material.Neon,
			BeltColor = Color3.fromRGB(26, 12, 10),
			RailColor = Color3.fromRGB(255, 215, 55),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 185, 45),
			RunSpeed = 92,
		},
		[23] = {
			Name = "Chronos Time Runner",
			PlatformColor = Color3.fromRGB(25, 85, 95),
			PlatformMat = Enum.Material.ForceField,
			BeltColor = Color3.fromRGB(10, 24, 28),
			RailColor = Color3.fromRGB(95, 255, 225),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(110, 255, 230),
			RunSpeed = 94,
		},
		[24] = {
			Name = "Multiverse Infinity Belt",
			PlatformColor = Color3.fromRGB(85, 18, 115),
			PlatformMat = Enum.Material.ForceField,
			BeltColor = Color3.fromRGB(18, 8, 28),
			RailColor = Color3.fromRGB(255, 95, 215),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(255, 120, 235),
			RunSpeed = 96,
		},
		[25] = {
			Name = "Omniverse Supreme Core",
			PlatformColor = Color3.fromRGB(255, 245, 195),
			PlatformMat = Enum.Material.Neon,
			BeltColor = Color3.fromRGB(15, 15, 25),
			RailColor = Color3.fromRGB(145, 255, 255),
			RailMat = Enum.Material.Neon,
			AccentColor = Color3.fromRGB(145, 255, 255),
			RunSpeed = 100,
		},
	},
	PetSlots = {
		Prices = {
			2500,
			12000,
			50000,
			200000,
			800000,
			3000000,
			12000000,
			45000000,
			175000000,
			650000000,
			2500000000,
			9500000000,
			35000000000,
			130000000000,
			500000000000,
			1800000000000,
			6500000000000,
			24000000000000,
			90000000000000,
			350000000000000,
			1200000000000000,
			4500000000000000,
		},
	},
	SellMultiplier = 0.5,

	-- Street Food Feeding ("Alaga & Pakain") -> Triggers 10-minute "Busog Mode" (+20% $/s tick rate!)
	BusogIncomeMultiplier = 1.20,
	StreetFoods = {
		fishball = {
			Id = "fishball",
			DisplayName = "Tusok-Tusok Fishball",
			Emoji = "🍡",
			Cost = 500,
			DurationSeconds = 600, -- 10 minutes
			Description = "Crispy golden street fishballs in sweet-spicy manong sauce! Triggers 10m Busog Mode (+20% $/s)!",
		},
		kwek_kwek = {
			Id = "kwek_kwek",
			DisplayName = "Kwek-Kwek & Pipino",
			Emoji = "🟠",
			Cost = 3500,
			DurationSeconds = 600,
			Description = "Orange-battered quail eggs with cucumber vinegar! Triggers 10m Busog Mode (+20% $/s) + Instant Joy!",
		},
		banana_cue = {
			Id = "banana_cue",
			DisplayName = "Caramel Banana Cue",
			Emoji = "🍌",
			Cost = 25000,
			DurationSeconds = 600,
			Description = "Skewered Saba bananas coated in crunchy brown sugar caramel! Triggers 10m Busog Mode (+20% $/s)!",
		},
		halo_halo = {
			Id = "halo_halo",
			DisplayName = "Espesyal Halo-Halo",
			Emoji = "🍧",
			Cost = 150000,
			DurationSeconds = 600,
			Description = "Shaved ice topped with leche flan & ube halaya! Triggers 10m Busog Mode (+20% $/s)!",
		},
	},
	StreetFoodOrder = { "fishball", "kwek_kwek", "banana_cue", "halo_halo" },

	-- Plot Evolution Architecture Tiers (auto-evolves player plot based on $/s or Cash milestones!)
	PlotEvolutionTiers = {
		[1] = {
			Tier = 1,
			Title = "🛖 Kawayan Bakod & Nipa Hut (Kubo)",
			MinIncomePerSec = 0,
			MinMoney = 0,
			AccentColor = Color3.fromRGB(165, 225, 110),
		},
		[2] = {
			Tier = 2,
			Title = "🏛️ Bahay na Bato Courtyard",
			MinIncomePerSec = 25000,
			MinMoney = 250000,
			AccentColor = Color3.fromRGB(255, 205, 85),
		},
		[3] = {
			Tier = 3,
			Title = "👑 Intramuros Royal Courtyard",
			MinIncomePerSec = 5000000,
			MinMoney = 50000000,
			AccentColor = Color3.fromRGB(255, 145, 220),
		},
	},
}

export type StreetFoodInfo = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Cost: number,
	DurationSeconds: number,
	Description: string,
}

function ShopData.GetStreetFood(foodId: string): StreetFoodInfo?
	return (ShopData.StreetFoods :: { [string]: StreetFoodInfo })[foodId]
end

function ShopData.GetPlotEvolutionTier(incomePerSec: number, money: number): number
	if incomePerSec >= 5000000 or money >= 50000000 then
		return 3
	elseif incomePerSec >= 25000 or money >= 250000 then
		return 2
	end
	return 1
end

function ShopData.GetTreadmillTierInfo(trainerLevel: number)
	local clamped = math.clamp(math.floor(trainerLevel), 0, ShopData.Speed.MaxLevel)
	return ShopData.TreadmillTiers[clamped] or ShopData.TreadmillTiers[0]
end

-- Converts a Steal-a-Pet style Speed Stat (16 -> 900 -> 10K -> 40K -> 170K -> 75M) into a controllable physical Roblox WalkSpeed (16..74).
function ShopData.StatToPhysicalWalkSpeed(speedStat: number): number
	if speedStat <= 16 then
		return 16
	end
	local ratio = math.max(1, speedStat / 16)
	return math.clamp(16 + math.log10(ratio) * 7.6, 16, 86)
end

function ShopData.GetTrainerGainPerSec(trainerLevel: number): number
	local clamped = math.clamp(math.floor(trainerLevel), 0, ShopData.Speed.MaxLevel)
	return ShopData.Speed.TierGains[clamped] or (ShopData.Speed.BaseGainPerSec + clamped * ShopData.Speed.GainPerLevel)
end

function ShopData.GetSpeedPrice(currentLevel: number): number?
	if currentLevel >= ShopData.Speed.MaxLevel then
		return nil
	end
	local clamped = math.clamp(math.floor(currentLevel), 0, ShopData.Speed.MaxLevel - 1)
	return ShopData.Speed.TierPrices[clamped] or math.floor(ShopData.Speed.BasePrice * (ShopData.Speed.PriceGrowth ^ clamped))
end

function ShopData.GetSlotPrice(currentSlots: number): number?
	local index = currentSlots - Config.StartingPetSlots + 1
	if index < 1 or index > #ShopData.PetSlots.Prices then
		return nil
	end
	return ShopData.PetSlots.Prices[index]
end

function ShopData.GetSellValue(petId: string, mutation: string?): number
	local pet = PetData.Get(petId)
	if not pet then
		return 0
	end
	local mult = MutationData.GetMultiplier(mutation)
	return math.floor(pet.CagePrice * ShopData.SellMultiplier * mult)
end

return ShopData
