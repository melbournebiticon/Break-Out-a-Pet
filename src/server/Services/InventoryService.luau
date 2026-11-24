--!strict
-- InventoryService.luau (SERVER)
-- Manages each player's owned pets, placement in base slots, and equipped heist pet.
-- Backed by DataService profile as the single source of truth.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

export type OwnedPet = DataService.SavedPet

local InventoryService = {}

local PetsChangedEvent = Instance.new("BindableEvent")
InventoryService.PetsChanged = PetsChangedEvent.Event
InventoryService.PetsChangedEvent = PetsChangedEvent

local maxSlotsGetter: ((Player) -> number)? = nil
local slotBlockedChecker: ((Player, number) -> boolean)? = nil

function InventoryService.SetMaxSlotsGetter(fn: (Player) -> number)
	maxSlotsGetter = fn
end

function InventoryService.SetSlotBlockedChecker(fn: (Player, number) -> boolean)
	slotBlockedChecker = fn
end

function InventoryService.IsSlotBlocked(player: Player, slotIndex: number): boolean
	if slotBlockedChecker then
		return slotBlockedChecker(player, slotIndex)
	end
	return false
end

function InventoryService.GetMaxPetSlots(player: Player): number
	if maxSlotsGetter then
		return maxSlotsGetter(player)
	end
	return Config.MaxPetSlots
end

local function ensureLeaderstats(player: Player): IntValue
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local petsVal = stats:FindFirstChild("Pets")
	if petsVal and petsVal:IsA("IntValue") then
		return petsVal
	end
	local created = Instance.new("IntValue")
	created.Name = "Pets"
	created.Value = 0
	created.Parent = stats
	return created
end

local function updateEquippedAttributes(player: Player, pets: { OwnedPet })
	local equippedUid = ""
	local equippedPetId = ""
	local abilityId = ""

	for _, pet in pets do
		if pet.Equipped then
			equippedUid = pet.Uid
			equippedPetId = pet.PetId
			local info = PetData.Get(pet.PetId)
			if info and info.Ability then
				abilityId = info.Ability.AbilityId
			end
			break
		end
	end

	player:SetAttribute("EquippedUid", equippedUid)
	player:SetAttribute("EquippedPetId", equippedPetId)
	player:SetAttribute("AbilityId", abilityId)
end

-- Syncs unplaced ("Stored") pets into the player's native Roblox Backpack toolbar so they can hold & click to place!
local function syncBackpackPetTools(player: Player, pets: { OwnedPet })
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local desiredByUid: { [string]: OwnedPet } = {}
	local count = 0
	for i = #pets, 1, -1 do
		local p = pets[i]
		if p.State == "Stored" and not p.Equipped and not p.InTransit then
			desiredByUid[p.Uid] = p
			count += 1
			if count >= 7 then
				break
			end
		end
	end

	local existingByUid: { [string]: Tool } = {}
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("IsPetTool") == true then
					local uid = child:GetAttribute("PetUid")
					if typeof(uid) == "string" and desiredByUid[uid] then
						existingByUid[uid] = child
					else
						child:Destroy()
					end
				end
			end
		end
	end

	for uid, owned in desiredByUid do
		if not existingByUid[uid] then
			local info = PetData.Get(owned.PetId)
			if info then
				local tool = Instance.new("Tool")
				local mutPrefix = if owned.Mutation then `[{owned.Mutation}] ` else ""
				tool.Name = `{info.Emoji} {mutPrefix}{info.DisplayName}`
				tool.RequiresHandle = true
				tool.CanBeDropped = false
				tool:SetAttribute("IsPetTool", true)
				tool:SetAttribute("PetUid", owned.Uid)

				local handle = Instance.new("Part")
				handle.Name = "Handle"
				handle.Size = Vector3.new(0.8, 0.8, 0.8)
				handle.Transparency = 1
				handle.CanCollide = false
				handle.CanTouch = false
				handle.CanQuery = false
				handle.Massless = true
				handle.Parent = tool

				local visual = PetVisuals.BuildModel(owned.PetId, owned.Mutation, handle.CFrame * CFrame.new(0, 0.4, 0))
				for _, desc in visual:GetDescendants() do
					if desc:IsA("BasePart") then
						desc.Size *= 0.45
						desc.Anchored = false
						desc.Massless = true
					end
				end
				visual.Parent = tool
				if visual.PrimaryPart then
					local w = Instance.new("WeldConstraint")
					w.Part0 = handle
					w.Part1 = visual.PrimaryPart
					w.Parent = visual.PrimaryPart
				end

				tool.Activated:Connect(function()
					if info.Type == "Money" or info.Type == "Hybrid" then
						if InventoryService.PlacePet(player, owned.Uid, nil) then
							ClientSyncService.Notify(player, `🏠 Placed {info.Emoji} {info.DisplayName} on your plot!`, Color3.fromRGB(100, 255, 130))
						else
							ClientSyncService.Notify(player, "Your plot pet limit is full! Upgrade Pet Slots in Shop or use Equip Best.", Color3.fromRGB(255, 180, 60))
						end
					elseif info.Ability ~= nil then
						if InventoryService.Equip(player, owned.Uid) then
							ClientSyncService.Notify(player, `⚡ Equipped {info.Emoji} {info.DisplayName} ability!`, Color3.fromRGB(185, 110, 255))
						end
					end
				end)

				tool.Parent = backpack
			end
		end
	end
end

local function fireChanged(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local petsVal = ensureLeaderstats(player)
	petsVal.Value = #profile.Pets
	player:SetAttribute("PetSlots", profile.PetSlots)
	updateEquippedAttributes(player, profile.Pets)
	syncBackpackPetTools(player, profile.Pets)
	DataService.MarkDirty(player)
	ClientSyncService.SyncInventory(player, profile.Pets)
	PetsChangedEvent:Fire(player)
end

local function findFirstFreeSlot(player: Player, pets: { OwnedPet }, unlockedSlots: number): number?
	local used: { [number]: boolean } = {}
	for _, p in pets do
		if p.State == "Placed" and p.SlotIndex then
			used[p.SlotIndex] = true
		end
	end
	for i = 1, unlockedSlots do
		if not used[i] and not InventoryService.IsSlotBlocked(player, i) then
			return i
		end
	end
	return nil
end

local function setupPlayer(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end
	local petsVal = ensureLeaderstats(player)
	petsVal.Value = #profile.Pets
	player:SetAttribute("PetSlots", profile.PetSlots)
	updateEquippedAttributes(player, profile.Pets)
	syncBackpackPetTools(player, profile.Pets)
	player.CharacterAdded:Connect(function()
		task.delay(0.45, function()
			if player.Parent and DataService.GetProfile(player) then
				syncBackpackPetTools(player, profile.Pets)
			end
		end)
	end)
	ClientSyncService.SyncInventory(player, profile.Pets)
	PetsChangedEvent:Fire(player)
end

function InventoryService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(setupPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
end

function InventoryService.GetPets(player: Player): { OwnedPet }
	local profile = DataService.GetProfile(player)
	return if profile then profile.Pets else {}
end

function InventoryService.GetPetByUid(player: Player, uid: string): (OwnedPet?, number?)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil, nil
	end
	for i, pet in profile.Pets do
		if pet.Uid == uid then
			return pet, i
		end
	end
	return nil, nil
end

function InventoryService.GetPlaced(player: Player): { OwnedPet }
	local result: { OwnedPet } = {}
	for _, pet in InventoryService.GetPets(player) do
		if pet.State == "Placed" then
			table.insert(result, pet)
		end
	end
	return result
end

function InventoryService.GetEquipped(player: Player): OwnedPet?
	for _, pet in InventoryService.GetPets(player) do
		if pet.Equipped then
			return pet
		end
	end
	return nil
end

function InventoryService.GetPetSlots(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.PetSlots else Config.StartingPetSlots
end

function InventoryService.SetPetSlots(player: Player, count: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local maxSlots = InventoryService.GetMaxPetSlots(player)
	profile.PetSlots = math.clamp(math.floor(count), Config.StartingPetSlots, maxSlots)
	fireChanged(player)
end

function InventoryService.AutoPlaceStored(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local changed = false
	for _, pet in profile.Pets do
		if pet.State == "Stored" and not pet.Equipped and not pet.InTransit then
			local info = PetData.Get(pet.PetId)
			if info and (info.Type == "Money" or info.Type == "Hybrid") then
				local freeSlot = findFirstFreeSlot(player, profile.Pets, profile.PetSlots)
				if not freeSlot then
					break
				end
				pet.State = "Placed"
				pet.SlotIndex = freeSlot
				changed = true
			end
		end
	end
	if changed then
		fireChanged(player)
	end
end

function InventoryService.AddPet(player: Player, petId: string, mutation: string?): OwnedPet?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local info = PetData.Get(petId)
	if not info then
		warn(`InventoryService.AddPet: unknown pet "{petId}"`)
		return nil
	end

	local validMutation: string? = nil
	if mutation and MutationData.Get(mutation) ~= nil then
		validMutation = mutation
	end

	local owned: OwnedPet = {
		Uid = HttpService:GenerateGUID(false),
		PetId = petId,
		State = "Stored",
		SlotIndex = nil,
		Equipped = false,
		Mutation = validMutation,
		InTransit = false,
	}

	-- Rule: if pet has an Ability and nothing is currently equipped, auto-equip it.
	-- Otherwise, if it's a Money or Hybrid pet, auto-place it into the first free unlocked slot.
	if info.Ability ~= nil and InventoryService.GetEquipped(player) == nil then
		owned.Equipped = true
	elseif info.Type == "Money" or info.Type == "Hybrid" then
		local freeSlot = findFirstFreeSlot(player, profile.Pets, profile.PetSlots)
		if freeSlot then
			owned.State = "Placed"
			owned.SlotIndex = freeSlot
		end
	end

	table.insert(profile.Pets, owned)
	fireChanged(player)
	return owned
end

-- Adds a pet straight to the player's Bag ("Stored") when opening an unlocked cage on their plot.
function InventoryService.AddPetToBag(player: Player, petId: string, mutation: string?): OwnedPet?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local info = PetData.Get(petId)
	if not info then
		warn(`InventoryService.AddPetToBag: unknown pet "{petId}"`)
		return nil
	end

	local validMutation: string? = nil
	if mutation and MutationData.Get(mutation) ~= nil then
		validMutation = mutation
	end

	local owned: OwnedPet = {
		Uid = HttpService:GenerateGUID(false),
		PetId = petId,
		State = "Stored",
		SlotIndex = nil,
		Equipped = false,
		Mutation = validMutation,
		InTransit = false,
	}

	table.insert(profile.Pets, owned)
	fireChanged(player)
	return owned
end

-- Places the highest-income Money/Hybrid pets into all available unlocked slots and equips the best Ability pet.
function InventoryService.EquipBest(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end

	-- Clear existing placements & equip (skip InTransit pets)
	for _, pet in profile.Pets do
		if not pet.InTransit then
			pet.State = "Stored"
			pet.SlotIndex = nil
			pet.Equipped = false
		end
	end

	-- 1) Pick best pure Power pet (or best Ability pet) to Equip
	local bestPower: OwnedPet? = nil
	local bestPowerPrice = -1
	for _, pet in profile.Pets do
		if not pet.InTransit then
			local info = PetData.Get(pet.PetId)
			if info and info.Type == "Power" and info.Ability ~= nil and info.CagePrice > bestPowerPrice then
				bestPower = pet
				bestPowerPrice = info.CagePrice
			end
		end
	end
	if bestPower then
		bestPower.Equipped = true
	end

	-- 2) Sort all available Money & Hybrid pets by effective income/sec descending
	local earners: { { Pet: OwnedPet, Rate: number } } = {}
	for _, pet in profile.Pets do
		if not pet.InTransit and not pet.Equipped then
			local info = PetData.Get(pet.PetId)
			if info and (info.Type == "Money" or info.Type == "Hybrid") and info.IncomePerSec > 0 then
				local rate = info.IncomePerSec * MutationData.GetMultiplier(pet.Mutation)
				table.insert(earners, { Pet = pet, Rate = rate })
			end
		end
	end

	table.sort(earners, function(a, b)
		return a.Rate > b.Rate
	end)

	local placedCount = 0
	local earnerIdx = 1
	for slotIdx = 1, profile.PetSlots do
		if earnerIdx > #earners then
			break
		end
		if not InventoryService.IsSlotBlocked(player, slotIdx) then
			local chosen = earners[earnerIdx].Pet
			chosen.State = "Placed"
			chosen.SlotIndex = slotIdx
			placedCount += 1
			earnerIdx += 1
		end
	end

	-- 3) If no Power pet was equipped yet, equip the best remaining unplaced Hybrid ability pet
	if not bestPower then
		local bestHybrid: OwnedPet? = nil
		local bestHybridPrice = -1
		for _, pet in profile.Pets do
			if not pet.InTransit and pet.State == "Stored" then
				local info = PetData.Get(pet.PetId)
				if info and info.Ability ~= nil and info.CagePrice > bestHybridPrice then
					bestHybrid = pet
					bestHybridPrice = info.CagePrice
				end
			end
		end
		if bestHybrid then
			bestHybrid.Equipped = true
		end
	end

	fireChanged(player)
	return placedCount
end

function InventoryService.RemovePet(player: Player, uid: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	local pet, index = InventoryService.GetPetByUid(player, uid)
	if not pet or not index or pet.InTransit then
		return false
	end
	table.remove(profile.Pets, index)
	fireChanged(player)
	return true
end

function InventoryService.PlacePet(player: Player, uid: string, slotIndex: number?): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	local pet = InventoryService.GetPetByUid(player, uid)
	if not pet or pet.InTransit then
		return false
	end
	local info = PetData.Get(pet.PetId)
	if not info or (info.Type ~= "Money" and info.Type ~= "Hybrid") then
		return false
	end

	local targetSlot = slotIndex or findFirstFreeSlot(player, profile.Pets, profile.PetSlots)
	if typeof(targetSlot) ~= "number" then
		return false
	end
	targetSlot = math.floor(targetSlot)
	if targetSlot < 1 or targetSlot > profile.PetSlots or InventoryService.IsSlotBlocked(player, targetSlot) then
		return false
	end

	for _, other in profile.Pets do
		if other.Uid ~= uid and other.State == "Placed" and other.SlotIndex == targetSlot then
			return false
		end
	end

	pet.Equipped = false
	pet.State = "Placed"
	pet.SlotIndex = targetSlot
	fireChanged(player)
	return true
end

function InventoryService.UnplacePet(player: Player, uid: string): boolean
	local pet = InventoryService.GetPetByUid(player, uid)
	if not pet or pet.State ~= "Placed" or pet.InTransit then
		return false
	end
	pet.State = "Stored"
	pet.SlotIndex = nil
	fireChanged(player)
	return true
end

function InventoryService.Equip(player: Player, uid: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	local pet = InventoryService.GetPetByUid(player, uid)
	if not pet or pet.InTransit then
		return false
	end
	local info = PetData.Get(pet.PetId)
	if not info or info.Ability == nil then
		return false
	end

	for _, other in profile.Pets do
		other.Equipped = false
	end

	pet.State = "Stored"
	pet.SlotIndex = nil
	pet.Equipped = true
	fireChanged(player)
	return true
end

function InventoryService.Unequip(player: Player): boolean
	local equipped = InventoryService.GetEquipped(player)
	if not equipped then
		return false
	end
	equipped.Equipped = false
	fireChanged(player)
	return true
end

function InventoryService.SetInTransit(player: Player, uid: string, inTransit: boolean): boolean
	local pet = InventoryService.GetPetByUid(player, uid)
	if not pet then
		return false
	end
	pet.InTransit = inTransit
	fireChanged(player)
	return true
end

return InventoryService
