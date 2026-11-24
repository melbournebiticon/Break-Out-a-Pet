--!strict
-- ShopData.luau
-- All shop balance numbers:
--   * Treadmill Speed Trainer Tiers (each level increases how much +Speed you gain per second on the Treadmill!)
--   * Base Pet Slots (unlocks slots 4..6)
--   * Pet Sell Multiplier

local Config = require(script.Parent.Config)
local PetData = require(script.Parent.PetData)

local ShopData = {
	Speed = {
		MaxLevel = 10,
		SpeedPerLevel = 0.8, -- kept for backward compatibility
		BaseGainPerSec = 15, -- +15 Speed/sec at Tier 0 (grind up to 900 -> 10K -> 40K -> 170K+!)
		GainPerLevel = 50,
		BasePrice = 350,
		PriceGrowth = 4.2,
		TierGains = {
			[0] = 15,
			[1] = 45,
			[2] = 150,
			[3] = 520,
			[4] = 1800,
			[5] = 6500,
			[6] = 24000,
			[7] = 90000,
			[8] = 350000,
			[9] = 1400000,
			[10] = 5500000,
		},
		TierPrices = {
			[0] = 350,
			[1] = 1800,
			[2] = 8500,
			[3] = 40000,
			[4] = 180000,
			[5] = 800000,
			[6] = 3500000,
			[7] = 16000000,
			[8] = 75000000,
			[9] = 350000000,
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
	},
	PetSlots = {
		Prices = { 2500, 15000, 75000, 350000, 1500000, 6000000, 25000000, 100000000, 400000000 },
	},
	SellMultiplier = 0.5,
}

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
	return math.clamp(16 + math.log10(ratio) * 7.2, 16, 74)
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

function ShopData.GetSellValue(petId: string): number
	local pet = PetData.Get(petId)
	if not pet then
		return 0
	end
	return math.floor(pet.CagePrice * ShopData.SellMultiplier)
end

return ShopData
