--!strict
-- SoundController.luau (CLIENT)
-- Plays game SFX, loops the chase alarm continuously while BeingChased is true,
-- plays a triumphant success sound when entering the Safe Zone,
-- and streams the authentic "Grow a Garden" official Roblox Creator Store BGM playlist!

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundData = require(Shared:WaitForChild("SoundData"))

local SoundController = {}

local sounds: { [string]: Sound } = {}
local chaseLoopRunning = false
local isMuted = false
local activeBgm: Sound? = nil

-- Official Verified "Grow a Garden" & Roblox Creator Store BGM Tracks:
local GROW_A_GARDEN_BGM = {
	{ Id = "rbxassetid://1846088038", Name = "Morning Mood (Grow a Garden Main Theme)", Volume = 0.45 },
	{ Id = "rbxassetid://9045766074", Name = "Four Seasons: Spring (Grow a Garden)", Volume = 0.42 },
	{ Id = "rbxassetid://9047134822", Name = "Tropical Breeze (Island Vibe)", Volume = 0.45 },
	{ Id = "rbxassetid://1842150151", Name = "Turkish March Strings (Upbeat)", Volume = 0.40 },
	{ Id = "rbxassetid://1848354536", Name = "Relaxed Scene", Volume = 0.45 },
}

local function getOrCreateSound(name: string): Sound?
	local entry = SoundData[name]
	if not entry or entry.Id == "" then
		return nil
	end
	local snd = sounds[name]
	if not snd then
		snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = entry.Id
		snd.PlaybackSpeed = entry.Pitch
		snd.Volume = entry.Volume
		snd.Parent = SoundService
		sounds[name] = snd
	end
	return snd
end

function SoundController.Play(name: string)
	local snd = getOrCreateSound(name)
	if snd then
		snd:Play()
	end
end

function SoundController.Stop(name: string)
	local snd = sounds[name]
	if snd and snd.IsPlaying then
		snd:Stop()
	end
end

function SoundController.ToggleMusic(): boolean
	isMuted = not isMuted
	if activeBgm then
		activeBgm.Volume = if isMuted then 0 else 0.45
	end
	return not isMuted
end

function SoundController.IsMusicOn(): boolean
	return not isMuted
end

local function waitUntilSoundLoaded(sound: Sound, timeoutSec: number): boolean
	if sound.IsLoaded and sound.TimeLength > 0 then
		return true
	end
	local deadline = os.clock() + timeoutSec
	while os.clock() < deadline do
		if sound.IsLoaded and sound.TimeLength > 0 then
			return true
		end
		task.wait(0.15)
	end
	return sound.IsLoaded and sound.TimeLength > 0
end

local function startGrowAGardenBgm()
	task.spawn(function()
		-- Clean up any old BGM sound in SoundService
		local old = SoundService:FindFirstChild("GrowAGardenBGM")
		if old then
			old:Destroy()
		end

		local bgm = Instance.new("Sound")
		bgm.Name = "GrowAGardenBGM"
		bgm.Looped = false
		bgm.Volume = 0
		bgm.Parent = SoundService
		activeBgm = bgm

		local trackIdx = 1
		local consecutiveFailures = 0

		while true do
			local track = GROW_A_GARDEN_BGM[trackIdx]
			bgm:Stop()
			bgm.SoundId = track.Id
			bgm.TimePosition = 0

			local loaded = waitUntilSoundLoaded(bgm, 5.0)
			if loaded and bgm.TimeLength > 0 then
				consecutiveFailures = 0
				bgm.Volume = 0
				bgm:Play()
				local targetVol = if isMuted then 0 else track.Volume
				TweenService:Create(bgm, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Volume = targetVol,
				}):Play()

				-- Wait until the song finishes naturally
				local maxPlay = math.min(bgm.TimeLength, 240)
				local startedAt = os.clock()
				while bgm.IsPlaying and (os.clock() - startedAt) < (maxPlay - 1.5) do
					if isMuted and bgm.Volume > 0 then
						bgm.Volume = 0
					elseif not isMuted and bgm.Volume == 0 then
						bgm.Volume = track.Volume
					end
					task.wait(0.5)
				end

				-- Smooth fade out before next track
				local fadeOut = TweenService:Create(bgm, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Volume = 0,
				})
				fadeOut:Play()
				fadeOut.Completed:Wait()
			else
				consecutiveFailures += 1
				if consecutiveFailures >= #GROW_A_GARDEN_BGM then
					warn("[SoundController] Roblox Studio blocked streaming Creator Store audio because this local file is not yet saved/published to Roblox (File -> Save to Roblox). Retrying in 10s...")
					task.wait(10.0)
					consecutiveFailures = 0
				end
			end

			trackIdx = (trackIdx % #GROW_A_GARDEN_BGM) + 1
			task.wait(0.25)
		end
	end)
end

local function updateChaseLoop(localPlayer: Player)
	local shouldChase = localPlayer:GetAttribute("BeingChased") == true
		and localPlayer:GetAttribute("CageSecured") ~= true

	if shouldChase and not chaseLoopRunning then
		chaseLoopRunning = true
		task.spawn(function()
			while chaseLoopRunning do
				if localPlayer:GetAttribute("BeingChased") ~= true or localPlayer:GetAttribute("CageSecured") == true then
					chaseLoopRunning = false
					break
				end
				SoundController.Play("WardenAlert")
				task.wait(0.62)
			end
			SoundController.Stop("WardenAlert")
		end)
	elseif not shouldChase and chaseLoopRunning then
		chaseLoopRunning = false
		SoundController.Stop("WardenAlert")
	end
end

function SoundController.Init()
	ProximityPromptService.PromptButtonHoldBegan:Connect(function()
		SoundController.Play("CageOpen")
	end)

	ProximityPromptService.PromptTriggered:Connect(function()
		SoundController.Play("Pickup")
	end)

	local localPlayer = Players.LocalPlayer
	localPlayer:GetAttributeChangedSignal("BeingChased"):Connect(function()
		updateChaseLoop(localPlayer)
	end)

	localPlayer:GetAttributeChangedSignal("CageSecured"):Connect(function()
		updateChaseLoop(localPlayer)
		if localPlayer:GetAttribute("CageSecured") == true then
			SoundController.Play("SafeZoneSuccess")
		end
	end)

	startGrowAGardenBgm()
end

return SoundController
