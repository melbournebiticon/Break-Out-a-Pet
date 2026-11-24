--!strict
-- Remotes.luau
-- Helper to create (server) or wait for (client) RemoteFunctions and RemoteEvents in ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		return folder
	else
		return ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
end

function Remotes.GetFunction(name: string): RemoteFunction
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			return existing
		end
		local fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = folder
		return fn
	else
		return folder:WaitForChild(name) :: RemoteFunction
	end
end

function Remotes.GetEvent(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
		return ev
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
