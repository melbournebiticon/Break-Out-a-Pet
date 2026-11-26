--!strict
-- DataService.luau (SERVER)
-- Loads, migrates, sanitizes, and saves player profiles using DataStoreService.UpdateAsync.
-- Includes Studio fallback when API Services are disabled.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local MutationData = require(Shared:WaitForChild("MutationData"))

export type SavedPet = {
	Uid: string,
	PetId: string,
	State: "Stored" | "Placed",
	SlotIndex: number?,
	Equipped: boolean,
	Mutation: string?,
	Scale: number?,
	InTransit: boolean?,
}

export type Profile = {
	Version: number,
	Money: number,
	SpeedLevel: number,
	TrainedSpeed: number,
	PetSlots: number,
	Pets: { SavedPet },
	LastSeen: number,
	TutorialDone: boolean,
	DailyStreak: number,
	LastDailyClaimDay: number,
	ProcessedReceipts: { string },
	TotalRescued: number,
	LuckyNextCage: boolean,
	OwnedPamalos: { [string]: boolean },
	EquippedPamalo: string,
}

local CURRENT_VERSION = 3

local DataService = {}

local ProfileLoadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = ProfileLoadedEvent.Event

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local loadFailed: { [Player]: boolean } = {}
local activeSaves = 0
local studioOfflineMode = false
local store: DataStore? = nil

local function createDefaultProfile(): Profile
	return {
		Version = CURRENT_VERSION,
		Money = Config.StartingMoney,
		SpeedLevel = 0,
		TrainedSpeed = 0,
		PetSlots = Config.StartingPetSlots,
		Pets = {},
		LastSeen = os.time(),
		TutorialDone = false,
		DailyStreak = 0,
		LastDailyClaimDay = 0,
		ProcessedReceipts = {},
		TotalRescued = 0,
		LuckyNextCage = false,
		OwnedPamalos = { tsinelas_spartan = true },
		EquippedPamalo = "tsinelas_spartan",
	}
end

-- Migrations: each version upgrade adds missing fields with safe defaults.
local function migrateAndSanitize(raw: any): Profile
	if typeof(raw) ~= "table" then
		return createDefaultProfile()
	end

	local money = if typeof(raw.Money) == "number" and raw.Money == raw.Money then math.max(0, math.floor(raw.Money)) else Config.StartingMoney
	local speedLevel = if typeof(raw.SpeedLevel) == "number" then math.clamp(math.floor(raw.SpeedLevel), 0, ShopData.Speed.MaxLevel) else 0
	local trainedSpeed = if typeof(raw.TrainedSpeed) == "number" and raw.TrainedSpeed == raw.TrainedSpeed
		then math.clamp(raw.TrainedSpeed, 0, 999999999999)
		else (speedLevel * ShopData.Speed.SpeedPerLevel)
	local maxAllowedSlots = Config.MaxPetSlots + Config.ExtraPassPetSlots
	local petSlots = if typeof(raw.PetSlots) == "number" then math.clamp(math.floor(raw.PetSlots), Config.StartingPetSlots, maxAllowedSlots) else Config.StartingPetSlots
	local lastSeen = if typeof(raw.LastSeen) == "number" then raw.LastSeen else os.time()
	local tutorialDone = if typeof(raw.TutorialDone) == "boolean" then raw.TutorialDone else false
	local dailyStreak = if typeof(raw.DailyStreak) == "number" then math.max(0, math.floor(raw.DailyStreak)) else 0
	local lastDailyClaimDay = if typeof(raw.LastDailyClaimDay) == "number" then math.max(0, math.floor(raw.LastDailyClaimDay)) else 0
	local totalRescued = if typeof(raw.TotalRescued) == "number" then math.max(0, math.floor(raw.TotalRescued)) else 0
	local luckyNextCage = if typeof(raw.LuckyNextCage) == "boolean" then raw.LuckyNextCage else false

	local ownedPamalos: { [string]: boolean } = { tsinelas_spartan = true }
	if typeof(raw.OwnedPamalos) == "table" then
		for k, v in raw.OwnedPamalos do
			if typeof(k) == "string" and v == true then
				ownedPamalos[k] = true
			end
		end
	end
	local equippedPamalo = if typeof(raw.EquippedPamalo) == "string" and ownedPamalos[raw.EquippedPamalo]
		then raw.EquippedPamalo
		else "tsinelas_spartan"

	local receipts: { string } = {}
	if typeof(raw.ProcessedReceipts) == "table" then
		for _, id in raw.ProcessedReceipts do
			if typeof(id) == "string" then
				table.insert(receipts, id)
			end
		end
	end

	local seenUids: { [string]: boolean } = {}
	local occupiedSlots: { [number]: boolean } = {}
	local hasEquipped = false
	local cleanPets: { SavedPet } = {}

	if typeof(raw.Pets) == "table" then
		for _, entry in raw.Pets do
			if typeof(entry) == "table" and typeof(entry.PetId) == "string" then
				local petInfo = PetData.Get(entry.PetId)
				if petInfo then
					local uid = if typeof(entry.Uid) == "string" and entry.Uid ~= "" and not seenUids[entry.Uid]
						then entry.Uid
						else HttpService:GenerateGUID(false)
					seenUids[uid] = true

					local mutation: string? = nil
					if typeof(entry.Mutation) == "string" and MutationData.Get(entry.Mutation) ~= nil then
						mutation = entry.Mutation
					end

					local equipped = false
					if entry.Equipped == true and not hasEquipped and petInfo.Ability ~= nil then
						equipped = true
						hasEquipped = true
					end

					local state: "Stored" | "Placed" = "Stored"
					local slotIndex: number? = nil
					if not equipped and entry.State == "Placed" and petInfo.Type ~= "Power" then
						local idx = if typeof(entry.SlotIndex) == "number" then math.floor(entry.SlotIndex) else 0
						if idx >= 1 and idx <= petSlots and not occupiedSlots[idx] then
							state = "Placed"
							slotIndex = idx
							occupiedSlots[idx] = true
						end
					end

					table.insert(cleanPets, {
						Uid = uid,
						PetId = entry.PetId,
						State = state,
						SlotIndex = slotIndex,
						Equipped = equipped,
						Mutation = mutation,
						InTransit = false,
					})
				end
			end
		end
	end

	return {
		Version = CURRENT_VERSION,
		Money = money,
		SpeedLevel = speedLevel,
		TrainedSpeed = trainedSpeed,
		PetSlots = petSlots,
		Pets = cleanPets,
		LastSeen = lastSeen,
		TutorialDone = tutorialDone,
		DailyStreak = dailyStreak,
		LastDailyClaimDay = lastDailyClaimDay,
		ProcessedReceipts = receipts,
		TotalRescued = totalRescued,
		LuckyNextCage = luckyNextCage,
		OwnedPamalos = ownedPamalos,
		EquippedPamalo = equippedPamalo,
	}
end

local function serializeProfile(profile: Profile): any
	local savedPets = {}
	for _, pet in profile.Pets do
		table.insert(savedPets, {
			Uid = pet.Uid,
			PetId = pet.PetId,
			State = pet.State,
			SlotIndex = pet.SlotIndex,
			Equipped = pet.Equipped,
			Mutation = pet.Mutation,
		})
	end

	return {
		Version = CURRENT_VERSION,
		Money = profile.Money,
		SpeedLevel = profile.SpeedLevel,
		TrainedSpeed = profile.TrainedSpeed,
		PetSlots = profile.PetSlots,
		Pets = savedPets,
		LastSeen = os.time(),
		TutorialDone = profile.TutorialDone,
		DailyStreak = profile.DailyStreak,
		LastDailyClaimDay = profile.LastDailyClaimDay,
		ProcessedReceipts = profile.ProcessedReceipts,
		TotalRescued = profile.TotalRescued,
		LuckyNextCage = profile.LuckyNextCage,
		OwnedPamalos = profile.OwnedPamalos,
		EquippedPamalo = profile.EquippedPamalo,
	}
end

function DataService.SavePlayer(player: Player, force: boolean?): boolean
	local profile = profiles[player]
	if not profile or loadFailed[player] then
		return false
	end
	if not force and not dirty[player] then
		return true
	end
	if studioOfflineMode or not store then
		dirty[player] = false
		return true
	end

	local key = `Player_{player.UserId}`
	local payload = serializeProfile(profile)
	activeSaves += 1
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function()
			return payload
		end)
	end)
	activeSaves -= 1

	if ok then
		dirty[player] = false
		profile.LastSeen = payload.LastSeen
		print(`[DataService] Saved {player.Name}`)
		return true
	else
		warn(`[DataService] Failed to save {player.Name}: {err}`)
		return false
	end
end

local function loadPlayer(player: Player)
	if profiles[player] then
		return
	end

	local key = `Player_{player.UserId}`
	local rawData: any = nil
	local loadedOk = false

	if not studioOfflineMode and store then
		for attempt = 1, Config.LoadRetries do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key)
			end)
			if ok then
				rawData = result
				loadedOk = true
				break
			end

			if RunService:IsStudio() and attempt == 1 then
				studioOfflineMode = true
				warn("[DataService] Studio API Services disabled or unavailable; running with in-memory default profile (not saved).")
				loadedOk = true
				break
			end

			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {result}`)
			if attempt < Config.LoadRetries then
				task.wait(2 ^ attempt)
			end
		end
	else
		loadedOk = true
	end

	if not player.Parent then
		return
	end

	if not loadedOk then
		loadFailed[player] = true
		player:Kick("Could not load your saved data after multiple retries. Please rejoin to protect your progress.")
		return
	end

	local profile = migrateAndSanitize(rawData)
	profiles[player] = profile
	dirty[player] = false

	player:SetAttribute("TutorialDone", profile.TutorialDone)
	player:SetAttribute("DailyStreak", profile.DailyStreak)
	player:SetAttribute("LastDailyClaimDay", profile.LastDailyClaimDay)

	print(`[DataService] Loaded {player.Name} (Money=${profile.Money}, SpeedLevel={profile.SpeedLevel}, TrainedSpeed={profile.TrainedSpeed}, Pets={#profile.Pets}, StudioOffline={studioOfflineMode})`)
	ProfileLoadedEvent:Fire(player, profile)
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.WaitForProfile(player: Player): Profile?
	while player.Parent and not profiles[player] and not loadFailed[player] do
		task.wait(0.05)
	end
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService.SetTutorialDone(player: Player)
	local profile = profiles[player]
	if profile and not profile.TutorialDone then
		profile.TutorialDone = true
		player:SetAttribute("TutorialDone", true)
		dirty[player] = true
	end
end

function DataService.Init()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok and ds then
		store = ds
	else
		studioOfflineMode = true
		warn("[DataService] DataStore unavailable; using temporary in-memory profiles.")
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.SavePlayer(player, true)
		profiles[player] = nil
		dirty[player] = nil
		loadFailed[player] = nil
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				if dirty[player] then
					task.spawn(DataService.SavePlayer, player, false)
					task.wait(0.25)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, _ in profiles do
			if dirty[player] then
				pending += 1
				task.spawn(function()
					DataService.SavePlayer(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while (pending > 0 or activeSaves > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
