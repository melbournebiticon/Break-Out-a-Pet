--!strict
-- PetActionService.luau (SERVER)
-- Handles "PetActionRequest" RemoteFunction for Place, Unplace, Equip, and Unequip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

export type ActionResponse = {
	Ok: boolean,
	Message: string,
}

local PetActionService = {}

function PetActionService.HandleRequest(player: Player, action: any, arg1: any, arg2: any): ActionResponse
	if not DataService.IsLoaded(player) then
		return { Ok = false, Message = "Data is still loading." }
	end
	if typeof(action) ~= "string" then
		return { Ok = false, Message = "Invalid action." }
	end

	if action == "Place" then
		if typeof(arg1) ~= "string" or arg1 == "" then
			return { Ok = false, Message = "Invalid pet ID." }
		end
		local slotIndex: number? = if typeof(arg2) == "number" then math.floor(arg2) else nil
		if InventoryService.PlacePet(player, arg1, slotIndex) then
			return { Ok = true, Message = "Pet placed on plot!" }
		end
		return { Ok = false, Message = "No free unlocked slot (or Power pets cannot be placed)." }
	elseif action == "Unplace" then
		if typeof(arg1) ~= "string" or arg1 == "" then
			return { Ok = false, Message = "Invalid pet ID." }
		end
		if InventoryService.UnplacePet(player, arg1) then
			return { Ok = true, Message = "Pet returned to storage." }
		end
		return { Ok = false, Message = "Could not unplace pet." }
	elseif action == "Equip" then
		if typeof(arg1) ~= "string" or arg1 == "" then
			return { Ok = false, Message = "Invalid pet ID." }
		end
		if InventoryService.Equip(player, arg1) then
			return { Ok = true, Message = "Pet equipped for heist!" }
		end
		return { Ok = false, Message = "Only pets with an Ability can be equipped." }
	elseif action == "Unequip" then
		if InventoryService.Unequip(player) then
			return { Ok = true, Message = "Pet unequipped." }
		end
		return { Ok = false, Message = "Nothing is equipped." }
	elseif action == "EquipBest" then
		local count = InventoryService.EquipBest(player)
		return { Ok = true, Message = `⚡ Equipped your best pets ({count} placed on plot)!` }
	end

	return { Ok = false, Message = "Unknown pet action." }
end

function PetActionService.Init()
	local fn = Remotes.GetFunction("PetActionRequest")
	fn.OnServerInvoke = function(player: Player, action: any, arg1: any, arg2: any): ActionResponse
		if not RateLimiter.Check(player, "PetActionRequest", 0.2) then
			return { Ok = false, Message = "Too fast! Slow down." }
		end
		return PetActionService.HandleRequest(player, action, arg1, arg2)
	end
end

return PetActionService
