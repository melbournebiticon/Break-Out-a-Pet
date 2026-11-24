--!strict
-- Toasts.luau (CLIENT)
-- Polished "Steal an Egg"-style animated pill toasts at top-center (supports single-line & title+subtitle zone toasts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))
local VfxController = require(script.Parent.Parent:WaitForChild("VfxController"))

local Toasts = {}

local container: Frame
local MAX_TOASTS = 1

function Toasts.Show(message: string, color: Color3?, subtitle: string?)
	if not container then
		return
	end

	local children = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	while #children >= MAX_TOASTS do
		children[1]:Destroy()
		table.remove(children, 1)
	end

	local hasSub = typeof(subtitle) == "string" and subtitle ~= ""
	local height = if hasSub then 44 else 32
	local accent = color or Theme.AccentGold

	local toast = Theme.MakeFrame("Toast", UDim2.new(1, 0, 0, height), UDim2.fromScale(0, 0), Color3.fromRGB(16, 19, 28), 16, container)
	toast.BackgroundTransparency = 0.18
	toast.Active = false
	toast.Interactable = false
	Theme.AddStroke(toast, accent, 2)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(32, 38, 56), Color3.fromRGB(18, 20, 30))
	grad.Rotation = 90
	grad.Parent = toast

	local scale = Instance.new("UIScale")
	scale.Scale = 0.72
	scale.Parent = toast
	TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local titleLbl = Theme.MakeLabel(
		"Title",
		message,
		UDim2.fromScale(0.92, if hasSub then 0.50 else 0.78),
		UDim2.fromScale(0.04, if hasSub then 0.08 else 0.11),
		Theme.FontTitle,
		accent,
		toast
	)

	local subLbl: TextLabel? = nil
	if hasSub then
		subLbl = Theme.MakeLabel(
			"Subtitle",
			subtitle :: string,
			UDim2.fromScale(0.92, 0.34),
			UDim2.fromScale(0.04, 0.58),
			Theme.FontBody,
			Color3.fromRGB(230, 235, 245),
			toast
		)
	end

	if string.find(string.lower(message), "caught") then
		SoundController.Play("Caught")
		VfxController.ShakeCamera(0.35, 0.55)
	elseif string.find(string.lower(message), "rescued") then
		SoundController.Play("Deliver")
	end

	local holdTime = if hasSub then 1.05 else 0.95
	task.delay(holdTime, function()
		if toast.Parent then
			TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
			TweenService:Create(toast, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(titleLbl, TweenInfo.new(0.14), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			if subLbl then
				TweenService:Create(subLbl, TweenInfo.new(0.14), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
			task.wait(0.15)
			if toast.Parent then
				toast:Destroy()
			end
		end
	end)
end

function Toasts.Init(screenGui: ScreenGui)
	container = Instance.new("Frame")
	container.Name = "ToastContainer"
	container.Size = UDim2.new(0, 310, 0, 56)
	container.Position = UDim2.new(0.5, 0, 0, 8)
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.BackgroundTransparency = 1
	container.Active = false
	container.Interactable = false
	container.ZIndex = 25
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local notifyEvent = Remotes.GetEvent("Notify")
	notifyEvent.OnClientEvent:Connect(function(message: any, color: any)
		if typeof(message) == "string" then
			Toasts.Show(message, if typeof(color) == "Color3" then color else nil)
		end
	end)
end

return Toasts
