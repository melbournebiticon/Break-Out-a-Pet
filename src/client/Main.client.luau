--!strict
-- Main.client.luau (CLIENT)
-- Creates the main ScreenGui and initializes all client UI panels and SFX/VFX controllers.

local Players = game:GetService("Players")

local SoundController = require(script.Parent:WaitForChild("SoundController"))
local VfxController = require(script.Parent:WaitForChild("VfxController"))
local UI = script.Parent:WaitForChild("UI")

local Toasts = require(UI:WaitForChild("Toasts"))
local Hud = require(UI:WaitForChild("Hud"))
local InventoryPanel = require(UI:WaitForChild("InventoryPanel"))
local ShopPanel = require(UI:WaitForChild("ShopPanel"))
local FusionPanel = require(UI:WaitForChild("FusionPanel"))
local DailyPanel = require(UI:WaitForChild("DailyPanel"))
local TradePanel = require(UI:WaitForChild("TradePanel"))
local SellPetPanel = require(UI:WaitForChild("SellPetPanel"))
local AbilityButton = require(UI:WaitForChild("AbilityButton"))
local TutorialGuide = require(UI:WaitForChild("TutorialGuide"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BreakOutAPetUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

SoundController.Init()
VfxController.Init()
Toasts.Init(screenGui)

local panels: { [string]: { SetVisible: (boolean) -> (), IsVisible: () -> boolean } } = {
	Pets = InventoryPanel,
	Shop = ShopPanel,
	Fusion = FusionPanel,
	Daily = DailyPanel,
	Trade = TradePanel,
	SellPet = SellPetPanel,
}

local function closeAllPanels()
	for _, panel in panels do
		panel.SetVisible(false)
	end
	Hud.SetSideMenuVisible(true)
end

local function togglePanel(name: string)
	local target = panels[name]
	if not target then
		return
	end
	local wasOpen = target.IsVisible()
	closeAllPanels()
	if not wasOpen then
		target.SetVisible(true)
		Hud.SetSideMenuVisible(false)
	end
end

local function openPanel(name: string)
	closeAllPanels()
	local target = panels[name]
	if target then
		target.SetVisible(true)
		Hud.SetSideMenuVisible(false)
	end
end

InventoryPanel.Init(screenGui, closeAllPanels)
ShopPanel.Init(screenGui, closeAllPanels)
FusionPanel.Init(screenGui, closeAllPanels, function()
	openPanel("Fusion")
end)
DailyPanel.Init(screenGui, closeAllPanels)
TradePanel.Init(screenGui, closeAllPanels, function()
	openPanel("Trade")
end)
SellPetPanel.Init(screenGui, closeAllPanels, function()
	openPanel("SellPet")
end)
AbilityButton.Init(screenGui)
TutorialGuide.Init(screenGui)

Hud.Init(screenGui, {
	TogglePanel = togglePanel,
})

print("[Break Out a Pet] Client UI & Controllers initialized")
