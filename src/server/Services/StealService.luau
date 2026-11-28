--!strict
-- StealService.luau (SERVER)
-- Allows players to steal placed pets from other unshielded bases and carry them back to their own DropZone.
-- The pet stays in the victim's inventory (marked InTransit) until the thief reaches their own DropZone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local CageService = require(script.Parent:WaitForChild("CageService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local TrapService = require(script.Parent:WaitForChild("TrapService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

type StolenCarry = {
	Owner: Player,
	OwnerPlot: Model,
	Uid: string,
	PetId: string,
	Mutation: string?,
	CarryModel: Model,
}

local StealService = {}

local stolenCarrying: { [Player]: StolenCarry } = {}
local stealTimestamps: { [Player]: { number } } = {}

function StealService.IsCarryingStolen(player: Player): boolean
	return stolenCarrying[player] ~= nil
end

local function checkStealRateLimit(thief: Player): boolean
	local now = os.clock()
	local list = stealTimestamps[thief]
	if not list then
		list = {}
		stealTimestamps[thief] = list
	end
	for i = #list, 1, -1 do
		if now - list[i] > 60 then
			table.remove(list, i)
		end
	end
	if #list >= Config.MaxStealsPerPlayerPerMinute then
		return false
	end
	table.insert(list, now)
	return true
end

function StealService.DropStolenPet(thief: Player, reason: string?)
	local carry = stolenCarrying[thief]
	if not carry then
		return
	end
	stolenCarrying[thief] = nil
	thief:SetAttribute("IsCarryingStolen", false)
	if not CageService.IsCarrying(thief) then
		thief:SetAttribute("CarriedPetId", "")
		thief:SetAttribute("CarriedRarity", "")
	end
	carry.CarryModel:Destroy()
	StatsService.Refresh(thief)

	if carry.Owner.Parent and DataService.IsLoaded(carry.Owner) then
		InventoryService.SetInTransit(carry.Owner, carry.Uid, false)
		ClientSyncService.Notify(carry.Owner, "🛡️ Your stolen pet was recovered!", Color3.fromRGB(100, 255, 130))
	end

	if reason == "caught" and thief.Parent then
		ClientSyncService.Notify(thief, "Caught! The stolen pet returned to its owner.", Color3.fromRGB(255, 80, 80))
	end
end

local function completeSteal(thief: Player)
	local carry = stolenCarrying[thief]
	if not carry then
		return
	end
	stolenCarrying[thief] = nil
	thief:SetAttribute("IsCarryingStolen", false)
	if not CageService.IsCarrying(thief) then
		thief:SetAttribute("CarriedPetId", "")
		thief:SetAttribute("CarriedRarity", "")
	end
	carry.CarryModel:Destroy()
	StatsService.Refresh(thief)

	local owner = carry.Owner
	if not owner.Parent or not DataService.IsLoaded(owner) then
		return
	end

	local owned = InventoryService.GetPetByUid(owner, carry.Uid)
	if not owned then
		return
	end

	-- Clear InTransit so RemovePet succeeds
	owned.InTransit = false
	if not InventoryService.RemovePet(owner, carry.Uid) then
		return
	end

	InventoryService.AddPet(thief, carry.PetId, carry.Mutation)
	PlotService.SetShield(carry.OwnerPlot, Config.AfterRobberyShieldSeconds)

	local pet = PetData.Get(carry.PetId)
	local petName = if pet then `{pet.Emoji} {pet.DisplayName}` else carry.PetId
	ClientSyncService.Notify(thief, `🕵️ You stole {petName} from {owner.DisplayName}!`, Color3.fromRGB(100, 255, 130))
	ClientSyncService.Notify(owner, `🚨 {thief.DisplayName} stole your {petName}! Base shielded for {Config.AfterRobberyShieldSeconds}s.`, Color3.fromRGB(255, 90, 90))
end

local function onStealTriggered(owner: Player, plot: Model, uid: string, thief: Player)
	if thief == owner then
		return
	end
	if not DataService.IsLoaded(thief) or not DataService.IsLoaded(owner) then
		return
	end
	if CageService.IsCarrying(thief) or stolenCarrying[thief] then
		ClientSyncService.Notify(thief, "Your hands are already full!", Color3.fromRGB(255, 180, 60))
		return
	end
	if PlotService.IsShielded(plot) then
		ClientSyncService.Notify(thief, "🛡️ This base is currently shielded!", Color3.fromRGB(120, 200, 255))
		return
	end

	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local owned = InventoryService.GetPetByUid(owner, uid)
	if not owned or owned.State ~= "Placed" or owned.InTransit then
		return
	end

	if not checkStealRateLimit(thief) then
		ClientSyncService.Notify(thief, "Steal cooldown! Wait a moment.", Color3.fromRGB(255, 180, 60))
		return
	end

	local petInfo = PetData.Get(owned.PetId)
	if not petInfo then
		return
	end

	InventoryService.SetInTransit(owner, uid, true)

	local carryModel = PetVisuals.BuildModel(owned.PetId, owned.Mutation, root.CFrame)
	carryModel.Name = "StolenPetCarry"
	carryModel:SetAttribute("CarriedByUserId", thief.UserId)
	carryModel:SetAttribute("Rarity", petInfo.Rarity)
	carryModel.Parent = character

	CageService.AttachModelToPlayer(carryModel, root)
	CageService.AddRevealLabel(carryModel, petInfo, owned.Mutation)

	stolenCarrying[thief] = {
		Owner = owner,
		OwnerPlot = plot,
		Uid = uid,
		PetId = owned.PetId,
		Mutation = owned.Mutation,
		CarryModel = carryModel,
	}
	thief:SetAttribute("IsCarryingStolen", true)
	thief:SetAttribute("CarriedPetId", owned.PetId)
	thief:SetAttribute("CarriedRarity", petInfo.Rarity)
	thief:SetAttribute("LastCarryPickupAt", workspace:GetServerTimeNow())

	StatsService.Refresh(thief)
	ClientSyncService.Notify(owner, `🚨 {thief.DisplayName} is stealing your {petInfo.Emoji} {petInfo.DisplayName}! Touch them to stop them!`, Color3.fromRGB(255, 80, 80))
end

local function attachStealPrompt(owner: Player, plot: Model, owned: InventoryService.OwnedPet, model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal Pet"
	prompt.ObjectText = `{owner.DisplayName}'s Pet`
	prompt.HoldDuration = Config.StealHoldSeconds
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(thief: Player)
		onStealTriggered(owner, plot, owned.Uid, thief)
	end)
	prompt.Parent = primary
end

local function setupDropZoneDelivery(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local thief = Players:GetPlayerFromCharacter(character)
		if not thief or not stolenCarrying[thief] then
			return
		end
		local plot = instance:FindFirstAncestorOfClass("Model")
		if not plot or plot:GetAttribute("OwnerUserId") ~= thief.UserId then
			return
		end
		completeSteal(thief)
	end)
end

local function watchPlayer(player: Player)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				StealService.DropStolenPet(player, "caught")
			end)
		end
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and root:IsA("BasePart") then
			root.Touched:Connect(function(hit: BasePart)
				local carry = stolenCarrying[player]
				if not carry then
					return
				end
				local otherChar = hit:FindFirstAncestorOfClass("Model")
				local otherPlayer = if otherChar then Players:GetPlayerFromCharacter(otherChar) else nil
				if otherPlayer and otherPlayer == carry.Owner then
					StealService.DropStolenPet(player, "caught")
				end
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		StealService.DropStolenPet(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function StealService.Init()
	-- Player bases/plots are strictly 100% SAFE (NO base stealing from player plots!).
	CageService.SetExternalCarryCheck(StealService.IsCarryingStolen)

	EnemyService.SetExtraCarryingCheck(function(player: Player): (boolean, Model?)
		local carry = stolenCarrying[player]
		if carry then
			return true, carry.CarryModel
		end
		return false, nil
	end)

	EnemyService.SetExtraCatchHandler(function(player: Player)
		StealService.DropStolenPet(player, "caught")
	end)

	TrapService.SetExtraLaserCatch(function(player: Player)
		StealService.DropStolenPet(player, "caught")
	end)

	StatsService.AddSpeedModifier("StolenCarry", function(player: Player): number
		local carry = stolenCarrying[player]
		if not carry then
			return 1
		end
		local pet = PetData.Get(carry.PetId)
		return if pet then Rarities.Get(pet.Rarity).CarrySpeedMultiplier else 1
	end)

	for _, instance in CollectionService:GetTagged("DropZone") do
		task.spawn(setupDropZoneDelivery, instance)
	end
	CollectionService:GetInstanceAddedSignal("DropZone"):Connect(setupDropZoneDelivery)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		StealService.DropStolenPet(player)
		stealTimestamps[player] = nil
		for thief, carry in stolenCarrying do
			if carry.Owner == player then
				StealService.DropStolenPet(thief)
			end
		end
	end)
end

return StealService
