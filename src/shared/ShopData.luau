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
		SpeedPerLevel = 0.8, -- kept for backward compatibility; also used as bonus speed per trainer tier
		BaseGainPerSec = 0.20, -- +0.20 WalkSpeed per second at Trainer Tier 0
		GainPerLevel = 0.18, -- extra +0.18 WalkSpeed/sec per Trainer Tier upgrade
		BasePrice = 200,
		PriceGrowth = 1.85,
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
		Prices = { 5000, 50000, 500000 },
	},
	SellMultiplier = 0.5,
}

function ShopData.GetTreadmillTierInfo(trainerLevel: number)
	local clamped = math.clamp(math.floor(trainerLevel), 0, ShopData.Speed.MaxLevel)
	return ShopData.TreadmillTiers[clamped] or ShopData.TreadmillTiers[0]
end

function ShopData.GetTrainerGainPerSec(trainerLevel: number): number
	return ShopData.Speed.BaseGainPerSec + math.max(0, trainerLevel) * ShopData.Speed.GainPerLevel
end

function ShopData.GetSpeedPrice(currentLevel: number): number?
	if currentLevel >= ShopData.Speed.MaxLevel then
		return nil
	end
	return math.floor(ShopData.Speed.BasePrice * (ShopData.Speed.PriceGrowth ^ currentLevel))
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
