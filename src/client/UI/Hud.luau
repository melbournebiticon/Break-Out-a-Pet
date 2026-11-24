--!strict
-- Hud.luau (CLIENT)
-- Left-side Money & Character Speed HUD, Right-side Menu Buttons, Chase Warning,
-- Chat system messages for Lucky/Rainbow Cage events, and clean Zone Entry Toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local InventoryPanel = require(script.Parent:WaitForChild("InventoryPanel"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local Hud = {}

export type PanelCallbacks = {
	TogglePanel: (name: string) -> (),
}

type ZoneMeta = {
	Id: string,
	Title: string,
	Rarities: string,
	MinZ: number,
	MaxZ: number,
	Color: Color3,
}

local ZONES: { ZoneMeta } = {
	{
		Id = "Zone1",
		Title = "🌾 ZONE 1 — BUKID & SABUNGAN",
		Rarities = "Manok, Itik, Puspin, Kuneho, Aspin, Kalabaw • Speed 900+",
		MinZ = -200,
		MaxZ = -50,
		Color = Color3.fromRGB(145, 235, 110),
	},
	{
		Id = "Zone2",
		Title = "🏪 ZONE 2 — PALENGKE & TIANGGE",
		Rarities = "Pagong, Golden Bangus, Alimango, Golden Baboy • Speed 10K+",
		MinZ = -350,
		MaxZ = -200,
		Color = Color3.fromRGB(255, 195, 70),
	},
	{
		Id = "Zone3",
		Title = "🏛️ ZONE 3 — HACIENDA COMPOUND",
		Rarities = "Bayawak, Pawikan, Tarsier, Hunyanggo • Speed 40K+",
		MinZ = -500,
		MaxZ = -350,
		Color = Color3.fromRGB(255, 140, 85),
	},
	{
		Id = "Zone4",
		Title = "🌴 ZONE 4 — BOHOL & PALAWAN GUBAT",
		Rarities = "Pilandok, Agila, Butanding, Ibong Adarna • Speed 170K+",
		MinZ = -650,
		MaxZ = -500,
		Color = Color3.fromRGB(95, 235, 175),
	},
	{
		Id = "Zone5",
		Title = "🌋 ZONE 5 — BULKANG MAYON RIDGE",
		Rarities = "Tamaraw, Sigbin, Minokawa, Butanding • Speed 750K+",
		MinZ = -800,
		MaxZ = -650,
		Color = Color3.fromRGB(255, 95, 65),
	},
	{
		Id = "Zone6",
		Title = "👑 ZONE 6 — INTRAMUROS ROYAL VAULT",
		Rarities = "Sarimanok, Chibi Tikbalang, Baby Bakunawa • Speed 3.5M+",
		MinZ = -950,
		MaxZ = -800,
		Color = Color3.fromRGB(255, 215, 55),
	},
	{
		Id = "Zone7",
		Title = "🌸 ZONE 7 — MYTHICAL SANCTUARY",
		Rarities = "Hamster, Raccoon, Panda, Octopus, Mini Dragon • Speed 18M+",
		MinZ = -1100,
		MaxZ = -950,
		Color = Color3.fromRGB(255, 140, 200),
	},
	{
		Id = "Zone8",
		Title = "🌌 ZONE 8 — CELESTIAL VAULT",
		Rarities = "Diamond Capybara, Wolf, Shadow Kitsune, Rainbow Unicorn • Speed 90M+",
		MinZ = -1255,
		MaxZ = -1100,
		Color = Color3.fromRGB(0, 245, 225),
	},
	{
		Id = "Zone9",
		Title = "⚔️ ZONE 9 — VALHALLA COLISEUM",
		Rarities = "Mecha Lion, Void Phoenix, Semi-Titanic Typhon • Speed 450M+",
		MinZ = -1400,
		MaxZ = -1255,
		Color = Color3.fromRGB(120, 215, 255),
	},
	{
		Id = "Zone10",
		Title = "🔱 ZONE 10 — OLYMPUS TITAN REALM",
		Rarities = "Semi-Titanic Hydra/Golem, Titanic Kalabaw (8.2x) • Speed 2.2B+",
		MinZ = -1550,
		MaxZ = -1400,
		Color = Color3.fromRGB(255, 165, 45),
	},
	{
		Id = "Zone11",
		Title = "🐉 ZONE 11 — DRAGON EMPEROR CITADEL",
		Rarities = "Titanic Agila (9x), Bakunawa (10x), Celestial Dragon (10.5x) • Speed 12B+",
		MinZ = -1700,
		MaxZ = -1550,
		Color = Color3.fromRGB(255, 55, 85),
	},
	{
		Id = "Zone12",
		Title = "👑 ZONE 12 — BATHALA INFINITY THRONE",
		Rarities = "Titanic Sarimanok (11x), Godly Bathala & Astral Leviathan • Speed 65B+",
		MinZ = -1855,
		MaxZ = -1700,
		Color = Color3.fromRGB(255, 225, 95),
	},
}

local function postToChat(text: string, color: Color3)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			local r = math.floor(color.R * 255)
			local g = math.floor(color.G * 255)
			local b = math.floor(color.B * 255)
			local hex = string.format("#%02X%02X%02X", r, g, b)
			general:DisplaySystemMessage(`<font color="{hex}"><b>[EVENT] {text}</b></font>`)
		end
	end)
end

local sideMenuFrame: Frame? = nil

function Hud.SetSideMenuVisible(visible: boolean)
	if sideMenuFrame then
		sideMenuFrame.Visible = visible
	end
end

function Hud.Init(screenGui: ScreenGui, callbacks: PanelCallbacks)
	local player = Players.LocalPlayer

	-- LEFT-SIDE STATS HUD (Total Money + Character Speed + Slow Mode Toggle)
	local leftStats = Instance.new("Frame")
	leftStats.Name = "LeftStatsHud"
	leftStats.Size = UDim2.fromOffset(185, 166)
	leftStats.Position = UDim2.new(0, 16, 0.5, 0)
	leftStats.AnchorPoint = Vector2.new(0, 0.5)
	leftStats.BackgroundTransparency = 1
	leftStats.Parent = screenGui

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.Parent = leftStats

	-- 1) Total Money Pill on the Left
	local moneyCard = Theme.MakeFrame("MoneyCard", UDim2.fromOffset(180, 50), UDim2.fromScale(0, 0), Theme.BgDark, 14, leftStats)
	Theme.AddStroke(moneyCard, Theme.AccentGold, 2)
	local moneyLabel = Theme.MakeLabel("MoneyLabel", "💵 $0", UDim2.fromScale(0.90, 0.74), UDim2.fromScale(0.05, 0.13), Theme.FontTitle, Theme.AccentGold, moneyCard)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- 2) Character WalkSpeed Pill on the Left
	local speedCard = Theme.MakeFrame("SpeedCard", UDim2.fromOffset(180, 50), UDim2.fromScale(0, 0), Theme.BgDark, 14, leftStats)
	Theme.AddStroke(speedCard, Theme.AccentBlue, 2)
	local speedLabel = Theme.MakeLabel("SpeedLabel", "⚡ Speed: 16.0", UDim2.fromScale(0.90, 0.74), UDim2.fromScale(0.05, 0.13), Theme.FontTitle, Color3.fromRGB(120, 215, 255), speedCard)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- 3) Slow Mode Toggle Button (Like Steal a Pet!)
	local slowModeEvent = Remotes.GetEvent("ToggleSlowMode")
	local slowBtn = Theme.MakeButton("SlowModeBtn", "🐢 Slow Mode: OFF", UDim2.fromOffset(180, 38), UDim2.fromScale(0, 0), Theme.BgCard, leftStats, function()
		slowModeEvent:FireServer()
	end)
	Theme.AddStroke(slowBtn, Theme.BgHeader, 2)
	local function updateSlowBtn()
		local isSlow = player:GetAttribute("SlowMode") == true
		slowBtn.Text = if isSlow then "🐢 Slow Mode: ON" else "🐢 Slow Mode: OFF"
		slowBtn.BackgroundColor3 = if isSlow then Theme.AccentGreen else Theme.BgCard
	end
	player:GetAttributeChangedSignal("SlowMode"):Connect(updateSlowBtn)
	updateSlowBtn()

	local function getCurrentPlayerSpeed(): number
		local totalStatAttr = player:GetAttribute("TotalSpeedStat")
		if typeof(totalStatAttr) == "number" and totalStatAttr > 0 then
			return totalStatAttr
		end
		local trainedAttr = player:GetAttribute("TrainedSpeed")
		local trained = if typeof(trainedAttr) == "number" then trainedAttr else 0
		return Config.BaseWalkSpeed + trained
	end

	local function refreshMoney()
		local m = player:GetAttribute("Money")
		local num = if typeof(m) == "number" then m else 0
		moneyLabel.Text = `💵 ${NumberFormat.Short(num)}`
		TweenService:Create(moneyCard, TweenInfo.new(0.07), { Size = UDim2.fromOffset(188, 55) }):Play()
		task.delay(0.07, function()
			if moneyCard.Parent then
				TweenService:Create(moneyCard, TweenInfo.new(0.09), { Size = UDim2.fromOffset(180, 52) }):Play()
			end
		end)
	end

	local function refreshSpeed()
		local spd = getCurrentPlayerSpeed()
		local formatted = if spd >= 1000 then NumberFormat.Short(math.floor(spd + 0.5)) else string.format("%.1f", spd)
		speedLabel.Text = `⚡ Speed: {formatted}`
	end

	player:GetAttributeChangedSignal("Money"):Connect(refreshMoney)
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshSpeed)
	player:GetAttributeChangedSignal("TrainedSpeed"):Connect(refreshSpeed)
	player:GetAttributeChangedSignal("TotalSpeedStat"):Connect(refreshSpeed)
	refreshMoney()
	refreshSpeed()

	-- SLIDE-LEFT "UNLOCKING CAGES" DRAWER (Manual open only via Cages button; replaces right-side menu while open!)
	local remoteOpenCageEvent = Remotes.GetEvent("RemoteOpenPlotCage")
	local cagesDrawerOpen = false
	local cagesOpenPos = UDim2.new(1, -12, 0.5, 0)
	local cagesClosedPos = UDim2.new(1, 260, 0.5, 0)

	local cagesDrawer = Theme.MakeFrame(
		"UnlockingCagesDrawer",
		UDim2.fromOffset(236, 224),
		cagesClosedPos,
		Color3.fromRGB(28, 30, 38),
		10,
		screenGui
	)
	cagesDrawer.AnchorPoint = Vector2.new(1, 0.5)
	cagesDrawer.Visible = false
	cagesDrawer.ZIndex = 18
	Theme.AddStroke(cagesDrawer, Color3.fromRGB(15, 16, 22), 3)

	local function setCagesDrawerVisible(visible: boolean)
		cagesDrawerOpen = visible
		if visible then
			InventoryPanel.SetVisible(false)
			Hud.SetSideMenuVisible(false)
			cagesDrawer.Visible = true
			TweenService:Create(cagesDrawer, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = cagesOpenPos,
			}):Play()
		else
			TweenService:Create(cagesDrawer, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = cagesClosedPos,
			}):Play()
			task.delay(0.19, function()
				if not cagesDrawerOpen and cagesDrawer then
					cagesDrawer.Visible = false
				end
			end)
			Hud.SetSideMenuVisible(true)
		end
	end

	local cagesCollapseBtn = Theme.MakeButton(
		"CollapseTab",
		">",
		UDim2.fromOffset(28, 32),
		UDim2.new(0, -32, 0.5, -16),
		Color3.fromRGB(215, 42, 42),
		cagesDrawer,
		function()
			setCagesDrawerVisible(false)
		end
	)
	Theme.AddStroke(cagesCollapseBtn, Color3.fromRGB(20, 20, 25), 2)

	local cagesHeader = Theme.MakeFrame("Header", UDim2.new(1, -10, 0, 34), UDim2.fromOffset(5, 5), Color3.fromRGB(20, 22, 28), 8, cagesDrawer)
	local cagesTitle = Theme.MakeLabel(
		"Title",
		"Unlocking Cages",
		UDim2.new(0.60, 0, 1, 0),
		UDim2.fromOffset(6, 0),
		Theme.FontTitle,
		Color3.fromRGB(255, 235, 180),
		cagesHeader
	)
	cagesTitle.TextXAlignment = Enum.TextXAlignment.Left

	Theme.MakeButton(
		"OpenAllBtn",
		"Open All",
		UDim2.fromOffset(74, 24),
		UDim2.new(1, -78, 0.5, -12),
		Color3.fromRGB(185, 145, 75),
		cagesHeader,
		function()
			SoundController.Play("UiClick")
			remoteOpenCageEvent:FireServer("ALL")
		end
	)

	local cagesScroll = Instance.new("ScrollingFrame")
	cagesScroll.Name = "CageRows"
	cagesScroll.Size = UDim2.new(1, -10, 1, -46)
	cagesScroll.Position = UDim2.fromOffset(5, 42)
	cagesScroll.BackgroundTransparency = 1
	cagesScroll.BorderSizePixel = 0
	cagesScroll.ScrollBarThickness = 5
	cagesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cagesScroll.CanvasSize = UDim2.fromOffset(0, 0)
	cagesScroll.Parent = cagesDrawer

	local cagesLayout = Instance.new("UIListLayout")
	cagesLayout.Padding = UDim.new(0, 6)
	cagesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cagesLayout.Parent = cagesScroll

	type ClientUnlockCage = {
		Id: string,
		PetId: string,
		Mutation: string?,
		UnlockClientTime: number,
		Ready: boolean,
	}
	local trackedUnlockCages: { ClientUnlockCage } = {}

	local function rebuildCagesDrawer()
		for _, child in cagesScroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #trackedUnlockCages == 0 then
			Theme.MakeLabel(
				"EmptyHint",
				"No cages unlocking on your plot.\nSteal a cage from a Zone and place it on your plot!",
				UDim2.new(1, -12, 0, 65),
				UDim2.fromOffset(6, 12),
				Theme.FontBody,
				Theme.TextMuted,
				cagesScroll
			)
			return
		end

		local now = os.clock()
		for idx, item in trackedUnlockCages do
			local pet = PetData.Get(item.PetId)
			local rarity = if pet then Rarities.Get(pet.Rarity) else Rarities.Data.Common
			local mutInfo = MutationData.Get(item.Mutation)

			local row = Theme.MakeFrame(
				item.Id,
				UDim2.new(1, -4, 0, 46),
				UDim2.fromScale(0, 0),
				Color3.fromRGB(42, 46, 58),
				8,
				cagesScroll
			)
			row.LayoutOrder = idx
			Theme.AddStroke(row, if mutInfo then mutInfo.Color else rarity.Color, 1.5)

			local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
			local display = if pet then `{pet.Emoji} {prefix}{pet.DisplayName}` else "📦 Mystery Cage"
			local nameLbl = Theme.MakeLabel(
				"CageName",
				display,
				UDim2.new(0.58, 0, 1, 0),
				UDim2.fromOffset(10, 0),
				Theme.FontTitle,
				if mutInfo then mutInfo.Color else rarity.Color,
				row
			)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local rem = math.max(0, math.ceil(item.UnlockClientTime - now))
			local isReady = item.Ready or rem <= 0
			if isReady then
				Theme.MakeButton(
					"OpenBtn",
					"Open",
					UDim2.fromOffset(82, 30),
					UDim2.new(1, -90, 0.5, -15),
					Color3.fromRGB(65, 195, 75),
					row,
					function()
						SoundController.Play("UiClick")
						remoteOpenCageEvent:FireServer(item.Id)
					end
				)
			else
				local timerLbl = Theme.MakeLabel(
					"TimerLbl",
					`⏳ {rem}s`,
					UDim2.fromOffset(82, 30),
					UDim2.new(1, -90, 0.5, -15),
					Theme.FontTitle,
					Theme.AccentGold,
					row
				)
				timerLbl.Name = "TimerLbl"
			end
		end
	end

	Remotes.GetEvent("SyncUnlockingCages").OnClientEvent:Connect(function(list: any)
		if typeof(list) ~= "table" then
			return
		end
		local now = os.clock()
		local newTracked: { ClientUnlockCage } = {}
		for _, entry in list do
			if typeof(entry) == "table" and typeof(entry.Id) == "string" then
				local rem = if typeof(entry.Remaining) == "number" then entry.Remaining else 0
				table.insert(newTracked, {
					Id = entry.Id,
					PetId = tostring(entry.PetId or "chicken"),
					Mutation = if typeof(entry.Mutation) == "string" then entry.Mutation else nil,
					UnlockClientTime = now + rem,
					Ready = entry.Ready == true or rem <= 0,
				})
			end
		end
		trackedUnlockCages = newTracked
		rebuildCagesDrawer()
	end)

	-- Live 1-second countdown refresh inside Unlocking Cages drawer
	task.spawn(function()
		while true do
			task.wait(0.5)
			if cagesDrawerOpen and #trackedUnlockCages > 0 then
				rebuildCagesDrawer()
			end
		end
	end)

	-- RIGHT-SIDE MENU BUTTONS (Compact & hides when any panel/drawer is open!)
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.Size = UDim2.fromOffset(108, 285)
	sideMenu.Position = UDim2.new(1, -12, 0.5, 0)
	sideMenu.AnchorPoint = Vector2.new(1, 0.5)
	sideMenu.BackgroundTransparency = 1
	sideMenu.Parent = screenGui
	sideMenuFrame = sideMenu

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Parent = sideMenu

	Theme.MakeButton("CagesBtn", "📦 Cages", UDim2.fromOffset(104, 40), UDim2.fromScale(0, 0), Color3.fromRGB(235, 95, 75), sideMenu, function()
		setCagesDrawerVisible(not cagesDrawerOpen)
	end)

	local buttons = {
		{ id = "Pets", text = "🐾 Pets", color = Theme.AccentBlue },
		{ id = "Shop", text = "🛒 Shop", color = Theme.AccentGreen },
		{ id = "Fusion", text = "⚗️ Fuse", color = Theme.AccentPurple },
		{ id = "Daily", text = "🎁 Daily", color = Theme.AccentGold },
		{ id = "Trade", text = "🤝 Trade", color = Color3.fromRGB(235, 130, 50) },
	}

	for _, b in buttons do
		Theme.MakeButton(b.id .. "Btn", b.text, UDim2.fromOffset(104, 40), UDim2.fromScale(0, 0), b.color, sideMenu, function()
			cagesDrawerOpen = false
			cagesDrawer.Visible = false
			callbacks.TogglePanel(b.id)
		end)
	end

	-- RED CHASE WARNING BANNER & SCREEN EDGE
	local chaseEdge = Theme.MakeFrame("ChaseEdge", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.AccentRed, 0, screenGui)
	chaseEdge.BackgroundTransparency = 1
	chaseEdge.Visible = false
	local edgeStroke = Instance.new("UIStroke")
	edgeStroke.Color = Theme.AccentRed
	edgeStroke.Thickness = 8
	edgeStroke.Parent = chaseEdge

	local chaseBanner = Theme.MakeLabel(
		"ChaseBanner",
		"⚠️ HINAHABOL KA NG BANTAY! ⚠️",
		UDim2.new(0.65, 0, 0, 36),
		UDim2.new(0.5, 0, 0, 84),
		Theme.FontTitle,
		Theme.AccentRed,
		chaseEdge
	)
	chaseBanner.AnchorPoint = Vector2.new(0.5, 0)

	local function updateChaseState()
		local chaserAttr = player:GetAttribute("ChaserName")
		local chaserName = if typeof(chaserAttr) == "string" and chaserAttr ~= "" then chaserAttr else "BANTAY"
		chaseBanner.Text = `⚠️ HINAHABOL KA NG {chaserName}! ⚠️`
		chaseEdge.Visible = player:GetAttribute("BeingChased") == true
	end
	player:GetAttributeChangedSignal("BeingChased"):Connect(updateChaseState)
	player:GetAttributeChangedSignal("ChaserName"):Connect(updateChaseState)
	updateChaseState()

	-- LUCKY / RAINBOW CAGE ANNOUNCEMENTS -> Sent to Chat window instead of a floating UI banner!
	Remotes.GetEvent("EventAnnounce").OnClientEvent:Connect(function(text: any, _endsAt: any, color: any)
		if typeof(text) == "string" then
			postToChat(text, if typeof(color) == "Color3" then color else Theme.AccentGold)
		end
	end)

	-- "📦 CLICK / TAP TO PLACE CAGE" (No E key needed — click button or click anywhere on your plot grass!)
	local placeCageEvent = Remotes.GetEvent("PlaceCageOnPlot")
	local placeCageBtn = Theme.MakeButton(
		"PlaceCageBtn",
		"📦 Tap / Click Plot to Place Cage",
		UDim2.fromOffset(270, 48),
		UDim2.new(0.5, -135, 1, -84),
		Theme.AccentGreen,
		screenGui,
		function()
			placeCageEvent:FireServer()
		end
	)
	placeCageBtn.Visible = false
	Theme.AddStroke(placeCageBtn, Color3.new(1, 1, 1), 2)

	local function getOwnPlotFloor(): BasePart?
		local plots = workspace:FindFirstChild("BasePlots")
		if not plots then
			return nil
		end
		for _, plot in plots:GetChildren() do
			if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
				local floor = plot:FindFirstChild("Floor")
				if floor and floor:IsA("BasePart") then
					return floor
				end
			end
		end
		return nil
	end

	local function isStandingNearOwnPlot(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local floor = getOwnPlotFloor()
		if not root or not root:IsA("BasePart") or not floor then
			return false
		end
		local dx = math.abs(root.Position.X - floor.Position.X)
		local dz = math.abs(root.Position.Z - floor.Position.Z)
		return dx <= floor.Size.X * 0.5 + 8 and dz <= floor.Size.Z * 0.5 + 8
	end

	-- Clicking / Tapping anywhere on your plot grass while carrying a cage places it right where you clicked!
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if player:GetAttribute("IsCarryingCage") ~= true or not isStandingNearOwnPlot() then
			return
		end
		local cam = workspace.CurrentCamera
		local floor = getOwnPlotFloor()
		if not cam or not floor then
			return
		end
		local pos = input.Position
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 250)
		if result then
			local dx = math.abs(result.Position.X - floor.Position.X)
			local dz = math.abs(result.Position.Z - floor.Position.Z)
			if dx <= floor.Size.X * 0.5 + 2 and dz <= floor.Size.Z * 0.5 + 2 then
				placeCageEvent:FireServer(result.Position)
			end
		end
	end)

	-- ZONE ENTRY TOAST DETECTOR
	local currentZoneId = "SafeBase"
	local lastZoneCheck = 0

	RunService.Heartbeat:Connect(function()
		refreshSpeed()
		placeCageBtn.Visible = (player:GetAttribute("IsCarryingCage") == true) and isStandingNearOwnPlot()

		if chaseEdge.Visible then
			local pulse = 0.25 + 0.55 * math.abs(math.sin(os.clock() * 5))
			edgeStroke.Transparency = pulse
		end

		local now = os.clock()
		if now - lastZoneCheck >= 0.25 then
			lastZoneCheck = now
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local pos = root.Position
				local detectedId = "SafeBase"
				local detectedMeta: ZoneMeta? = nil

				if math.abs(pos.X) <= 44 then
					for _, zm in ZONES do
						if pos.Z >= zm.MinZ and pos.Z <= zm.MaxZ then
							detectedId = zm.Id
							detectedMeta = zm
							break
						end
					end
				end

				if detectedId ~= currentZoneId then
					currentZoneId = detectedId
					if detectedMeta then
						Toasts.Show(detectedMeta.Title, detectedMeta.Color, detectedMeta.Rarities)
					end
				end
			end
		end
	end)
end

return Hud
