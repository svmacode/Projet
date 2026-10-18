--!strict
-- Contour d'encre façon cel-shading sur les personnages (joueurs et bots).
--
-- Roblox limite le nombre de Highlights affichés en même temps (31) : on en
-- garde au plus BUDGET, attribués aux personnages les plus proches de la
-- caméra et réattribués toutes les 0,5 s. Le ballon a déjà son propre
-- contour (BallRenderer), compté dans la marge restante.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Toon = {}

local BUDGET = 28
local REFRESH = 0.5
local MAX_DISTANCE = 160
local INK = Color3.fromRGB(14, 8, 28)

local outlines: { [Model]: Highlight } = {}

local function candidates(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.Parent then
			table.insert(list, character)
		end
	end
	for _, bot in CollectionService:GetTagged("HL_Bot") do
		if bot:IsA("Model") and bot.Parent then
			table.insert(list, bot)
		end
	end
	return list
end

local function rootPosition(model: Model): Vector3?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function attach(model: Model)
	local existing = outlines[model]
	if existing and existing.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ContourEncre"
	highlight.FillTransparency = 1
	highlight.OutlineColor = INK
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	outlines[model] = highlight
end

local function detach(model: Model)
	local highlight = outlines[model]
	if highlight then
		highlight:Destroy()
		outlines[model] = nil
	end
end

local function refresh()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	type Entry = { Model: Model, Distance: number }
	local ranked: { Entry } = {}
	for _, model in candidates() do
		local position = rootPosition(model)
		if position then
			local distance = (position - eye).Magnitude
			if distance <= MAX_DISTANCE then
				table.insert(ranked, { Model = model, Distance = distance })
			end
		end
	end
	table.sort(ranked, function(a, b)
		return a.Distance < b.Distance
	end)
	local keep: { [Model]: boolean } = {}
	for index = 1, math.min(BUDGET, #ranked) do
		keep[ranked[index].Model] = true
	end
	for model in outlines do
		if not keep[model] or model.Parent == nil then
			detach(model)
		end
	end
	for model in keep do
		attach(model)
	end
end

function Toon.start()
	task.spawn(function()
		while true do
			local result = table.pack(pcall(refresh))
			if not result[1] then
				warn(`[Toon] {result[2]}`)
			end
			task.wait(REFRESH)
		end
	end)
end

return Toon
