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
		Rarities = "Manok, Itik, Puspin, Kuneho, Aspin, Kalabaw • Speed 16+",
		MinZ = -200,
		MaxZ = -50,
		Color = Color3.fromRGB(145, 235, 110),
	},
	{
		Id = "Zone2",
		Title = "🏪 ZONE 2 — PALENGKE & TIANGGE",
		Rarities = "Pagong, Golden Bangus, Alimango, Golden Baboy • Speed 19+",
		MinZ = -350,
		MaxZ = -200,
		Color = Color3.fromRGB(255, 195, 70),
	},
	{
		Id = "Zone3",
		Title = "🏛️ ZONE 3 — HACIENDA COMPOUND",
		Rarities = "Bayawak, Pawikan, Tarsier, Hunyanggo • Speed 22+",
		MinZ = -500,
		MaxZ = -350,
		Color = Color3.fromRGB(255, 140, 85),
	},
	{
		Id = "Zone4",
		Title = "🌴 ZONE 4 — BOHOL & PALAWAN GUBAT",
		Rarities = "Pilandok, Agila, Butanding, Ibong Adarna • Speed 26+",
		MinZ = -650,
		MaxZ = -500,
		Color = Color3.fromRGB(95, 235, 175),
	},
	{
		Id = "Zone5",
		Title = "🌋 ZONE 5 — BULKANG MAYON RIDGE",
		Rarities = "Tamaraw, Sigbin, Minokawa, Butanding • Speed 30+",
		MinZ = -800,
		MaxZ = -650,
		Color = Color3.fromRGB(255, 95, 65),
	},
	{
		Id = "Zone6",
		Title = "👑 ZONE 6 — INTRAMUROS ROYAL VAULT",
		Rarities = "Sarimanok, Chibi Tikbalang, Baby Bakunawa • Speed 35+",
		MinZ = -950,
		MaxZ = -800,
		Color = Color3.fromRGB(255, 215, 55),
	},
	{
		Id = "Zone7",
		Title = "🌸 ZONE 7 — MYTHICAL SANCTUARY",
		Rarities = "Hamster, Raccoon, Panda, Octopus, Mini Dragon • Speed 40+",
		MinZ = -1100,
		MaxZ = -950,
		Color = Color3.fromRGB(255, 140, 200),
	},
	{
		Id = "Zone8",
		Title = "🌌 ZONE 8 — CELESTIAL VAULT",
		Rarities = "Diamond Capybara, Wolf, Shadow Kitsune, Rainbow Unicorn • Speed 45+",
		MinZ = -1255,
		MaxZ = -1100,
		Color = Color3.fromRGB(0, 245, 225),
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
		if player:GetAttribute("OnTreadmill") == true then
			local actualAttr = player:GetAttribute("ActualWalkSpeed")
			if typeof(actualAttr) == "number" and actualAttr > 0 then
				return actualAttr
			end
			local trainedAttr = player:GetAttribute("TrainedSpeed")
			local trained = if typeof(trainedAttr) == "number" then trainedAttr else 0
			local slow = if player:GetAttribute("SlowMode") == true then 0.55 else 1
			return (Config.BaseWalkSpeed + trained) * slow
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.WalkSpeed > 0 then
			return humanoid.WalkSpeed
		end
		local lvlAttr = player:GetAttribute("SpeedLevel")
		local lvl = if typeof(lvlAttr) == "number" then lvlAttr else 0
		return Config.BaseWalkSpeed + lvl * ShopData.Speed.SpeedPerLevel
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
		speedLabel.Text = string.format("⚡ Speed: %.1f", spd)
	end

	player:GetAttributeChangedSignal("Money"):Connect(refreshMoney)
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshSpeed)
	refreshMoney()
	refreshSpeed()

	-- RIGHT-SIDE MENU BUTTONS
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.Size = UDim2.fromOffset(125, 290)
	sideMenu.Position = UDim2.new(1, -14, 0.5, 0)
	sideMenu.AnchorPoint = Vector2.new(1, 0.5)
	sideMenu.BackgroundTransparency = 1
	sideMenu.Parent = screenGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Parent = sideMenu

	local buttons = {
		{ id = "Pets", text = "🐾 Pets", color = Theme.AccentBlue },
		{ id = "Shop", text = "🛒 Shop", color = Theme.AccentGreen },
		{ id = "Fusion", text = "⚗️ Fuse", color = Theme.AccentPurple },
		{ id = "Daily", text = "🎁 Daily", color = Theme.AccentGold },
		{ id = "Trade", text = "🤝 Trade", color = Color3.fromRGB(235, 130, 50) },
	}

	for _, b in buttons do
		Theme.MakeButton(b.id .. "Btn", b.text, UDim2.fromOffset(120, 48), UDim2.fromScale(0, 0), b.color, sideMenu, function()
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
		"⚠️ WARDEN IS CHASING YOU! ⚠️",
		UDim2.new(0.55, 0, 0, 36),
		UDim2.new(0.5, 0, 0, 84),
		Theme.FontTitle,
		Theme.AccentRed,
		chaseEdge
	)
	chaseBanner.AnchorPoint = Vector2.new(0.5, 0)

	local function updateChaseState()
		chaseEdge.Visible = player:GetAttribute("BeingChased") == true
	end
	player:GetAttributeChangedSignal("BeingChased"):Connect(updateChaseState)
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
