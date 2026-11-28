--!strict
-- Hud.luau (CLIENT)
-- Left-side Money & Character Speed HUD, Right-side Menu Buttons, Chase Warning,
-- Chat system messages for Lucky/Rainbow Cage events, and clean Zone Entry Toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local PetData = require(Shared:WaitForChild("PetData"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local PamaloConfig = require(Shared:WaitForChild("PamaloConfig"))
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
		Rarities = "Recommended Speed: 900+",
		MinZ = -200,
		MaxZ = -50,
		Color = Color3.fromRGB(145, 235, 110),
	},
	{
		Id = "Zone2",
		Title = "🏪 ZONE 2 — PALENGKE & TIANGGE",
		Rarities = "Recommended Speed: 3.5K+",
		MinZ = -350,
		MaxZ = -200,
		Color = Color3.fromRGB(255, 195, 70),
	},
	{
		Id = "Zone3",
		Title = "🏛️ ZONE 3 — HACIENDA COMPOUND",
		Rarities = "Recommended Speed: 10K+",
		MinZ = -500,
		MaxZ = -350,
		Color = Color3.fromRGB(255, 140, 85),
	},
	{
		Id = "Zone4",
		Title = "🌴 ZONE 4 — BOHOL & PALAWAN GUBAT",
		Rarities = "Recommended Speed: 25K+",
		MinZ = -650,
		MaxZ = -500,
		Color = Color3.fromRGB(95, 235, 175),
	},
	{
		Id = "Zone5",
		Title = "🌋 ZONE 5 — BULKANG MAYON RIDGE",
		Rarities = "Recommended Speed: 60K+",
		MinZ = -800,
		MaxZ = -650,
		Color = Color3.fromRGB(255, 95, 65),
	},
	{
		Id = "Zone6",
		Title = "👑 ZONE 6 — INTRAMUROS ROYAL VAULT",
		Rarities = "Recommended Speed: 140K+",
		MinZ = -950,
		MaxZ = -800,
		Color = Color3.fromRGB(255, 215, 55),
	},
	{
		Id = "Zone7",
		Title = "🌸 ZONE 7 — MYTHICAL SANCTUARY",
		Rarities = "Recommended Speed: 320K+",
		MinZ = -1100,
		MaxZ = -950,
		Color = Color3.fromRGB(255, 140, 200),
	},
	{
		Id = "Zone8",
		Title = "🌌 ZONE 8 — CELESTIAL VAULT",
		Rarities = "Recommended Speed: 750K+",
		MinZ = -1255,
		MaxZ = -1100,
		Color = Color3.fromRGB(0, 245, 225),
	},
	{
		Id = "Zone9",
		Title = "⚔️ ZONE 9 — VALHALLA COLISEUM",
		Rarities = "Recommended Speed: 1.7M+",
		MinZ = -1400,
		MaxZ = -1255,
		Color = Color3.fromRGB(120, 215, 255),
	},
	{
		Id = "Zone10",
		Title = "🔱 ZONE 10 — OLYMPUS TITAN REALM",
		Rarities = "Recommended Speed: 3.8M+",
		MinZ = -1550,
		MaxZ = -1400,
		Color = Color3.fromRGB(255, 165, 45),
	},
	{
		Id = "Zone11",
		Title = "🐉 ZONE 11 — DRAGON EMPEROR CITADEL",
		Rarities = "Recommended Speed: 8.5M+",
		MinZ = -1700,
		MaxZ = -1550,
		Color = Color3.fromRGB(255, 55, 85),
	},
	{
		Id = "Zone12",
		Title = "👑 ZONE 12 — BATHALA INFINITY THRONE",
		Rarities = "Recommended Speed: 19M+",
		MinZ = -1850,
		MaxZ = -1700,
		Color = Color3.fromRGB(255, 225, 95),
	},
	{
		Id = "Zone13",
		Title = "❄️ ZONE 13 — FROSTBITE GLACIER KEEP",
		Rarities = "Recommended Speed: 42M+",
		MinZ = -2000,
		MaxZ = -1850,
		Color = Color3.fromRGB(120, 235, 255),
	},
	{
		Id = "Zone14",
		Title = "🏜️ ZONE 14 — PHARAOH GOLDEN PYRAMID",
		Rarities = "Recommended Speed: 95M+",
		MinZ = -2150,
		MaxZ = -2000,
		Color = Color3.fromRGB(255, 215, 55),
	},
	{
		Id = "Zone15",
		Title = "🌊 ZONE 15 — ATLANTIS ABYSSAL TRENCH",
		Rarities = "Recommended Speed: 210M+",
		MinZ = -2300,
		MaxZ = -2150,
		Color = Color3.fromRGB(0, 255, 215),
	},
	{
		Id = "Zone16",
		Title = "⚡ ZONE 16 — CYBER NEON METROPOLIS",
		Rarities = "Recommended Speed: 460M+",
		MinZ = -2450,
		MaxZ = -2300,
		Color = Color3.fromRGB(0, 245, 255),
	},
	{
		Id = "Zone17",
		Title = "🩸 ZONE 17 — UNDERWORLD HADES CORE",
		Rarities = "Recommended Speed: 1.0B+",
		MinZ = -2600,
		MaxZ = -2450,
		Color = Color3.fromRGB(255, 75, 45),
	},
	{
		Id = "Zone18",
		Title = "☄️ ZONE 18 — ASTRAL NEBULA DIMENSION",
		Rarities = "Recommended Speed: 2.2B+",
		MinZ = -2750,
		MaxZ = -2600,
		Color = Color3.fromRGB(235, 110, 255),
	},
	{
		Id = "Zone19",
		Title = "⏳ ZONE 19 — CHRONOS TIME CITADEL",
		Rarities = "Recommended Speed: 5.0B+",
		MinZ = -2900,
		MaxZ = -2750,
		Color = Color3.fromRGB(110, 255, 230),
	},
	{
		Id = "Zone20",
		Title = "✨ ZONE 20 — OMNIVERSE GODLY SANCTUARY",
		Rarities = "Recommended Speed: 12B+",
		MinZ = -3055,
		MaxZ = -2900,
		Color = Color3.fromRGB(255, 240, 140),
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

	-- LEFT-SIDE STATS HUD (Anchored to Top-Left so the Bottom-Left is 100% clear for the Mobile Thumbstick!)
	local leftStats = Instance.new("Frame")
	leftStats.Name = "LeftStatsHud"
	leftStats.Size = UDim2.fromOffset(172, 240)
	leftStats.Position = UDim2.new(0, 12, 0, 8)
	leftStats.AnchorPoint = Vector2.new(0, 0)
	leftStats.BackgroundTransparency = 1
	leftStats.Parent = screenGui

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 6)
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftStats

	Theme.BindResponsiveScale(leftStats, 0.74, function(isCompact: boolean)
		leftStats.Position = if isCompact then UDim2.new(0, 8, 0, 6) else UDim2.new(0, 14, 0, 14)
	end)

	-- 1) Total Money Pill on the Left
	local moneyCard = Theme.MakeFrame("MoneyCard", UDim2.fromOffset(168, 42), UDim2.fromScale(0, 0), Theme.BgDark, 12, leftStats)
	moneyCard.LayoutOrder = 1
	Theme.AddStroke(moneyCard, Theme.AccentGold, 2)
	local moneyLabel = Theme.MakeLabel("MoneyLabel", "💵 $0", UDim2.fromScale(0.90, 0.74), UDim2.fromScale(0.05, 0.13), Theme.FontTitle, Theme.AccentGold, moneyCard)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- 2) Character WalkSpeed Pill on the Left
	local speedCard = Theme.MakeFrame("SpeedCard", UDim2.fromOffset(168, 42), UDim2.fromScale(0, 0), Theme.BgDark, 12, leftStats)
	speedCard.LayoutOrder = 2
	Theme.AddStroke(speedCard, Theme.AccentBlue, 2)
	local speedLabel = Theme.MakeLabel("SpeedLabel", "⚡ Speed: 16.0", UDim2.fromScale(0.90, 0.74), UDim2.fromScale(0.05, 0.13), Theme.FontTitle, Color3.fromRGB(120, 215, 255), speedCard)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Music Toggle & Slow Mode Button Row
	local utilityRow = Instance.new("Frame")
	utilityRow.Name = "UtilityRow"
	utilityRow.Size = UDim2.fromOffset(168, 32)
	utilityRow.BackgroundTransparency = 1
	utilityRow.LayoutOrder = 3
	utilityRow.Parent = leftStats

	-- 3) Slow Mode Toggle Button (Like Steal a Pet!)
	local slowModeEvent = Remotes.GetEvent("ToggleSlowMode")
	local slowBtn = Theme.MakeButton("SlowModeBtn", "🐢 Slow: OFF", UDim2.fromOffset(78, 32), UDim2.fromScale(0, 0), Theme.BgCard, utilityRow, function()
		slowModeEvent:FireServer()
	end)
	Theme.AddStroke(slowBtn, Theme.BgHeader, 2)
	local function updateSlowBtn()
		local isSlow = player:GetAttribute("SlowMode") == true
		slowBtn.Text = if isSlow then "🐢 Slow" else "🐢 Fast"
		slowBtn.BackgroundColor3 = if isSlow then Theme.AccentGreen else Theme.BgCard
	end
	player:GetAttributeChangedSignal("SlowMode"):Connect(updateSlowBtn)
	updateSlowBtn()

	-- 3b) Hide Pet Labels Toggle Button (Prevents giant pet names & floating $/s popups from cluttering the screen!)
	local labelsHidden = false
	local labelToggleBtn: TextButton
	labelToggleBtn = Theme.MakeButton("HideLabelsBtn", "🏷️ ON", UDim2.fromOffset(48, 32), UDim2.fromOffset(82, 0), Theme.BgCard, utilityRow, function()
		labelsHidden = not labelsHidden
		player:SetAttribute("HidePetLabels", labelsHidden)
		labelToggleBtn.Text = if labelsHidden then "🏷️ OFF" else "🏷️ ON"
		labelToggleBtn.BackgroundColor3 = if labelsHidden then Color3.fromRGB(55, 30, 30) else Theme.BgCard
	end)
	Theme.AddStroke(labelToggleBtn, Theme.BgHeader, 2)

	-- 3c) BGM Music Mute/Unmute Button (Grow a Garden BGM)
	local musicBtn = Theme.MakeButton("MusicBtn", "🎵", UDim2.fromOffset(34, 32), UDim2.fromOffset(134, 0), Theme.BgCard, utilityRow, function()
		local isOn = SoundController.ToggleMusic()
		local mBtn = utilityRow:FindFirstChild("MusicBtn")
		if mBtn and mBtn:IsA("TextButton") then
			mBtn.Text = if isOn then "🎵" else "🔇"
			mBtn.BackgroundColor3 = if isOn then Theme.BgCard else Color3.fromRGB(55, 30, 30)
		end
	end)
	Theme.AddStroke(musicBtn, Theme.BgHeader, 2)

	-- 4) Live Fiesta Event Status & Active Fiesta Boost Pills on the Left HUD!
	local fiestaBanner = Theme.MakeFrame("FiestaBanner", UDim2.fromOffset(168, 28), UDim2.fromScale(0, 0), Color3.fromRGB(38, 26, 54), 10, leftStats)
	fiestaBanner.LayoutOrder = 4
	Theme.AddStroke(fiestaBanner, Theme.AccentGold, 1.5)
	local fiestaBannerLbl = Theme.MakeLabel("Text", "🎪 Fiesta Plaza Ready!", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Theme.AccentGold, fiestaBanner)

	local speedBoostPill = Theme.MakeFrame("SpeedBoostPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(18, 48, 68), 8, leftStats)
	speedBoostPill.LayoutOrder = 5
	speedBoostPill.Visible = false
	Theme.AddStroke(speedBoostPill, Color3.fromRGB(80, 235, 255), 1.5)
	local speedBoostLbl = Theme.MakeLabel("Text", "⚡ 2x Treadmill (3:00)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Color3.fromRGB(80, 235, 255), speedBoostPill)

	local moneyBoostPill = Theme.MakeFrame("MoneyBoostPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(18, 56, 32), 8, leftStats)
	moneyBoostPill.LayoutOrder = 6
	moneyBoostPill.Visible = false
	Theme.AddStroke(moneyBoostPill, Theme.AccentGreen, 1.5)
	local moneyBoostLbl = Theme.MakeLabel("Text", "💰 2x Pet Cash (3:00)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Theme.AccentGreen, moneyBoostPill)

	local luckBoostPill = Theme.MakeFrame("LuckBoostPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(58, 42, 16), 8, leftStats)
	luckBoostPill.LayoutOrder = 7
	luckBoostPill.Visible = false
	Theme.AddStroke(luckBoostPill, Theme.AccentGold, 1.5)
	local luckBoostLbl = Theme.MakeLabel("Text", "🍀 2x Luck & Unlock (3:00)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Theme.AccentGold, luckBoostPill)

	local boodleBoostPill = Theme.MakeFrame("BoodleBoostPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(22, 54, 28), 8, leftStats)
	boodleBoostPill.LayoutOrder = 8
	boodleBoostPill.Visible = false
	Theme.AddStroke(boodleBoostPill, Color3.fromRGB(125, 255, 115), 1.5)
	local boodleBoostLbl = Theme.MakeLabel("Text", "🍽️ Busog & Swerte (10:00)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Color3.fromRGB(125, 255, 115), boodleBoostPill)

	local barkadaPill = Theme.MakeFrame("BarkadaComboPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(52, 38, 16), 8, leftStats)
	barkadaPill.LayoutOrder = 9
	barkadaPill.Visible = false
	Theme.AddStroke(barkadaPill, Theme.AccentGold, 1.5)
	local barkadaLbl = Theme.MakeLabel("Text", "🤝 Bukid Trio (+25% $/s)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Theme.AccentGold, barkadaPill)

	local streetFoodPill = Theme.MakeFrame("StreetFoodBusogPill", UDim2.fromOffset(168, 24), UDim2.fromScale(0, 0), Color3.fromRGB(58, 28, 36), 8, leftStats)
	streetFoodPill.LayoutOrder = 10
	streetFoodPill.Visible = false
	Theme.AddStroke(streetFoodPill, Color3.fromRGB(255, 165, 85), 1.5)
	local streetFoodLbl = Theme.MakeLabel("Text", "🍡 Busog +20% $/s (10:00)", UDim2.fromScale(0.92, 0.86), UDim2.fromScale(0.04, 0.07), Theme.FontTitle, Color3.fromRGB(255, 185, 95), streetFoodPill)

	local function formatTimer(sec: number): string
		local s = math.max(0, math.ceil(sec))
		return string.format("%d:%02d", s // 60, s % 60)
	end

	local function refreshFiestaHud()
		local evTitle = workspace:GetAttribute("FiestaEventTitle")
		if typeof(evTitle) == "string" and evTitle ~= "" then
			fiestaBannerLbl.Text = evTitle
		end

		local now = workspace:GetServerTimeNow()
		local spdUntil = player:GetAttribute("FiestaSpeedBoostUntil")
		if typeof(spdUntil) == "number" and spdUntil > now then
			speedBoostPill.Visible = true
			speedBoostLbl.Text = `⚡ 2x Treadmill ({formatTimer(spdUntil - now)})`
		else
			speedBoostPill.Visible = false
		end

		local monUntil = player:GetAttribute("FiestaMoneyBoostUntil")
		if typeof(monUntil) == "number" and monUntil > now then
			moneyBoostPill.Visible = true
			moneyBoostLbl.Text = `💰 2x Pet Cash ({formatTimer(monUntil - now)})`
		else
			moneyBoostPill.Visible = false
		end

		local lckUntil = player:GetAttribute("FiestaLuckBoostUntil")
		if typeof(lckUntil) == "number" and lckUntil > now then
			luckBoostPill.Visible = true
			luckBoostLbl.Text = `🍀 2x Luck & Cage ({formatTimer(lckUntil - now)})`
		else
			luckBoostPill.Visible = false
		end

		local boodleUntil = player:GetAttribute("BoodleBuffUntil")
		if typeof(boodleUntil) == "number" and boodleUntil > now then
			boodleBoostPill.Visible = true
			boodleBoostLbl.Text = `🍽️ Busog & Swerte ({formatTimer(boodleUntil - now)})`
		else
			boodleBoostPill.Visible = false
		end

		local hasBarkada = player:GetAttribute("BarkadaComboActive") == true
		local barkadaTitle = player:GetAttribute("BarkadaComboTitle")
		if hasBarkada and typeof(barkadaTitle) == "string" and barkadaTitle ~= "" then
			barkadaPill.Visible = true
			barkadaLbl.Text = `🤝 {barkadaTitle} (+25% $/s)`
		else
			barkadaPill.Visible = false
		end

		local petBusogUntil = player:GetAttribute("PetBusogUntil")
		if typeof(petBusogUntil) == "number" and petBusogUntil > now then
			streetFoodPill.Visible = true
			streetFoodLbl.Text = `🍡 Busog +20% $/s ({formatTimer(petBusogUntil - now)})`
		else
			streetFoodPill.Visible = false
		end
	end

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
		TweenService:Create(moneyCard, TweenInfo.new(0.07), { Size = UDim2.fromOffset(174, 45) }):Play()
		task.delay(0.07, function()
			if moneyCard.Parent then
				TweenService:Create(moneyCard, TweenInfo.new(0.09), { Size = UDim2.fromOffset(168, 42) }):Play()
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
	local cagesOpenPos = UDim2.new(1, -10, 0, 8)
	local cagesClosedPos = UDim2.new(1, 260, 0, 8)

	local cagesDrawer = Theme.MakeFrame(
		"UnlockingCagesDrawer",
		UDim2.fromOffset(236, 214),
		cagesClosedPos,
		Color3.fromRGB(28, 30, 38),
		10,
		screenGui
	)
	cagesDrawer.AnchorPoint = Vector2.new(1, 0)
	cagesDrawer.Visible = false
	cagesDrawer.ZIndex = 18
	Theme.AddStroke(cagesDrawer, Color3.fromRGB(15, 16, 22), 3)
	Theme.BindResponsiveScale(cagesDrawer, 0.78)

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
			local row = Theme.MakeFrame(
				item.Id,
				UDim2.new(1, -4, 0, 46),
				UDim2.fromScale(0, 0),
				Color3.fromRGB(42, 46, 58),
				8,
				cagesScroll
			)
			row.LayoutOrder = idx
			Theme.AddStroke(row, Theme.AccentGold, 1.5)

			local nameLbl = Theme.MakeLabel(
				"CageName",
				"📦 Mystery Cage ???",
				UDim2.new(0.58, 0, 1, 0),
				UDim2.fromOffset(10, 0),
				Theme.FontTitle,
				Color3.fromRGB(255, 225, 95),
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

	-- RIGHT-SIDE MENU BUTTONS (Anchored to Top-Right so it NEVER overlaps the Mobile Jump Button!)
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.Size = UDim2.fromOffset(102, 236)
	sideMenu.Position = UDim2.new(1, -10, 0, 8)
	sideMenu.AnchorPoint = Vector2.new(1, 0)
	sideMenu.BackgroundTransparency = 1
	sideMenu.Parent = screenGui
	sideMenuFrame = sideMenu

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Parent = sideMenu

	Theme.BindResponsiveScale(sideMenu, 0.72, function(isCompact: boolean)
		sideMenu.Position = if isCompact then UDim2.new(1, -8, 0, 6) else UDim2.new(1, -12, 0, 14)
	end)

	Theme.MakeButton("CagesBtn", "📦 Cages", UDim2.fromOffset(98, 34), UDim2.fromScale(0, 0), Color3.fromRGB(235, 95, 75), sideMenu, function()
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
		Theme.MakeButton(b.id .. "Btn", b.text, UDim2.fromOffset(98, 34), UDim2.fromScale(0, 0), b.color, sideMenu, function()
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

	-- "📦 CLICK / TAP TO PLACE CAGE" + "🗑️ DROP CAGE (G)" BUTTONS WHILE CARRYING A CAGE!
	-- 3D VIEWPORT BOTTOM HOTBAR (Replaces plain-text CoreGui Backpack with 3D Pamalo & 3D Pet Models!)
	task.spawn(function()
		for _ = 1, 15 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				break
			end
			task.wait(0.2)
		end
	end)

	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "ViewportHotbar"
	hotbarFrame.Size = UDim2.fromOffset(530, 64)
	hotbarFrame.Position = UDim2.new(0.5, 0, 1, -6)
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = screenGui
	Theme.BindResponsiveScale(hotbarFrame, 0.72, function(isCompact: boolean)
		hotbarFrame.Position = if isCompact then UDim2.new(0.5, 0, 1, -3) else UDim2.new(0.5, 0, 1, -8)
	end)

	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarLayout.Padding = UDim.new(0, 6)
	hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarLayout.Parent = hotbarFrame

	local currentHotbarTools: { Tool } = {}
	local lastSignature = ""

	local function toggleEquipTool(tool: Tool)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		SoundController.Play("UiClick")
		if tool.Parent == character then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end

	local function refreshViewportHotbar()
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local pamaloList: { Tool } = {}
		local petToolList: { Tool } = {}

		for _, container in { character, backpack } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") then
						if child:GetAttribute("IsPamalo") == true then
							table.insert(pamaloList, child)
						elseif child:GetAttribute("IsPetTool") == true then
							table.insert(petToolList, child)
						end
					end
				end
			end
		end

		table.sort(petToolList, function(a, b)
			return tostring(a:GetAttribute("PetUid") or a.Name) < tostring(b:GetAttribute("PetUid") or b.Name)
		end)

		local ordered: { Tool } = {}
		for _, t in pamaloList do
			table.insert(ordered, t)
		end
		for _, t in petToolList do
			if #ordered < 8 then
				table.insert(ordered, t)
			end
		end

		local sigParts = {}
		for _, t in ordered do
			local eq = if character and t.Parent == character then "1" else "0"
			table.insert(sigParts, `{t.Name}:{t:GetAttribute("PetUid") or t:GetAttribute("PamaloId") or ""}:{t:GetAttribute("PetId") or ""}:{eq}`)
		end
		local sig = table.concat(sigParts, "|")
		if sig == lastSignature then
			return
		end

		for _, child in hotbarFrame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		for idx, tool in ordered do
			local isEquipped = (character ~= nil and tool.Parent == character)
			local isPamalo = tool:GetAttribute("IsPamalo") == true
			local pamaloId = tostring(tool:GetAttribute("PamaloId") or "tsinelas_spartan")
			local petId = tostring(tool:GetAttribute("PetId") or "chicken")
			local mutRaw = tool:GetAttribute("Mutation")
			local mutation: string? = if typeof(mutRaw) == "string" and mutRaw ~= "" then mutRaw else nil
			local petInfo = if not isPamalo then PetData.Get(petId) else nil
			local mutInfo = MutationData.Get(mutation)
			local rarityColor = if petInfo then Rarities.Get(petInfo.Rarity).Color else Theme.AccentGold
			local borderColor = if isEquipped
				then Color3.fromRGB(90, 225, 255)
				elseif mutInfo then mutInfo.Color
				else rarityColor

			local slotBtn = Instance.new("TextButton")
			slotBtn.Name = `Slot_{idx}`
			slotBtn.LayoutOrder = idx
			slotBtn.Size = UDim2.fromOffset(64, 64)
			slotBtn.BackgroundColor3 = if isEquipped then Color3.fromRGB(70, 120, 180) else Color3.fromRGB(20, 24, 32)
			-- Steal-a-Pet style transparent/frameless 3D hotbar slots (no heavy black box background!)
			slotBtn.BackgroundTransparency = if isEquipped then 0.65 else 0.88
			slotBtn.BorderSizePixel = 0
			slotBtn.Text = ""
			Theme.AddCorner(slotBtn, 10)
			if isEquipped then
				Theme.AddStroke(slotBtn, borderColor, 2.5)
			end
			slotBtn.Parent = hotbarFrame

			if isPamalo then
				PamaloConfig.MountViewport(slotBtn, pamaloId, UDim2.fromScale(1, 0.86), UDim2.fromScale(0, 0))
			else
				PetVisuals.MountViewport(slotBtn, petId, mutation, UDim2.fromScale(1, 0.86), UDim2.fromScale(0, 0))
			end

			local numLbl = Theme.MakeLabel("KeyNum", tostring(idx), UDim2.fromOffset(18, 16), UDim2.fromOffset(3, 1), Theme.FontTitle, Color3.fromRGB(255, 255, 255), slotBtn)
			numLbl.TextXAlignment = Enum.TextXAlignment.Left

			if mutInfo then
				local mutBadge = Theme.MakeLabel("Mut", mutInfo.Name, UDim2.new(0.94, 0, 0, 13), UDim2.fromOffset(2, 1), Theme.FontTitle, mutInfo.Color, slotBtn)
				mutBadge.TextXAlignment = Enum.TextXAlignment.Right
			end

			local shortName = if isPamalo
				then (if PamaloConfig.Get(pamaloId) then (PamaloConfig.Get(pamaloId) :: PamaloConfig.PamaloInfo).DisplayName else tool.Name)
				else (if petInfo then petInfo.DisplayName else tool.Name)
			Theme.MakeLabel("Caption", shortName, UDim2.new(0.96, 0, 0, 15), UDim2.new(0.02, 0, 1, -15), Theme.FontTitle, borderColor, slotBtn)

			slotBtn.Activated:Connect(function()
				toggleEquipTool(tool)
			end)
		end

		lastSignature = sig
		currentHotbarTools = ordered
	end

	local KEY_MAP: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
	}

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local slotIdx = KEY_MAP[input.KeyCode]
		if slotIdx and currentHotbarTools[slotIdx] then
			toggleEquipTool(currentHotbarTools[slotIdx])
		end
	end)

	-- "📦 CLICK / TAP TO PLACE CAGE" + "🗑️ DROP CAGE (G)" BUTTONS WHILE CARRYING A CAGE!
	local placeCageEvent = Remotes.GetEvent("PlaceCageOnPlot")
	local dropCageEvent = Remotes.GetEvent("DropCarriedCage")

	local cageActionBar = Instance.new("Frame")
	cageActionBar.Name = "CageActionBar"
	cageActionBar.Size = UDim2.fromOffset(410, 42)
	cageActionBar.Position = UDim2.new(0.5, 0, 1, -80)
	cageActionBar.AnchorPoint = Vector2.new(0.5, 1)
	cageActionBar.BackgroundTransparency = 1
	cageActionBar.Parent = screenGui
	Theme.BindResponsiveScale(cageActionBar, 0.75, function(isCompact: boolean)
		cageActionBar.Position = if isCompact then UDim2.new(0.5, 0, 1, -56) else UDim2.new(0.5, 0, 1, -82)
	end)

	local placeCageBtn = Theme.MakeButton(
		"PlaceCageBtn",
		"📦 Tap / Click Plot to Place Cage",
		UDim2.fromOffset(235, 42),
		UDim2.new(0.5, -203, 0, 0),
		Theme.AccentGreen,
		cageActionBar,
		function()
			placeCageEvent:FireServer()
		end
	)
	placeCageBtn.Visible = false
	Theme.AddStroke(placeCageBtn, Color3.new(1, 1, 1), 2)

	local dropCageBtn = Theme.MakeButton(
		"DropCageBtn",
		"🗑️ Drop Cage (G)",
		UDim2.fromOffset(165, 42),
		UDim2.new(0.5, -82, 0, 0),
		Theme.AccentRed,
		cageActionBar,
		function()
			dropCageEvent:FireServer()
		end
	)
	dropCageBtn.Visible = false
	Theme.AddStroke(dropCageBtn, Color3.new(1, 1, 1), 2)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G and player:GetAttribute("IsCarryingCage") == true then
			dropCageEvent:FireServer()
		end
	end)

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
		local now = os.clock()
		refreshSpeed()
		refreshFiestaHud()
		refreshViewportHotbar()
		local isCarrying = player:GetAttribute("IsCarryingCage") == true
		local nearOwnPlot = isCarrying and isStandingNearOwnPlot()
		placeCageBtn.Visible = nearOwnPlot
		dropCageBtn.Visible = isCarrying
		dropCageBtn.Position = if nearOwnPlot
			then UDim2.new(0.5, 38, 0, 0)
			else UDim2.new(0.5, -82, 0, 0)

		if chaseEdge.Visible then
			local pulse = 0.25 + 0.55 * math.abs(math.sin(now * 5))
			edgeStroke.Transparency = pulse
		end

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
