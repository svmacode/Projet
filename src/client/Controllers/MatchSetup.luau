--!strict
-- Avant le coup d'envoi : choix du poste (un seul gardien par équipe) puis
-- d'un archétype de ce poste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local MatchSetup = {}

local POSTES = { Gardien = "Gardien", Defenseur = "Défenseur", Attaquant = "Attaquant" }

local gui: ScreenGui
local title: TextLabel
local timer: TextLabel
local columns: { [string]: Frame } = {}
local posteSelector: Kit.Segmented
local cardRow: ScrollingFrame
local powers: Frame
local ready: Kit.Button
local hint: TextLabel

local function mine(setup: any): any
	for _, entry in setup.Participants do
		if entry.UserId == LocalPlayer.UserId then
			return entry
		end
	end
	return nil
end

local function renderTeams(setup: any)
	for team, column in columns do
		Kit.clear(column)
		local order = 0
		for _, entry in setup.Participants do
			if entry.Team == team then
				order += 1
				local row = Kit.surface({
					Color = if entry.UserId == LocalPlayer.UserId then C.Surface3 else C.Surface2,
					Size = UDim2.new(1, 0, 0, 60),
					Order = order,
					ZIndex = 4,
					Parent = column,
				})
				local archetype = Archetypes.get(entry.Archetype)
				Kit.label({
					Text = entry.Name,
					Font = Theme.Fonts.Bold,
					Position = UDim2.fromOffset(16, 8),
					Size = UDim2.new(1, -60, 0, 22),
					ZIndex = 5,
					Parent = row,
				})
				Kit.label({
					Text = if entry.Poste
						then `{POSTES[entry.Poste]}{if archetype then " · " .. archetype.Name else ""}`
						else "Choisit son poste…",
					TextSize = Theme.Text.Small,
					Color = C.TextMuted,
					Position = UDim2.fromOffset(16, 30),
					Size = UDim2.new(1, -60, 0, 20),
					ZIndex = 5,
					Parent = row,
				})
				local status = Kit.new("Frame", {
					BackgroundColor3 = if entry.Ready then C.Success else C.Surface3,
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.new(1, -24, 0.5, -5),
					ZIndex = 5,
					Parent = row,
				})
				Kit.corner(status, 5)
			end
		end
	end
end

local function render(setup: any)
	if not setup or setup.Closed then
		gui.Enabled = false
		return
	end
	local me = mine(setup)
	if not me then
		return
	end
	gui.Enabled = true
	local modeInfo = Config.Modes[setup.Mode]
	title.Text = `{modeInfo.Label}{if setup.Ranked
		then " · Classé"
		elseif setup.Training then " · Entraînement"
		else ""}  ·  Équipe {string.lower(Theme.Team[me.Team].Name)}`
	title.TextColor3 = C.Text
	renderTeams(setup)

	local keeperTaken = false
	for _, entry in setup.Participants do
		if entry.Team == me.Team and entry.Poste == "Gardien" and entry.UserId ~= LocalPlayer.UserId then
			keeperTaken = true
		end
	end
	posteSelector.SetEnabled("Gardien", not keeperTaken)
	if me.Poste then
		posteSelector.Select(me.Poste)
	end

	Kit.clear(cardRow)
	if me.Poste then
		local profile = State.Profile
		local list = Archetypes.byPoste(me.Poste)
		table.sort(list, function(a, b)
			return (Rarities.get(a.Rarity) :: any).Rank < (Rarities.get(b.Rarity) :: any).Rank
		end)
		for index, archetype in list do
			local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
			Cards.archetype(cardRow, archetype, {
				Size = UDim2.fromOffset(156, 214),
				Owned = owned,
				Selected = me.Archetype == archetype.Id,
				Order = index,
				ZIndex = 5,
				OnClick = if owned
					then function()
						State.request("MatchSetupAction", "Archetype", archetype.Id)
					end
					else nil,
			})
		end
		hint.Visible = false
	else
		hint.Visible = true
	end

	Kit.clear(powers)
	local archetype = Archetypes.get(me.Archetype)
	if archetype then
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Size = UDim2.new(1 / 3, -8, 0, 96), Order = power.Slot, ZIndex = 6 })
		end
	end
	ready.SetEnabled(me.Poste ~= nil and not me.Ready)
	ready.SetText(if me.Ready then "Prêt — en attente des autres" else "Je suis prêt")
end

function MatchSetup.start()
	local root: Frame
	gui, root = Kit.screen("ChoixDuPoste", 40, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = root,
	})
	local page =
		Kit.box({ Size = UDim2.new(1, -96, 1, -80), Position = UDim2.fromOffset(48, 40), ZIndex = 2, Parent = root })

	Kit.label({
		Text = "CHOIX DU POSTE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.Accent,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 3,
		Parent = page,
	})
	title = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H1,
		Size = UDim2.new(1, -240, 0, 44),
		Position = UDim2.fromOffset(0, 20),
		ZIndex = 3,
		Parent = page,
	})
	timer = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H1,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.new(1, 0, 0, 20),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 3,
		Parent = page,
	})

	for index, team in { "Rouge", "Bleu" } do
		local panel = Kit.surface({
			Color = C.Surface,
			Size = UDim2.new(0, 300, 1, -96),
			Position = if index == 1 then UDim2.fromOffset(0, 96) else UDim2.new(1, 0, 0, 96),
			AnchorPoint = if index == 1 then Vector2.zero else Vector2.new(1, 0),
			Radius = Theme.RadiusLarge,
			ZIndex = 3,
			Parent = page,
		})
		Kit.new("Frame", {
			BackgroundColor3 = Theme.Team[team].Main,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -48, 0, 3),
			Position = UDim2.fromOffset(24, 0),
			ZIndex = 4,
			Parent = panel,
		})
		Kit.label({
			Text = `Équipe {string.lower(Theme.Team[team].Name)}`,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.H3,
			Position = UDim2.fromOffset(24, 18),
			Size = UDim2.new(1, -48, 0, 26),
			ZIndex = 4,
			Parent = panel,
		})
		local column = Kit.box({
			Size = UDim2.new(1, -32, 1, -72),
			Position = UDim2.fromOffset(16, 60),
			ZIndex = 4,
			Parent = panel,
		})
		Kit.list(column, 8)
		columns[team] = column
	end

	local center =
		Kit.box({ Size = UDim2.new(1, -660, 1, -96), Position = UDim2.fromOffset(330, 96), ZIndex = 3, Parent = page })
	Kit.label({
		Text = "POSTE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 4,
		Parent = center,
	})
	posteSelector = Kit.segmented({
		Options = {
			{ Id = "Gardien", Label = "Gardien" },
			{ Id = "Defenseur", Label = "Défenseur" },
			{ Id = "Attaquant", Label = "Attaquant" },
		},
		Value = "",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = 4,
		Parent = center,
		OnChange = function(value: string)
			State.request("MatchSetupAction", "Poste", value)
		end,
	})
	Kit.label({
		Text = "ARCHÉTYPE",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 4,
		Parent = center,
	})
	cardRow = Kit.scroll({
		Horizontal = true,
		Size = UDim2.new(1, 0, 0, 226),
		Position = UDim2.fromOffset(0, 110),
		ZIndex = 4,
		Parent = center,
	})
	Kit.list(cardRow, 12, true)
	hint = Kit.label({
		Text = "Choisis d'abord ton poste.",
		Color = C.TextMuted,
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 24),
		AlignX = Enum.TextXAlignment.Center,
		ZIndex = 5,
		Parent = center,
	})
	powers =
		Kit.box({ Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 352), ZIndex = 5, Parent = center })
	Kit.list(powers, 12, true)
	ready = Kit.button({
		Text = "Je suis prêt",
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		ZIndex = 5,
		Parent = center,
		OnClick = function()
			State.request("MatchSetupAction", "Ready")
		end,
	})

	State.SetupChanged:Connect(render)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			gui.Enabled = false
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local setup = State.Setup
			if gui.Enabled and setup and not setup.Closed then
				local remaining = math.max(0, setup.Deadline - Workspace:GetServerTimeNow())
				timer.Text = `{math.ceil(remaining)}`
				timer.TextColor3 = if remaining < 6 then C.Danger else C.Text
			end
		end
	end)
end

return MatchSetup
