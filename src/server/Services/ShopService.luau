--!strict
-- ShopService.luau (SERVER)
-- Handles "ShopRequest" RemoteFunction for BuySpeed, BuySlot, and SellPet.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopData = require(Shared:WaitForChild("ShopData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

export type ShopResponse = {
	Ok: boolean,
	Message: string,
}

local ShopService = {}
local feedStationSetup: { [Instance]: boolean } = {}

function ShopService.FeedPetsStreetFood(player: Player, foodId: string): ShopResponse
	if not DataService.IsLoaded(player) then
		return { Ok = false, Message = "Data is still loading." }
	end
	local food = ShopData.GetStreetFood(foodId) or ShopData.GetStreetFood("fishball")
	if not food then
		return { Ok = false, Message = "Unknown street food." }
	end
	if not EconomyService.TrySpend(player, food.Cost) then
		return {
			Ok = false,
			Message = `Need $${NumberFormat.Short(food.Cost)} to buy {food.Emoji} {food.DisplayName}!`,
		}
	end

	local now = workspace:GetServerTimeNow()
	local curAttr = player:GetAttribute("PetBusogUntil")
	local curUntil = if typeof(curAttr) == "number" and curAttr > now then curAttr else now
	-- Stack up to 30 minutes max
	local newUntil = math.min(now + 1800, curUntil + food.DurationSeconds)
	player:SetAttribute("PetBusogUntil", newUntil)
	player:SetAttribute("LastStreetFood", `{food.Emoji} {food.DisplayName}`)

	BaseService.Refresh(player)
	Remotes.GetEvent("PetFedVfx"):FireClient(player, food.Id, food.Emoji, food.DisplayName)

	local mins = math.ceil((newUntil - now) / 60)
	return {
		Ok = true,
		Message = `{food.Emoji} Fed pets {food.DisplayName}! BUSOG MODE active (+20% $/s for {mins}m)!`,
	}
end

function ShopService.HandleRequest(player: Player, action: any, arg: any): ShopResponse
	if not DataService.IsLoaded(player) then
		return { Ok = false, Message = "Data is still loading." }
	end
	if typeof(action) ~= "string" then
		return { Ok = false, Message = "Invalid action." }
	end

	if action == "BuySpeed" then
		local currentLevel = StatsService.GetSpeedLevel(player)
		local price = ShopData.GetSpeedPrice(currentLevel)
		if not price then
			return { Ok = false, Message = "Treadmill Trainer is already at max tier!" }
		end
		if not EconomyService.TrySpend(player, price) then
			return { Ok = false, Message = `Need ${NumberFormat.Short(price)}!` }
		end
		StatsService.SetSpeedLevel(player, currentLevel + 1)
		local newGain = ShopData.GetTrainerGainPerSec(currentLevel + 1)
		return { Ok = true, Message = string.format("🏃 Treadmill Upgraded to Tier %d (+%.2f Speed/sec)!", currentLevel + 1, newGain) }
	elseif action == "BuySlot" then
		local currentSlots = InventoryService.GetPetSlots(player)
		local maxSlots = InventoryService.GetMaxPetSlots(player)
		if currentSlots >= maxSlots then
			return { Ok = false, Message = "All pet slots unlocked!" }
		end
		local price = ShopData.GetSlotPrice(currentSlots)
		if not price then
			return { Ok = false, Message = "No more purchasable slots!" }
		end
		if not EconomyService.TrySpend(player, price) then
			return { Ok = false, Message = `Need ${NumberFormat.Short(price)}!` }
		end
		InventoryService.SetPetSlots(player, currentSlots + 1)
		InventoryService.AutoPlaceStored(player)
		return { Ok = true, Message = `Unlocked Pet Slot #{currentSlots + 1}!` }
	elseif action == "SellPet" then
		if typeof(arg) ~= "string" or arg == "" then
			return { Ok = false, Message = "Invalid pet." }
		end
		local owned = InventoryService.GetPetByUid(player, arg)
		if not owned then
			return { Ok = false, Message = "Pet not found." }
		end
		if owned.InTransit then
			return { Ok = false, Message = "Cannot sell a pet right now." }
		end
		local value = ShopData.GetSellValue(owned.PetId, owned.Mutation)
		if not InventoryService.RemovePet(player, arg) then
			return { Ok = false, Message = "Could not remove pet." }
		end
		EconomyService.AddMoney(player, value)
		return { Ok = true, Message = `💰 Sold for $${NumberFormat.Short(value)}!` }
	elseif action == "SellPetsBatch" then
		if typeof(arg) ~= "table" then
			return { Ok = false, Message = "Select at least 1 pet to sell!" }
		end
		local totalEarned = 0
		local soldCount = 0
		for _, uid in arg do
			if typeof(uid) == "string" and uid ~= "" then
				local owned = InventoryService.GetPetByUid(player, uid)
				if owned and not owned.InTransit and owned.State ~= "Placed" and not owned.Equipped then
					local value = ShopData.GetSellValue(owned.PetId, owned.Mutation)
					if InventoryService.RemovePet(player, uid) then
						totalEarned += value
						soldCount += 1
					end
				end
			end
		end
		if soldCount == 0 then
			return { Ok = false, Message = "No unused pets were selected to sell." }
		end
		EconomyService.AddMoney(player, totalEarned)
		return { Ok = true, Message = `💰 Sold {soldCount} pet(s) for $${NumberFormat.Short(totalEarned)}!` }
	elseif action == "BuyStreetFood" then
		local foodId = if typeof(arg) == "string" and arg ~= "" then arg else "fishball"
		return ShopService.FeedPetsStreetFood(player, foodId)
	end

	return { Ok = false, Message = "Unknown shop action." }
end

local function setupFeedStationPrompt(instance: Instance)
	if feedStationSetup[instance] or not instance:IsA("BasePart") then
		return
	end
	feedStationSetup[instance] = true
	instance.Destroying:Connect(function()
		feedStationSetup[instance] = nil
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedPetsPrompt"
	prompt.ActionText = "Pakainin ang Pets ($500 Fishball)"
	prompt.ObjectText = "🍡 Alaga & Pakain (10m Busog +20% $/s)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if not RateLimiter.Check(player, "FeedStationPrompt", 0.35) then
			return
		end
		local res = ShopService.FeedPetsStreetFood(player, "fishball")
		ClientSyncService.Notify(
			player,
			res.Message,
			if res.Ok then Color3.fromRGB(110, 255, 130) else Color3.fromRGB(255, 95, 95)
		)
	end)
	prompt.Parent = instance
end

function ShopService.Init()
	Remotes.GetEvent("PetFedVfx")
	local fn = Remotes.GetFunction("ShopRequest")
	fn.OnServerInvoke = function(player: Player, action: any, arg: any): ShopResponse
		if not RateLimiter.Check(player, "ShopRequest", 0.2) then
			return { Ok = false, Message = "Too fast! Slow down." }
		end
		return ShopService.HandleRequest(player, action, arg)
	end

	for _, inst in CollectionService:GetTagged("PlotFeedStation") do
		task.spawn(setupFeedStationPrompt, inst)
	end
	CollectionService:GetInstanceAddedSignal("PlotFeedStation"):Connect(setupFeedStationPrompt)
end

return ShopService
