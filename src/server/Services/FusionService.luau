--!strict
-- FusionService.luau (SERVER)
-- Combines 3 pets of the same rarity for a chance at a pet of the next rarity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FusionData = require(Shared:WaitForChild("FusionData"))
local PetData = require(Shared:WaitForChild("PetData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

export type FusionResponse = {
	Ok: boolean,
	Message: string,
	ResultPetId: string?,
	Success: boolean?,
}

local FusionService = {}
local rng = Random.new()

function FusionService.HandleRequest(player: Player, uids: any): FusionResponse
	if not DataService.IsLoaded(player) then
		return { Ok = false, Message = "Data is still loading." }
	end
	if typeof(uids) ~= "table" or #uids ~= FusionData.FuseCount then
		return { Ok = false, Message = `Select exactly {FusionData.FuseCount} pets.` }
	end

	local seen: { [string]: boolean } = {}
	local rarity: string? = nil

	for _, uid in uids do
		if typeof(uid) ~= "string" or uid == "" or seen[uid] then
			return { Ok = false, Message = "Invalid or duplicate pets selected." }
		end
		seen[uid] = true

		local owned = InventoryService.GetPetByUid(player, uid)
		if not owned then
			return { Ok = false, Message = "One of the selected pets is no longer in your inventory." }
		end
		if owned.Equipped then
			return { Ok = false, Message = "Unequip a pet before fusing it." }
		end
		if owned.InTransit then
			return { Ok = false, Message = "One of your pets is currently in transit." }
		end

		local info = PetData.Get(owned.PetId)
		if not info then
			return { Ok = false, Message = "Unknown pet data." }
		end

		if not rarity then
			rarity = info.Rarity
		elseif rarity ~= info.Rarity then
			return { Ok = false, Message = "All 3 pets must have the exact same rarity!" }
		end
	end

	if not rarity then
		return { Ok = false, Message = "Invalid selection." }
	end

	local rule = FusionData.GetRule(rarity)
	if not rule then
		return { Ok = false, Message = `{rarity} pets cannot be fused any higher!` }
	end

	if not EconomyService.TrySpend(player, rule.Cost) then
		return { Ok = false, Message = `Need ${NumberFormat.Short(rule.Cost)} to fuse!` }
	end

	for _, uid in uids do
		InventoryService.RemovePet(player, uid)
	end

	local success = rng:NextNumber() <= rule.SuccessChance
	local targetRarity = if success then rule.NextRarity else rarity
	local pool = PetData.GetAllByRarity(targetRarity)
	local picked = pool[rng:NextInteger(1, #pool)]

	InventoryService.AddPet(player, picked.Id, nil)

	local msg = if success
		then `✨ FUSION SUCCESS! You got {picked.Emoji} {picked.DisplayName} ({targetRarity})!`
		else `Fusion failed! Returned {picked.Emoji} {picked.DisplayName} ({targetRarity}).`

	return {
		Ok = true,
		Message = msg,
		ResultPetId = picked.Id,
		Success = success,
	}
end

function FusionService.Init()
	local fn = Remotes.GetFunction("FusionRequest")
	fn.OnServerInvoke = function(player: Player, uids: any): FusionResponse
		if not RateLimiter.Check(player, "FusionRequest", 0.4) then
			return { Ok = false, Message = "Too fast! Slow down." }
		end
		return FusionService.HandleRequest(player, uids)
	end
end

return FusionService
