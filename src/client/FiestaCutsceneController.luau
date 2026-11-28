--!strict
-- FiestaCutsceneController.luau (CLIENT)
-- Runs a 4-second Scriptable camera sequence (TweenService) whenever a Fiesta Plaza event starts
-- or a player joins an active Fiesta session:
--   * Smoothly pans from the player's character toward the Fiesta Plaza center
--   * Lowers procedural colorful banderitas into place & bursts confetti particles
--   * Plays Fiesta fanfare audio & pops a bold comic title banner
--   * Includes a Theme-styled "[Skip ⏭️]" button in the corner that immediately restores Enum.CameraType.Custom

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventData = require(Shared:WaitForChild("EventData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local FiestaCutsceneController = {}

local activeToken = 0
local activeTweens: { Tween } = {}
local cutsceneFolder: Folder? = nil

local bannerFrame: Frame? = nil
local bannerTitleLbl: TextLabel? = nil
local bannerSubLbl: TextLabel? = nil
local skipBtn: TextButton? = nil

local BANDERITA_COLORS = {
	Color3.fromRGB(255, 65, 65),
	Color3.fromRGB(255, 215, 45),
	Color3.fromRGB(55, 205, 255),
	Color3.fromRGB(80, 240, 115),
	Color3.fromRGB(255, 95, 215),
}

local function cleanupActiveCutscene()
	activeToken += 1
	for _, tw in activeTweens do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(activeTweens)

	if cutsceneFolder and cutsceneFolder.Parent then
		cutsceneFolder:Destroy()
	end
	cutsceneFolder = nil

	if bannerFrame then
		bannerFrame.Visible = false
	end
	if skipBtn then
		skipBtn.Visible = false
	end

	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local player = Players.LocalPlayer
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end

local function spawnLoweringBanderitasAndConfetti(centerPos: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = "FiestaCutsceneProps"
	folder.Parent = workspace

	-- Procedural Banderitas strings lowering from Y+21 down to Y+13.5 across the plaza
	local ropeCount = 10
	for i = 1, ropeCount do
		local t = (i - 1) / (ropeCount - 1)
		local x = -13.5 + t * 27.0
		for _, zSide in { -10, 0, 10 } do
			local startPos = centerPos + Vector3.new(x, 20.5, zSide)
			local targetPos = centerPos + Vector3.new(x, 12.8 - math.sin(t * math.pi) * 1.4, zSide)

			local flag = Instance.new("Part")
			flag.Name = `CutsceneBanderita_{i}_{zSide}`
			flag.Size = Vector3.new(1.8, 1.15, 0.22)
			flag.Position = startPos
			flag.Anchored = true
			flag.CanCollide = false
			flag.CanTouch = false
			flag.CanQuery = false
			flag.Color = BANDERITA_COLORS[((i + math.abs(zSide)) % #BANDERITA_COLORS) + 1]
			flag.Material = Enum.Material.Neon
			flag.Parent = folder

			local tw = TweenService:Create(
				flag,
				TweenInfo.new(1.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
				{ Position = targetPos }
			)
			table.insert(activeTweens, tw)
			tw:Play()
		end
	end

	-- Central Confetti Burst Emitter
	local confettiHost = Instance.new("Part")
	confettiHost.Name = "ConfettiHost"
	confettiHost.Size = Vector3.new(1, 1, 1)
	confettiHost.Position = centerPos + Vector3.new(0, 9.5, 0)
	confettiHost.Anchored = true
	confettiHost.Transparency = 1
	confettiHost.CanCollide = false
	confettiHost.CanTouch = false
	confettiHost.CanQuery = false
	confettiHost.Parent = folder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 65, 85)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 45)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 240, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(65, 210, 255)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(245, 90, 225)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(1.8, 2.8)
	emitter.Speed = NumberRange.new(14, 28)
	emitter.SpreadAngle = Vector2.new(180, 120)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Rate = 45
	emitter.LightEmission = 0.7
	emitter.Parent = confettiHost
	emitter:Emit(65)

	return folder
end

local function playCutscene(bannerTitle: string, bannerSubtitle: string, centerPos: Vector3)
	cleanupActiveCutscene()
	activeToken += 1
	local myToken = activeToken

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	local duration = EventData.Fiesta.CutsceneDurationSeconds or 4.0
	SoundController.Play("FiestaFanfare")
	cutsceneFolder = spawnLoweringBanderitasAndConfetti(centerPos)

	if bannerFrame and bannerTitleLbl and bannerSubLbl and skipBtn then
		bannerTitleLbl.Text = `🎉 {bannerTitle} 🎉`
		bannerSubLbl.Text = bannerSubtitle
		bannerFrame.Visible = true
		skipBtn.Visible = true

		local uiScale = bannerFrame:FindFirstChildOfClass("UIScale")
		if uiScale then
			uiScale.Scale = 0.65
			local popTw = TweenService:Create(
				uiScale,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = if Theme.IsCompactScreen() then 0.8 else 1.0 }
			)
			table.insert(activeTweens, popTw)
			popTw:Play()
		end
	end

	local player = Players.LocalPlayer
	local charRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local startCF = if charRoot and charRoot:IsA("BasePart")
		then CFrame.lookAt(charRoot.Position + Vector3.new(0, 8.5, -14), centerPos + Vector3.new(0, 4, 0))
		else cam.CFrame

	local midOverviewCF = CFrame.lookAt(
		centerPos + Vector3.new(-22, 16.5, -24),
		centerPos + Vector3.new(0, 4.2, 0)
	)
	local finalCloseupCF = CFrame.lookAt(
		centerPos + Vector3.new(16, 11.5, -18),
		centerPos + Vector3.new(0, 4.5, 0)
	)

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = startCF

	local panToPlaza = TweenService:Create(
		cam,
		TweenInfo.new(duration * 0.52, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ CFrame = midOverviewCF }
	)
	table.insert(activeTweens, panToPlaza)
	panToPlaza:Play()

	task.delay(duration * 0.52, function()
		if activeToken ~= myToken then
			return
		end
		local orbitTw = TweenService:Create(
			cam,
			TweenInfo.new(duration * 0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = finalCloseupCF }
		)
		table.insert(activeTweens, orbitTw)
		orbitTw:Play()
	end)

	task.delay(duration, function()
		if activeToken == myToken then
			cleanupActiveCutscene()
		end
	end)
end

function FiestaCutsceneController.Init(screenGui: ScreenGui)
	-- Bold Comic Fiesta Cutscene Title Banner at Top-Center
	local banner = Theme.MakeFrame(
		"FiestaCutsceneBanner",
		UDim2.fromOffset(480, 74),
		UDim2.new(0.5, 0, 0, 56),
		Color3.fromRGB(36, 22, 54),
		14,
		screenGui
	)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Visible = false
	banner.ZIndex = 30
	Theme.AddStroke(banner, Theme.AccentGold, 3)

	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner

	local title = Theme.MakeLabel(
		"Title",
		"🎉 FIESTA NA! - HAMPAS PALAYOK RUSH! 🎉",
		UDim2.fromScale(0.94, 0.52),
		UDim2.fromScale(0.03, 0.08),
		Theme.FontTitle,
		Theme.AccentGold,
		banner
	)
	local sub = Theme.MakeLabel(
		"Subtitle",
		"Swing your Pamalo to smash the giant Palayok!",
		UDim2.fromScale(0.92, 0.34),
		UDim2.fromScale(0.04, 0.60),
		Theme.FontBody,
		Theme.TextPrimary,
		banner
	)

	-- Clean Theme-styled [Skip] button in the corner that immediately restores Enum.CameraType.Custom
	local skip = Theme.MakeButton(
		"SkipFiestaCutsceneBtn",
		"Skip ⏭️",
		UDim2.fromOffset(116, 40),
		UDim2.new(1, -18, 1, -18),
		Theme.AccentRed,
		screenGui,
		function()
			cleanupActiveCutscene()
		end
	)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Visible = false
	skip.ZIndex = 32
	Theme.AddStroke(skip, Color3.new(1, 1, 1), 2)
	Theme.BindResponsiveScale(skip, 0.8, function(isCompact: boolean)
		skip.Position = if isCompact then UDim2.new(1, -14, 0, 52) else UDim2.new(1, -18, 1, -18)
		skip.AnchorPoint = if isCompact then Vector2.new(1, 0) else Vector2.new(1, 1)
	end)

	bannerFrame = banner
	bannerTitleLbl = title
	bannerSubLbl = sub
	skipBtn = skip

	Remotes.GetEvent("FiestaCutscene").OnClientEvent:Connect(
		function(_mode: any, _eventId: any, bannerTitle: any, bannerSub: any, centerPos: any)
			if typeof(bannerTitle) ~= "string" or typeof(centerPos) ~= "Vector3" then
				return
			end
			local subStr = if typeof(bannerSub) == "string" then bannerSub else ""
			playCutscene(bannerTitle, subStr, centerPos)
		end
	)
end

return FiestaCutsceneController
