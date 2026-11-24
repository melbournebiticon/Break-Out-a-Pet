--!strict
-- ClientSyncService.luau (SERVER)
-- Sends inventory updates ("InventorySync") and toast notifications ("Notify") to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientSyncService = {}

local inventorySyncEvent: RemoteEvent
local notifyEvent: RemoteEvent

function ClientSyncService.SyncInventory(player: Player, pets: { any })
	if not inventorySyncEvent then
		inventorySyncEvent = Remotes.GetEvent("InventorySync")
	end
	if player.Parent then
		inventorySyncEvent:FireClient(player, pets)
	end
end

function ClientSyncService.Notify(player: Player, message: string, color: Color3?)
	if not notifyEvent then
		notifyEvent = Remotes.GetEvent("Notify")
	end
	if player.Parent then
		notifyEvent:FireClient(player, message, color)
	end
end

function ClientSyncService.Init()
	inventorySyncEvent = Remotes.GetEvent("InventorySync")
	notifyEvent = Remotes.GetEvent("Notify")
end

return ClientSyncService
