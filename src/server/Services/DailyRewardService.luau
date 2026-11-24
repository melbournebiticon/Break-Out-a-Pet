--!strict
-- DailyRewardService.luau (SERVER)
-- Handles "DailyClaim" RemoteFunction with UTC day streak validation and bonus pet rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventData = require(Shared:WaitForChild("EventData"))
local CageLoot = require(Shared:WaitForChild("CageLoot"))
local PetData = require(Shared:WaitForChild("PetData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

export type DailyClaimResponse = {
	Ok: boolean,
	Message: string,
	Day: number?,
}

local DailyRewardService = {}

local function getUtcDay(): number
	return math.floor(os.time() / 86400)
end

function DailyRewardService.HandleClaim(player: Player): DailyClaimResponse
	local profile = DataService.GetProfile(player)
	if not profile then
		return { Ok = false, Message = "Data is still loading." }
	end

	local today = getUtcDay()
	if profile.LastDailyClaimDay == today then
		return { Ok = false, Message = "You already claimed today's reward! Come back tomorrow." }
	end

	if profile.LastDailyClaimDay == today - 1 then
		profile.DailyStreak = (profile.DailyStreak % #EventData.DailyRewards) + 1
	else
		profile.DailyStreak = 1
	end
	profile.LastDailyClaimDay = today

	player:SetAttribute("DailyStreak", profile.DailyStreak)
	player:SetAttribute("LastDailyClaimDay", profile.LastDailyClaimDay)
	DataService.MarkDirty(player)

	local reward = EventData.DailyRewards[profile.DailyStreak]
	EconomyService.AddMoney(player, reward.Money)

	local bonusText = ""
	if reward.BonusPetZone then
		local ok, petId = pcall(CageLoot.Roll, reward.BonusPetZone)
		if ok and typeof(petId) == "string" then
			InventoryService.AddPet(player, petId, nil)
			local petInfo = PetData.Get(petId)
			if petInfo then
				bonusText = ` + {petInfo.Emoji} {petInfo.DisplayName}`
			end
		end
	end

	return {
		Ok = true,
		Message = `🎁 Day {profile.DailyStreak} Claimed: +${NumberFormat.Short(reward.Money)}{bonusText}!`,
		Day = profile.DailyStreak,
	}
end

function DailyRewardService.Init()
	local fn = Remotes.GetFunction("DailyClaim")
	fn.OnServerInvoke = function(player: Player): DailyClaimResponse
		if not RateLimiter.Check(player, "DailyClaim", 0.5) then
			return { Ok = false, Message = "Please wait." }
		end
		return DailyRewardService.HandleClaim(player)
	end
end

return DailyRewardService
