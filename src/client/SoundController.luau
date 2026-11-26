--!strict
-- SoundController.luau (CLIENT)
-- Plays game SFX, loops the chase alarm continuously while BeingChased is true,
-- plays a triumphant success sound when entering the Safe Zone,
-- and controls the global Background Music (MainBGM in SoundService).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundData = require(Shared:WaitForChild("SoundData"))

local SoundController = {}

local sounds: { [string]: Sound } = {}
local chaseLoopRunning = false
local isMuted = false

local function getBgmSound(): Sound?
	local bgm = SoundService:WaitForChild("MainBGM", 6)
	if bgm and bgm:IsA("Sound") then
		return bgm
	end
	return nil
end

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
	local bgm = getBgmSound()
	if bgm then
		bgm.Volume = if isMuted then 0 else 0.45
		if not isMuted and not bgm.IsPlaying then
			bgm:Play()
		end
	end
	return not isMuted
end

function SoundController.IsMusicOn(): boolean
	return not isMuted
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

	-- Ensure BGM is playing on client join
	task.spawn(function()
		local bgm = getBgmSound()
		if bgm and not bgm.IsPlaying then
			bgm:Play()
		end
	end)
end

return SoundController
