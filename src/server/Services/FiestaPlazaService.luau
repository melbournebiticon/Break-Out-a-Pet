--!strict
-- FiestaPlazaService.luau (SERVER)
-- Runs rotating Tatak Pinoy Fiesta Mini-Events in the Safe Zone Fiesta Event Plaza:
-- 1) 🎋 FIESTA PABITIN (Jump & Grab Hanging Prizes -> ⚡ 2x Treadmill Speed Training Boost + Instant Speed!)
-- 2) 🎲 PERYA COLOR GAME (Stand on Color Tiles -> 💰 2x Pet Cash Income Boost + Cash Jackpot!)
-- 3) 🏺 HAMPAS-PALAYOK (Smash the Golden Palayok Pots -> 🍀 2x Titanic/Mutation Luck & 2x Faster Cage Unlock Boost!)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local FiestaPlazaService = {}

local rng = Random.new()
local BOOST_DURATION_SECONDS = 180 -- 3 minutes per Fiesta participation boost

local function getPlazaCenter(): Vector3
	for _, inst in CollectionService:GetTagged("FiestaArenaCenter") do
		if inst:IsA("BasePart") then
			return inst.Position
		end
	end
	return Vector3.new(0, 0.35, 150)
end

local function updateStageSigns(title: string, subtitle: string, titleColor: Color3)
	workspace:SetAttribute("FiestaEventTitle", title)
	workspace:SetAttribute("FiestaEventSub", subtitle)
	for _, sign in CollectionService:GetTagged("FiestaStageSign") do
		if sign:IsA("BasePart") then
			for _, sg in sign:GetChildren() do
				if sg:IsA("SurfaceGui") then
					local bg = sg:FindFirstChildOfClass("Frame")
					if bg then
						local labels: { TextLabel } = {}
						for _, child in bg:GetChildren() do
							if child:IsA("TextLabel") then
								table.insert(labels, child)
							end
						end
						if labels[1] then
							labels[1].Text = title
							labels[1].TextColor3 = titleColor
						end
						if labels[2] then
							labels[2].Text = subtitle
						end
					end
				end
			end
		end
	end
end

local function extendPlayerBoost(player: Player, attrName: string, addSeconds: number)
	local now = workspace:GetServerTimeNow()
	local currentAttr = player:GetAttribute(attrName)
	local currentUntil = if typeof(currentAttr) == "number" and currentAttr > now then currentAttr else now
	-- Cap stacked boost at 15 minutes max
	local newUntil = math.min(now + 900, currentUntil + addSeconds)
	player:SetAttribute(attrName, newUntil)
	if attrName == "FiestaMoneyBoostUntil" then
		EconomyService.RefreshPlayer(player)
	end
end

-- EVENT 1: 🎋 FIESTA PABITIN (Jump & Grab Hanging Prizes!) ------------------
local function runPabitinEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	announceEvent:FireAllClients(
		"🎋 FIESTA PABITIN started in the Fiesta Plaza! Jump & grab prizes for ⚡ 2x Treadmill Speed Boost!",
		workspace:GetServerTimeNow() + 35,
		Color3.fromRGB(80, 235, 255)
	)

	-- Bamboo Lattice Frame
	local frameBar = Instance.new("Part")
	frameBar.Name = "PabitinLattice"
	frameBar.Size = Vector3.new(16, 0.45, 16)
	frameBar.Position = center + Vector3.new(0, 11, 0)
	frameBar.Anchored = true
	frameBar.CanCollide = false
	frameBar.Color = Color3.fromRGB(185, 140, 72)
	frameBar.Material = Enum.Material.Wood
	frameBar.Parent = folder

	local prizeColors = {
		Color3.fromRGB(255, 75, 75),
		Color3.fromRGB(255, 215, 50),
		Color3.fromRGB(65, 225, 255),
		Color3.fromRGB(95, 245, 120),
		Color3.fromRGB(245, 95, 235),
	}

	type PrizeBox = {
		Part: Part,
		Offset: Vector3,
		Claimed: boolean,
	}
	local prizes: { PrizeBox } = {}

	local idx = 0
	for gx = -1, 1 do
		for gz = -1, 1 do
			idx += 1
			local off = Vector3.new(gx * 5.2, -1.6, gz * 5.2)
			local box = Instance.new("Part")
			box.Name = `PabitinPrize_{idx}`
			box.Size = Vector3.new(2.4, 2.4, 2.4)
			box.Position = frameBar.Position + off
			box.Anchored = true
			box.CanCollide = false
			box.Color = prizeColors[((idx - 1) % #prizeColors) + 1]
			box.Material = Enum.Material.Neon
			box.Parent = folder

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(4, 1.2)
			bb.StudsOffset = Vector3.new(0, 2.0, 0)
			bb.MaxDistance = 60
			bb.Adornee = box
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(255, 245, 150)
			lbl.TextStrokeTransparency = 0
			lbl.Text = "🎁 JUMP TO GRAB! (2x Speed)"
			lbl.Parent = bb
			bb.Parent = box

			table.insert(prizes, {
				Part = box,
				Offset = off,
				Claimed = false,
			})
		end
	end

	local duration = 35
	local startClock = os.clock()
	while os.clock() - startClock < duration do
		local elapsed = os.clock() - startClock
		local rem = math.max(0, math.ceil(duration - elapsed))
		-- Bob the Pabitin frame down to jump height (Y = 6.2) and up to Y = 11.8!
		local bobY = 8.8 - math.sin(elapsed * 2.4) * 2.8
		local framePos = center + Vector3.new(0, bobY, 0)
		frameBar.Position = framePos

		local remainingBoxes = 0
		for _, pz in prizes do
			if not pz.Claimed and pz.Part.Parent then
				remainingBoxes += 1
				pz.Part.CFrame = CFrame.new(framePos + pz.Offset) * CFrame.Angles(0, elapsed * 1.8, 0)

				-- Check if any player jumped close enough to snatch this prize!
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						if (root.Position - pz.Part.Position).Magnitude <= 4.6 then
							pz.Claimed = true
							pz.Part:Destroy()
							extendPlayerBoost(player, "FiestaSpeedBoostUntil", BOOST_DURATION_SECONDS)
							local tier = StatsService.GetSpeedLevel(player)
							local bonusSpeed = math.max(50, ShopData.GetTrainerGainPerSec(tier) * 20)
							StatsService.AddTrainedSpeed(player, bonusSpeed)
							ClientSyncService.Notify(
								player,
								`🎋 Snatched a Pabitin Prize! +${NumberFormat.Short(bonusSpeed)} Speed & ⚡ 2x Treadmill Boost (3m)!`,
								Color3.fromRGB(80, 235, 255)
							)
							break
						end
					end
				end
			end
		end

		updateStageSigns(
			`🎋 FIESTA PABITIN ({rem}s)`,
			`Jump & Grab Hanging Prizes for ⚡ 2x Treadmill Speed Boost! ({remainingBoxes} left)`,
			Color3.fromRGB(80, 235, 255)
		)

		if remainingBoxes == 0 then
			break
		end
		task.wait(0.1)
	end

	folder:Destroy()
end

-- EVENT 2: 🎲 PERYA COLOR GAME (Stand on the Winning Color Tile!) -----------
local function runColorGameEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	announceEvent:FireAllClients(
		"🎲 PERYA COLOR GAME started in the Fiesta Plaza! Stand on a color tile for 💰 2x Pet Cash Boost!",
		workspace:GetServerTimeNow() + 33,
		Color3.fromRGB(255, 215, 55)
	)

	local colorOptions = {
		{ Name = "RED", Color = Color3.fromRGB(235, 55, 55) },
		{ Name = "BLUE", Color = Color3.fromRGB(55, 145, 245) },
		{ Name = "YELLOW", Color = Color3.fromRGB(250, 210, 45) },
		{ Name = "GREEN", Color = Color3.fromRGB(65, 215, 95) },
		{ Name = "PINK", Color = Color3.fromRGB(245, 95, 210) },
		{ Name = "WHITE", Color = Color3.fromRGB(240, 245, 255) },
	}

	local dice = Instance.new("Part")
	dice.Name = "PeryaColorCube"
	dice.Size = Vector3.new(4.8, 4.8, 4.8)
	dice.Position = center + Vector3.new(0, 7.5, 0)
	dice.Anchored = true
	dice.CanCollide = false
	dice.Material = Enum.Material.Neon
	dice.Color = colorOptions[1].Color
	dice.Parent = folder

	for round = 1, 3 do
		-- 8 seconds of spinning & choosing a tile
		local spinStart = os.clock()
		while os.clock() - spinStart < 8.0 do
			local elapsed = os.clock() - spinStart
			local rem = math.max(1, math.ceil(8.0 - elapsed))
			local preview = colorOptions[(math.floor(elapsed * 6) % #colorOptions) + 1]
			dice.Color = preview.Color
			dice.CFrame = CFrame.new(center + Vector3.new(0, 7.5 + math.sin(elapsed * 4) * 0.6, 0))
				* CFrame.Angles(elapsed * 3.5, elapsed * 4.2, elapsed * 2.1)
			updateStageSigns(
				`🎲 PERYA COLOR GAME — Round {round}/3 ({rem}s)`,
				"Stand on any Color Tile! Matching the winning color gives 💰 2x Pet Cash Boost!",
				 preview.Color
			)
			task.wait(0.1)
		end

		-- Pick winning color!
		local winner = colorOptions[rng:NextInteger(1, #colorOptions)]
		dice.Color = winner.Color
		dice.CFrame = CFrame.new(center + Vector3.new(0, 7.5, 0))
		updateStageSigns(
			`🎲 WINNING COLOR: {winner.Name}! (Round {round}/3)`,
			"Winners get 💰 2x Pet Cash Boost (3m) + Instant Cash Jackpot!",
			winner.Color
		)

		-- Check players standing on the Color Tiles
		for _, tile in CollectionService:GetTagged("FiestaColorTile") do
			if tile:IsA("BasePart") then
				local tileColorName = tostring(tile:GetAttribute("ColorName") or "")
				local isWinTile = (tileColorName == winner.Name)
				tile.Material = if isWinTile then Enum.Material.Neon else Enum.Material.SmoothPlastic

				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local dx = math.abs(root.Position.X - tile.Position.X)
						local dz = math.abs(root.Position.Z - tile.Position.Z)
						local dy = math.abs(root.Position.Y - tile.Position.Y)
						if dx <= tile.Size.X * 0.55 and dz <= tile.Size.Z * 0.55 and dy <= 8 then
							if isWinTile then
								extendPlayerBoost(player, "FiestaMoneyBoostUntil", BOOST_DURATION_SECONDS)
								local jackpot = math.max(2500, EconomyService.GetIncomePerSec(player) * 45)
								EconomyService.AddMoney(player, jackpot)
								ClientSyncService.Notify(
									player,
									`🎲 JACKPOT ({winner.Name})! Won $${NumberFormat.Short(jackpot)} & 💰 2x Pet Cash Boost (3m)!`,
									Color3.fromRGB(95, 255, 130)
								)
							else
								extendPlayerBoost(player, "FiestaMoneyBoostUntil", 60)
								ClientSyncService.Notify(
									player,
									`🎲 Color Game Participation! +1m of 💰 2x Pet Cash Boost! (Winning color: {winner.Name})`,
									Color3.fromRGB(255, 215, 75)
								)
							end
						end
					end
				end
			end
		end

		task.wait(3.0)
		for _, tile in CollectionService:GetTagged("FiestaColorTile") do
			if tile:IsA("BasePart") then
				tile.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	folder:Destroy()
end

-- EVENT 3: 🏺 HAMPAS-PALAYOK (Smash the Golden Clay Pots!) ------------------
local function runPalayokEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	announceEvent:FireAllClients(
		"🏺 HAMPAS-PALAYOK started in the Fiesta Plaza! Smash the Palayok pots for 🍀 2x Titanic Luck & Fast Unlock!",
		workspace:GetServerTimeNow() + 35,
		Color3.fromRGB(255, 165, 45)
	)

	local potOffsets = {
		Vector3.new(-8, 3.2, -7),
		Vector3.new(0, 3.2, -7),
		Vector3.new(8, 3.2, -7),
		Vector3.new(-8, 3.2, 7),
		Vector3.new(0, 3.2, 7),
		Vector3.new(8, 3.2, 7),
	}

	local activePots: { Part } = {}

	local function smashPot(pot: Part, player: Player)
		if not pot.Parent or pot:GetAttribute("Smashed") == true then
			return
		end
		pot:SetAttribute("Smashed", true)
		pot:Destroy()
		extendPlayerBoost(player, "FiestaLuckBoostUntil", BOOST_DURATION_SECONDS)
		ClientSyncService.Notify(
			player,
			"🏺 BASAG ANG PALAYOK! Earned 🍀 2x Titanic/Mutation Luck & 2x Faster Cage Unlock (3m)!",
			Color3.fromRGB(255, 195, 55)
		)
	end

	for idx, off in potOffsets do
		local pot = Instance.new("Part")
		pot.Name = `FiestaPalayok_{idx}`
		pot.Shape = Enum.PartType.Ball
		pot.Size = Vector3.new(3.6, 3.6, 3.6)
		pot.Position = center + off
		pot.Anchored = true
		pot.CanCollide = false
		pot.Color = Color3.fromRGB(215, 115, 45)
		pot.Material = Enum.Material.SmoothPlastic
		pot.Parent = folder

		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 195, 55)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.45
		hl.Parent = pot

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(4.4, 1.2)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.MaxDistance = 60
		bb.Adornee = pot
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(255, 220, 85)
		lbl.TextStrokeTransparency = 0
		lbl.Text = "🏺 SMASH PALAYOK! (2x Luck)"
		lbl.Parent = bb
		bb.Parent = pot

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Smash Palayok!"
		prompt.ObjectText = "🏺 Fiesta Palayok (2x Luck Boost)"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player: Player)
			smashPot(pot, player)
		end)
		prompt.Parent = pot

		table.insert(activePots, pot)
	end

	local duration = 35
	local startClock = os.clock()
	while os.clock() - startClock < duration do
		local elapsed = os.clock() - startClock
		local rem = math.max(0, math.ceil(duration - elapsed))
		local leftCount = 0
		for _, pot in activePots do
			if pot.Parent and pot:GetAttribute("Smashed") ~= true then
				leftCount += 1
			end
		end
		updateStageSigns(
			`🏺 HAMPAS-PALAYOK ({rem}s)`,
			`Smash the Clay Palayok Pots for 🍀 2x Titanic Luck & Fast Cage Unlock! ({leftCount} left)`,
			Color3.fromRGB(255, 180, 55)
		)
		if leftCount == 0 then
			break
		end
		task.wait(0.25)
	end

	folder:Destroy()
end

function FiestaPlazaService.Init()
	local announceEvent = Remotes.GetEvent("EventAnnounce")

	-- Register 2x Cash Income Multiplier when FiestaMoneyBoostUntil is active!
	EconomyService.AddMultiplierProvider("FiestaPlazaBoost", function(player: Player): number
		local untilAttr = player:GetAttribute("FiestaMoneyBoostUntil")
		if typeof(untilAttr) == "number" and untilAttr > workspace:GetServerTimeNow() then
			return 2.0
		end
		return 1.0
	end)

	-- Rotate through the 3 Fiesta Plaza Events continuously!
	task.spawn(function()
		local nextEventIndex = 1
		local eventNames = {
			"🎋 Fiesta Pabitin (2x Speed Boost)",
			"🎲 Perya Color Game (2x Cash Boost)",
			"🏺 Hampas-Palayok (2x Titanic Luck Boost)",
		}

		-- 30s initial warmup on server start so players can get situated first!
		for rem = 30, 1, -1 do
			updateStageSigns(
				`🎪 NEXT FIESTA IN {rem}s`,
				`Up Next: {eventNames[nextEventIndex]} — Gather at the Fiesta Plaza behind the plots!`,
				Color3.fromRGB(255, 215, 55)
			)
			task.wait(1.0)
		end

		while true do
			if nextEventIndex == 1 then
				runPabitinEvent(announceEvent)
			elseif nextEventIndex == 2 then
				runColorGameEvent(announceEvent)
			else
				runPalayokEvent(announceEvent)
			end

			nextEventIndex = (nextEventIndex % 3) + 1

			-- 3.5 minutes (210s) Intermission between Fiesta Plaza events so players focus on prison grinding & speed training!
			for rem = 210, 1, -1 do
				local min = rem // 60
				local sec = rem % 60
				local timeStr = if min > 0 then string.format("%dm %02ds", min, sec) else `{sec}s`
				updateStageSigns(
					`🎪 NEXT FIESTA IN {timeStr}`,
					`Up Next: {eventNames[nextEventIndex]} — Gather at the Fiesta Plaza behind the plots!`,
					Color3.fromRGB(255, 215, 55)
				)
				task.wait(1.0)
			end
		end
	end)
end

return FiestaPlazaService
