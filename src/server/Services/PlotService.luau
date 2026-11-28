--!strict
-- PlotService.luau (SERVER)
-- Assigns each player their own 100% safe base plot from Workspace.BasePlots, manages respawn location,
-- and evolves the plot's 3D Pinoy architecture across 3 tiers based on total plot $/s or cash milestones:
--   * Tier 1: 🛖 Kawayan Bakod & Nipa Hut (Kubo)
--   * Tier 2: 🏛️ Bahay na Bato with stone walls & glowing capiz-style windows
--   * Tier 3: 👑 Intramuros Courtyard with decorative parol star lanterns & festive banderitas

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local PlotService = {}

local PlotClaimedEvent = Instance.new("BindableEvent")
PlotService.PlotClaimed = PlotClaimedEvent.Event

local plots: { Model } = {}
local plotByUserId: { [number]: Model } = {}
local builtTierByPlot: { [Model]: number } = {}

local function makeArchPart(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setDefaultFenceVisible(plot: Model, visible: boolean)
	for _, fenceName in { "FenceLeft", "FenceRight", "FenceBack" } do
		local f = plot:FindFirstChild(fenceName)
		if f and f:IsA("BasePart") then
			f.Transparency = if visible then 0 else 1
			f.CanCollide = visible
		end
	end
end

local function buildParolLantern(parent: Instance, pos: Vector3, starColor: Color3)
	local disc = makeArchPart("ParolRing", Vector3.new(0.3, 2.2, 2.2), CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0), starColor, Enum.Material.Neon, parent, false)
	disc.Shape = Enum.PartType.Cylinder
	makeArchPart("ParolStarA", Vector3.new(1.7, 1.7, 0.36), CFrame.new(pos), Color3.fromRGB(255, 240, 130), Enum.Material.Neon, parent, false)
	makeArchPart("ParolStarB", Vector3.new(1.7, 1.7, 0.36), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(45)), starColor, Enum.Material.Neon, parent, false)
	makeArchPart("ParolTailL", Vector3.new(0.28, 1.3, 0.18), CFrame.new(pos + Vector3.new(-0.45, -1.45, 0)), starColor, Enum.Material.Neon, parent, false)
	makeArchPart("ParolTailR", Vector3.new(0.28, 1.3, 0.18), CFrame.new(pos + Vector3.new(0.45, -1.45, 0)), starColor, Enum.Material.Neon, parent, false)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Brightness = 1.4
	light.Range = 18
	light.Parent = disc
end

local function buildPlotTierArchitecture(plot: Model, tier: number)
	local floor = plot:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		return
	end

	setDefaultFenceVisible(plot, false)

	local oldFolder = plot:FindFirstChild("PlotArchitecture")
	if oldFolder then
		oldFolder:Destroy()
	end

	local arch = Instance.new("Folder")
	arch.Name = "PlotArchitecture"
	arch.Parent = plot

	local center = floor.Position
	local half = 29.5

	-- Front Plot Signpost (Left of entrance, outside the pet yard)
	local signPos = center + Vector3.new(-16.5, 0.5, -29.4)
	makeArchPart("SignPostL", Vector3.new(0.65, 6.2, 0.65), CFrame.new(signPos + Vector3.new(-4.8, 3.1, 0)), Color3.fromRGB(110, 72, 36), Enum.Material.Wood, arch, false)
	makeArchPart("SignPostR", Vector3.new(0.65, 6.2, 0.65), CFrame.new(signPos + Vector3.new(4.8, 3.1, 0)), Color3.fromRGB(110, 72, 36), Enum.Material.Wood, arch, false)
	local signBoard = makeArchPart("PlotOwnerSign", Vector3.new(11.5, 3.0, 0.6), CFrame.new(signPos + Vector3.new(0, 5.0, 0)), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, arch, false)

	if tier == 1 then
		-- TIER 1: 🛖 KAWAYAN BAKOD & NIPA HUT (BAHAY KUBO)
		local bambooLight = Color3.fromRGB(182, 148, 76)
		local bambooDark = Color3.fromRGB(132, 96, 46)
		local nipaRoof = Color3.fromRGB(158, 114, 52)

		-- Clean Smooth Bamboo Fence (Left, Right, Back — no spiky posts sticking out!)
		makeArchPart("BambooFenceL", Vector3.new(0.9, 3.0, half * 2), CFrame.new(center + Vector3.new(-half, 2.0, 0)), bambooLight, Enum.Material.WoodPlanks, arch, true)
		makeArchPart("BambooFenceR", Vector3.new(0.9, 3.0, half * 2), CFrame.new(center + Vector3.new(half, 2.0, 0)), bambooLight, Enum.Material.WoodPlanks, arch, true)
		makeArchPart("BambooFenceB", Vector3.new(half * 2, 3.0, 0.9), CFrame.new(center + Vector3.new(0, 2.0, half)), bambooLight, Enum.Material.WoodPlanks, arch, true)

		-- Cozy Elevated Bahay Kubo (Nipa Hut) at the back-right corner of the plot
		local kuboCenter = center + Vector3.new(20.5, 0.5, 21.0)
		for _, stiltOff in {
			Vector3.new(-4.2, 1.5, -3.6),
			Vector3.new(4.2, 1.5, -3.6),
			Vector3.new(-4.2, 1.5, 3.6),
			Vector3.new(4.2, 1.5, 3.6),
		} do
			makeArchPart("KuboStilt", Vector3.new(0.75, 3.0, 0.75), CFrame.new(kuboCenter + stiltOff), bambooDark, Enum.Material.Wood, arch, true)
		end
		makeArchPart("KuboFloor", Vector3.new(9.8, 0.45, 8.4), CFrame.new(kuboCenter + Vector3.new(0, 3.1, 0)), bambooDark, Enum.Material.WoodPlanks, arch, true)
		makeArchPart("KuboWalls", Vector3.new(8.8, 4.6, 7.4), CFrame.new(kuboCenter + Vector3.new(0, 5.6, 0)), bambooLight, Enum.Material.WoodPlanks, arch, true)
		makeArchPart("KuboWindow", Vector3.new(3.2, 2.0, 0.25), CFrame.new(kuboCenter + Vector3.new(0, 5.8, -3.75)), Color3.fromRGB(48, 34, 22), Enum.Material.SmoothPlastic, arch, false)
		makeArchPart(
			"KuboWindowFlap",
			Vector3.new(3.4, 2.1, 0.2),
			CFrame.new(kuboCenter + Vector3.new(0, 6.6, -4.35)) * CFrame.Angles(math.rad(-42), 0, 0),
			bambooDark,
			Enum.Material.WoodPlanks,
			arch,
			false
		)
		makeArchPart(
			"KuboRoofFront",
			Vector3.new(11.2, 0.55, 5.8),
			CFrame.new(kuboCenter + Vector3.new(0, 9.2, -2.1)) * CFrame.Angles(math.rad(30), 0, 0),
			nipaRoof,
			Enum.Material.WoodPlanks,
			arch,
			false
		)
		makeArchPart(
			"KuboRoofBack",
			Vector3.new(11.2, 0.55, 5.8),
			CFrame.new(kuboCenter + Vector3.new(0, 9.2, 2.1)) * CFrame.Angles(math.rad(-30), 0, 0),
			nipaRoof,
			Enum.Material.WoodPlanks,
			arch,
			false
		)

	else
		-- TIER 2 & TIER 3: 🏛️ BAHAY NA BATO / 👑 INTRAMUROS ROYAL COURTYARD
		local isRoyal = (tier >= 3)
		local stoneColor = if isRoyal then Color3.fromRGB(228, 218, 198) else Color3.fromRGB(162, 154, 142)
		local woodUpper = if isRoyal then Color3.fromRGB(112, 58, 32) else Color3.fromRGB(128, 78, 44)
		local trimGold = if isRoyal then Color3.fromRGB(255, 205, 55) else Color3.fromRGB(195, 155, 88)
		local capizGlow = Color3.fromRGB(255, 244, 195)
		local roofTile = if isRoyal then Color3.fromRGB(175, 42, 38) else Color3.fromRGB(155, 62, 42)

		-- Clean Smooth Stone Perimeter Walls + Gold Trim (no spiky pillars sticking out!)
		makeArchPart("StoneWallL", Vector3.new(1.2, 3.2, half * 2), CFrame.new(center + Vector3.new(-half, 2.0, 0)), stoneColor, Enum.Material.Cobblestone, arch, true)
		makeArchPart("StoneWallR", Vector3.new(1.2, 3.2, half * 2), CFrame.new(center + Vector3.new(half, 2.0, 0)), stoneColor, Enum.Material.Cobblestone, arch, true)
		makeArchPart("StoneWallB", Vector3.new(half * 2, 3.2, 1.2), CFrame.new(center + Vector3.new(0, 2.0, half)), stoneColor, Enum.Material.Cobblestone, arch, true)

		makeArchPart("WallTrimL", Vector3.new(1.35, 0.35, half * 2), CFrame.new(center + Vector3.new(-half, 3.7, 0)), trimGold, if isRoyal then Enum.Material.Neon else Enum.Material.Metal, arch, false)
		makeArchPart("WallTrimR", Vector3.new(1.35, 0.35, half * 2), CFrame.new(center + Vector3.new(half, 3.7, 0)), trimGold, if isRoyal then Enum.Material.Neon else Enum.Material.Metal, arch, false)
		makeArchPart("WallTrimB", Vector3.new(half * 2, 0.35, 1.35), CFrame.new(center + Vector3.new(0, 3.7, half)), trimGold, if isRoyal then Enum.Material.Neon else Enum.Material.Metal, arch, false)

		-- Bahay na Bato Facade at the Back of the Plot
		local housePos = center + Vector3.new(16.5, 0.5, 22.0)
		makeArchPart("ZaguanStoneBase", Vector3.new(18.0, 5.0, 8.8), CFrame.new(housePos + Vector3.new(0, 2.5, 0)), stoneColor, Enum.Material.Cobblestone, arch, true)
		makeArchPart("VoladaUpperWood", Vector3.new(19.6, 5.4, 9.8), CFrame.new(housePos + Vector3.new(0, 7.7, 0)), woodUpper, Enum.Material.WoodPlanks, arch, true)
		for wx = -6.0, 6.0, 4.0 do
			makeArchPart(`CapizWindow_{wx}`, Vector3.new(2.8, 2.6, 0.25), CFrame.new(housePos + Vector3.new(wx, 7.9, -4.95)), capizGlow, Enum.Material.Neon, arch, false)
			makeArchPart(`CapizFrame_{wx}`, Vector3.new(3.1, 0.22, 0.32), CFrame.new(housePos + Vector3.new(wx, 7.9, -4.98)), woodUpper, Enum.Material.Wood, arch, false)
		end
		makeArchPart(
			"TileRoofFront",
			Vector3.new(21.0, 0.6, 6.4),
			CFrame.new(housePos + Vector3.new(0, 11.8, -2.5)) * CFrame.Angles(math.rad(26), 0, 0),
			roofTile,
			Enum.Material.Slate,
			arch,
			false
		)
		makeArchPart(
			"TileRoofBack",
			Vector3.new(21.0, 0.6, 6.4),
			CFrame.new(housePos + Vector3.new(0, 11.8, 2.5)) * CFrame.Angles(math.rad(-26), 0, 0),
			roofTile,
			Enum.Material.Slate,
			arch,
			false
		)

		if isRoyal then
			buildParolLantern(arch, housePos + Vector3.new(-8.2, 6.5, -5.2), Color3.fromRGB(255, 215, 55))
			buildParolLantern(arch, housePos + Vector3.new(8.2, 6.5, -5.2), Color3.fromRGB(255, 215, 55))
		end
	end

	-- Attach SurfaceGuis on both sides of PlotOwnerSign
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sgui = Instance.new("SurfaceGui")
		sgui.Name = `SignGui_{face.Name}`
		sgui.Face = face
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 35
		sgui.Parent = signBoard

		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
		bg.BorderSizePixel = 0
		bg.Parent = sgui

		local stroke = Instance.new("UIStroke")
		stroke.Name = "BorderStroke"
		stroke.Color = Color3.fromRGB(255, 205, 55)
		stroke.Thickness = 4
		stroke.Parent = bg

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "Title"
		titleLbl.Size = UDim2.fromScale(0.94, 0.50)
		titleLbl.Position = UDim2.fromScale(0.03, 0.06)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.FredokaOne
		titleLbl.TextScaled = true
		titleLbl.TextColor3 = Color3.fromRGB(255, 220, 75)
		titleLbl.Text = "🛖 BAHAY KUBO"
		titleLbl.Parent = bg

		local subLbl = Instance.new("TextLabel")
		subLbl.Name = "Sub"
		subLbl.Size = UDim2.fromScale(0.94, 0.38)
		subLbl.Position = UDim2.fromScale(0.03, 0.56)
		subLbl.BackgroundTransparency = 1
		subLbl.Font = Enum.Font.GothamBold
		subLbl.TextScaled = true
		subLbl.TextColor3 = Color3.fromRGB(120, 255, 145)
		subLbl.Text = "100% Safe Plot"
		subLbl.Parent = bg
	end
end

function PlotService.UpdatePlotArchitecture(player: Player)
	local plot = plotByUserId[player.UserId]
	if not plot then
		return
	end

	local incomeAttr = player:GetAttribute("IncomePerSec")
	local income = if typeof(incomeAttr) == "number" then incomeAttr else 0
	local moneyAttr = player:GetAttribute("Money")
	local money = if typeof(moneyAttr) == "number" then moneyAttr else 0

	local targetTier = ShopData.GetPlotEvolutionTier(income, money)
	local prevTier = builtTierByPlot[plot] or 0
	if targetTier ~= prevTier then
		builtTierByPlot[plot] = targetTier
		player:SetAttribute("PlotEvolutionTier", targetTier)
		plot:SetAttribute("EvolutionTier", targetTier)
		buildPlotTierArchitecture(plot, targetTier)
		if prevTier > 0 and targetTier > prevTier then
			local tierMeta = ShopData.PlotEvolutionTiers[targetTier]
			local tierTitle = if tierMeta then tierMeta.Title else `Tier {targetTier}`
			ClientSyncService.Notify(
				player,
				`🏡 PLOT EVOLVED! Your base upgraded to {tierTitle}!`,
				Color3.fromRGB(255, 215, 55)
			)
		end
	end

	local tierMeta = ShopData.PlotEvolutionTiers[targetTier] or ShopData.PlotEvolutionTiers[1]
	local comboTitleAttr = player:GetAttribute("BarkadaComboTitle")
	local comboTitle = if typeof(comboTitleAttr) == "string" then comboTitleAttr else ""
	local busogUntilAttr = player:GetAttribute("PetBusogUntil")
	local isBusog = typeof(busogUntilAttr) == "number" and busogUntilAttr > workspace:GetServerTimeNow()

	local subParts = { `💰 +$${NumberFormat.Short(income)}/s` }
	if comboTitle ~= "" then
		table.insert(subParts, `🤝 {comboTitle} (+25%)`)
	end
	if isBusog then
		table.insert(subParts, "🍡 BUSOG (+20%)")
	end
	local subText = table.concat(subParts, "  •  ")

	local arch = plot:FindFirstChild("PlotArchitecture")
	local signBoard = arch and arch:FindFirstChild("PlotOwnerSign")
	if signBoard then
		for _, child in signBoard:GetChildren() do
			if child:IsA("SurfaceGui") then
				local bg = child:FindFirstChild("Bg")
				if bg then
					local tLbl = bg:FindFirstChild("Title") :: TextLabel?
					local sLbl = bg:FindFirstChild("Sub") :: TextLabel?
					local st = bg:FindFirstChild("BorderStroke") :: UIStroke?
					if tLbl then
						tLbl.Text = `{player.DisplayName} — {tierMeta.Title}`
						tLbl.TextColor3 = tierMeta.AccentColor
					end
					if sLbl then
						sLbl.Text = subText
					end
					if st then
						st.Color = tierMeta.AccentColor
					end
				end
			end
		end
	end
end

function PlotService.SetShield(plot: Model, durationSeconds: number)
	local now = workspace:GetServerTimeNow()
	local current = plot:GetAttribute("ShieldUntil")
	local curNum = if typeof(current) == "number" then current else 0
	plot:SetAttribute("ShieldUntil", math.max(curNum, now + durationSeconds))
end

function PlotService.IsShielded(_plot: Model): boolean
	-- Player bases/plots are strictly 100% safe!
	return true
end

function PlotService.Claim(player: Player): Model?
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return nil
	end

	if plotByUserId[player.UserId] then
		return plotByUserId[player.UserId]
	end

	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			plotByUserId[player.UserId] = plot
			builtTierByPlot[plot] = 0

			PlotService.SetShield(plot, Config.NewPlayerProtectionSeconds)
			PlotService.UpdatePlotArchitecture(player)

			local spawnPart = plot:FindFirstChild("Spawn")
			if spawnPart and spawnPart:IsA("SpawnLocation") then
				player.RespawnLocation = spawnPart
				local function moveToPlot(character: Model)
					task.defer(function()
						if character.Parent and plotByUserId[player.UserId] == plot then
							character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
						end
					end)
				end
				player.CharacterAdded:Connect(moveToPlot)
				if player.Character then
					moveToPlot(player.Character)
				end
			end

			PlotClaimedEvent:Fire(player, plot)
			return plot
		end
	end

	warn(`No free plot for {player.Name}`)
	return nil
end

function PlotService.Release(player: Player)
	local plot = plotByUserId[player.UserId]
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		plot:SetAttribute("ShieldUntil", 0)
		builtTierByPlot[plot] = nil
		local oldArch = plot:FindFirstChild("PlotArchitecture")
		if oldArch then
			oldArch:Destroy()
		end
		setDefaultFenceVisible(plot, true)
		plotByUserId[player.UserId] = nil
	end
end

function PlotService.GetPlot(player: Player): Model?
	return plotByUserId[player.UserId]
end

function PlotService.GetAllPlots(): { Model }
	return plots
end

function PlotService.Init()
	local folder = workspace:WaitForChild("BasePlots", 10)
	if not folder then
		warn("Workspace.BasePlots not found. Run studio/Blockout.luau in the Studio command bar first.")
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			child:SetAttribute("OwnerUserId", 0)
			child:SetAttribute("OwnerName", "")
			child:SetAttribute("ShieldUntil", 0)
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(PlotService.Claim, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(PlotService.Claim, player)
	end
	Players.PlayerRemoving:Connect(PlotService.Release)

	-- Periodically check plot evolution milestones & refresh live $/s / Barkada / Busog sign text
	task.spawn(function()
		while true do
			task.wait(2.0)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) and plotByUserId[player.UserId] then
					PlotService.UpdatePlotArchitecture(player)
				end
			end
		end
	end)
end

return PlotService
