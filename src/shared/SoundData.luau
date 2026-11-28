--!strict
-- SoundData.luau
-- Built-in Roblox client sounds (rbxasset://sounds/...) with custom pitch & volume.

export type SoundEntry = {
	Id: string,
	Pitch: number,
	Volume: number,
}

local SoundData: { [string]: SoundEntry } = {
	CageOpen = { Id = "rbxasset://sounds/switch3.wav", Pitch = 0.9, Volume = 0.6 },
	Pickup = { Id = "rbxasset://sounds/action_get_up.mp3", Pitch = 1.15, Volume = 0.7 },
	RevealCommon = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.0, Volume = 0.65 },
	RevealRare = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.25, Volume = 0.75 },
	RevealEpic = { Id = "rbxasset://sounds/victory.wav", Pitch = 1.15, Volume = 0.85 },
	Caught = { Id = "rbxasset://sounds/uuhhh.mp3", Pitch = 0.95, Volume = 0.85 },
	Deliver = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.4, Volume = 0.75 },
	SafeZoneSuccess = { Id = "rbxasset://sounds/victory.wav", Pitch = 1.05, Volume = 0.95 },
	Purchase = { Id = "rbxasset://sounds/victory.wav", Pitch = 1.35, Volume = 0.75 },
	AbilityUse = { Id = "rbxasset://sounds/action_jump.mp3", Pitch = 1.3, Volume = 0.75 },
	WardenAlert = { Id = "rbxasset://sounds/bass.mp3", Pitch = 0.9, Volume = 0.85 },
	UiClick = { Id = "rbxasset://sounds/button.wav", Pitch = 1.2, Volume = 0.5 },
	PamaloSlap = { Id = "rbxasset://sounds/snap.mp3", Pitch = 0.95, Volume = 0.9 },
	SipatThrow = { Id = "rbxasset://sounds/swordslash.wav", Pitch = 1.45, Volume = 0.7 },
	GuardAlert = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 0.7, Volume = 0.8 },
	NoiseWarn = { Id = "rbxasset://sounds/switch3.wav", Pitch = 1.35, Volume = 0.55 },
	FiestaFanfare = { Id = "rbxasset://sounds/victory.wav", Pitch = 1.08, Volume = 0.9 },
	PalayokCrack = { Id = "rbxasset://sounds/snap.mp3", Pitch = 0.82, Volume = 0.95 },
	BiikSqueal = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.65, Volume = 0.8 },
	BoodleEat = { Id = "rbxasset://sounds/action_get_up.mp3", Pitch = 1.25, Volume = 0.85 },
}

return SoundData
