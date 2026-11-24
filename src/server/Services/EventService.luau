--!strict
-- EventService.luau (SERVER)
-- Runs periodic Lucky Cage / Rainbow Cage events and updates the "LeaderboardBoard" SurfaceGui.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EventData = require(Shared:WaitForChild("EventData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CageService = require(script.Parent:WaitForChild("CageService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local EventService = {}

local rng = Random.new()
local announceEvent: RemoteEvent
local orderedStore: OrderedDataStore? = nil
local pendingRescueDelta: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function getPlayerName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	for _, p in Players:GetPlayers() do
		if p.UserId == userId then
			nameCache[userId] = p.DisplayName
			return p.DisplayName
		end
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and typeof(name) == "string" then name else `Player_{userId}`
	nameCache[userId] = resolved
	return resolved
end

local function spawnSpecialCage()
	local prison = workspace:FindFirstChild("Prison")
	if not prison then
		return
	end

	local zones: { Folder } = {}
	for _, child in prison:GetChildren() do
		if child:IsA("Folder") and child:FindFirstChild("Floor") then
			table.insert(zones, child)
		end
	end
	if #zones == 0 then
		return
	end

	local chosenZone = zones[rng:NextInteger(1, #zones)]
	local floor = chosenZone:FindFirstChild("Floor") :: BasePart
	local isRainbow = rng:NextNumber() <= EventData.RainbowCageChance
	local lootTable = if isRainbow then "Rainbow" else "Lucky"
	local displayTitle = if isRainbow then "🌈 RAINBOW CAGE" else "🍀 LUCKY CAGE"
	local color = if isRainbow then Color3.fromRGB(0, 240, 220) else Color3.fromRGB(255, 210, 45)

	local cage = Instance.new("Model")
	cage.Name = `{lootTable}EventCage`
	cage:SetAttribute("Zone", chosenZone.Name)
	cage:SetAttribute("LootTable", lootTable)
	cage:SetAttribute("IsEventCage", true)

	local pos = floor.Position + Vector3.new(0, 3.2, -12)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(5, 5, 5)
	body.Position = pos
	body.Anchored = true
	body.Color = color
	body.Material = Enum.Material.Neon
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = cage
	cage.PrimaryPart = body

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.Parent = cage

	CollectionService:AddTag(cage, "Cage")
	cage.Parent = chosenZone

	local extraEnemy = EnemyService.SpawnTemporaryEnemy(
		"Warden",
		chosenZone.Name,
		CFrame.new(pos + Vector3.new(6, 0, 6)),
		EventData.ExtraGuardSpeedMultiplier
	)

	local endTime = workspace:GetServerTimeNow() + EventData.EventDurationSeconds
	local bannerText = `{displayTitle} spawned in {chosenZone.Name}!`
	announceEvent:FireAllClients(bannerText, endTime, color)

	task.delay(EventData.EventDurationSeconds, function()
		if cage.Parent and not cage:GetAttribute("Taken") then
			cage:Destroy()
		end
		if extraEnemy and extraEnemy.Parent then
			extraEnemy:Destroy()
		end
	end)
end

local function flushAndRefreshLeaderboards()
	if orderedStore then
		for userId, delta in pendingRescueDelta do
			if delta > 0 then
				pendingRescueDelta[userId] = nil
				pcall(function()
					(orderedStore :: OrderedDataStore):IncrementAsync(tostring(userId), delta)
				end)
			end
		end
	end

	-- Collect top 10 entries (from OrderedDataStore if available, otherwise current session players)
	local rows: { { Name: string, Count: number } } = {}
	local fetchedFromStore = false

	if orderedStore then
		local ok, pages = pcall(function()
			return (orderedStore :: OrderedDataStore):GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			for _, item in page do
				local uid = tonumber(item.key)
				local val = tonumber(item.value) or 0
				if uid and val > 0 then
					table.insert(rows, { Name = getPlayerName(uid), Count = val })
				end
			end
			fetchedFromStore = #rows > 0
		end
	end

	if not fetchedFromStore then
		for _, player in Players:GetPlayers() do
			local profile = DataService.GetProfile(player)
			if profile then
				table.insert(rows, { Name = player.DisplayName, Count = profile.TotalRescued })
			end
		end
		table.sort(rows, function(a, b)
			return a.Count > b.Count
		end)
	end

	for _, board in CollectionService:GetTagged("LeaderboardBoard") do
		if board:IsA("BasePart") then
			local sgui = board:FindFirstChild("LeaderboardGui") :: SurfaceGui?
			if not sgui then
				sgui = Instance.new("SurfaceGui")
				sgui.Name = "LeaderboardGui"
				sgui.Face = Enum.NormalId.Front
				sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sgui.PixelsPerStud = 35
				sgui.Parent = board
			end
			sgui:ClearAllChildren()

			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
			bg.BorderSizePixel = 0
			bg.Parent = sgui

			local header = Instance.new("TextLabel")
			header.Size = UDim2.new(1, 0, 0.14, 0)
			header.BackgroundColor3 = Color3.fromRGB(45, 95, 190)
			header.BorderSizePixel = 0
			header.Font = Enum.Font.FredokaOne
			header.TextScaled = true
			header.TextColor3 = Color3.new(1, 1, 1)
			header.Text = "🏆 MOST PETS RESCUED 🏆"
			header.Parent = bg

			for i = 1, math.min(10, math.max(1, #rows)) do
				local entry = rows[i]
				local rowLabel = Instance.new("TextLabel")
				rowLabel.Position = UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.082)
				rowLabel.Size = UDim2.fromScale(0.9, 0.075)
				rowLabel.BackgroundTransparency = 1
				rowLabel.Font = Enum.Font.FredokaOne
				rowLabel.TextScaled = true
				rowLabel.TextXAlignment = Enum.TextXAlignment.Left
				rowLabel.TextColor3 = if i == 1
					then Color3.fromRGB(255, 215, 50)
					elseif i <= 3 then Color3.fromRGB(160, 220, 255)
					else Color3.fromRGB(230, 230, 230)
				rowLabel.Text = if entry then `#{i}  {entry.Name}  —  {entry.Count} Pets` else "Rescue a pet to appear here!"
				rowLabel.Parent = bg
			end
		end
	end
end

function EventService.Init()
	announceEvent = Remotes.GetEvent("EventAnnounce")

	pcall(function()
		orderedStore = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)

	CageService.CageDelivered:Connect(function(player: Player)
		pendingRescueDelta[player.UserId] = (pendingRescueDelta[player.UserId] or 0) + 1
		task.spawn(flushAndRefreshLeaderboards)
	end)

	-- Periodic event loop
	task.spawn(function()
		while true do
			task.wait(EventData.EventIntervalSeconds)
			spawnSpecialCage()
		end
	end)

	-- Leaderboard refresh loop
	task.spawn(function()
		task.wait(2)
		while true do
			flushAndRefreshLeaderboards()
			task.wait(60)
		end
	end)
end

return EventService
