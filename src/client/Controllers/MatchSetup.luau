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
local POSTE_ORDER = { "Gardien", "Defenseur", "Attaquant" }
local POSTE_COLORS = { Gardien = C.Cyan, Defenseur = C.Lime, Attaquant = C.Pink }
local POSTE_HINTS = {
	Gardien = "Un seul par équipe · arrêts et relances",
	Defenseur = "Contres, interceptions, contacts",
	Attaquant = "Vitesse, feintes et tirs",
}

local gui: ScreenGui
local title: TextLabel
local timer: TextLabel
local columns: { [string]: Frame } = {}
type PosteSelector = { Select: (string) -> (), SetEnabled: (string, boolean) -> () }
local posteSelector: PosteSelector
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
				local isMe = entry.UserId == LocalPlayer.UserId
				local posteColor = if entry.Poste then POSTE_COLORS[entry.Poste] else C.TextFaint
				local row = Kit.surface({
					Color = if isMe then Theme.darken(Theme.Team[team].Main, 0.35) else C.Surface2,
					BorderColor = if isMe then C.Accent else C.Ink,
					Size = UDim2.new(1, 0, 0, 62),
					Order = order,
					ZIndex = 4,
					Parent = column,
				})
				local heel = Kit.new("Frame", {
					BackgroundColor3 = posteColor,
					BorderSizePixel = 0,
					Size = UDim2.new(0, 8, 1, 0),
					ZIndex = 5,
					Parent = row,
				})
				Kit.corner(heel, 4)
				local archetype = Archetypes.get(entry.Archetype)
				Kit.label({
					Text = entry.Name,
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.H3,
					Color = C.White,
					Stroke = 1.5,
					Position = UDim2.fromOffset(20, 7),
					Size = UDim2.new(1, -60, 0, 24),
					ZIndex = 5,
					Parent = row,
				})
				Kit.label({
					Text = if entry.Poste
						then `{string.upper(POSTES[entry.Poste])}{if archetype then " · " .. archetype.Name else ""}`
						else "Choisit son poste…",
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Small,
					Color = if entry.Poste then posteColor else C.TextMuted,
					Position = UDim2.fromOffset(20, 32),
					Size = UDim2.new(1, -60, 0, 20),
					ZIndex = 5,
					Parent = row,
				})
				local status = Kit.new("Frame", {
					BackgroundColor3 = if entry.Ready then C.Success else C.Surface3,
					Size = UDim2.fromOffset(16, 16),
					Position = UDim2.new(1, -28, 0.5, -8),
					Rotation = 45,
					ZIndex = 5,
					Parent = row,
				})
				Kit.border(status, C.Ink, 2)
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
	ready.SetText(if me.Ready then "PRÊT — EN ATTENTE DES AUTRES" else "JE SUIS PRÊT")
end

function MatchSetup.start()
	local root: Frame
	gui, root = Kit.screen("ChoixDuPoste", 40, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	Kit.backdrop(root, C.Accent, 1)
	local page =
		Kit.box({ Size = UDim2.new(1, -96, 1, -80), Position = UDim2.fromOffset(48, 40), ZIndex = 2, Parent = root })

	local tag = Kit.plate({
		Color = C.Accent,
		Size = UDim2.fromOffset(300, 46),
		ZIndex = 3,
		Parent = page,
	})
	Kit.label({
		Text = "CHOIX DU POSTE",
		Font = Theme.Fonts.Hero,
		TextSize = 36,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = tag,
	})
	title = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Color = C.White,
		Stroke = 2,
		Size = UDim2.new(1, -560, 0, 40),
		Position = UDim2.fromOffset(320, 4),
		ZIndex = 3,
		Parent = page,
	})
	local timerPlate = Kit.plate({
		Color = C.Ink,
		Gradient = false,
		BorderColor = C.Accent,
		Size = UDim2.fromOffset(120, 64),
		Position = UDim2.new(1, 0, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		Rotation = 3,
		ZIndex = 3,
		Parent = page,
	})
	timer = Kit.label({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = 48,
		Color = C.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = timerPlate,
	})

	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local panel = Kit.surface({
			Color = C.Surface,
			Size = UDim2.new(0, 300, 1, -100),
			Position = if index == 1 then UDim2.fromOffset(0, 100) else UDim2.new(1, -6, 0, 100),
			AnchorPoint = if index == 1 then Vector2.zero else Vector2.new(1, 0),
			Radius = Theme.RadiusLarge,
			BorderThickness = 3,
			Shadow = true,
			ShadowColor = info.Main,
			ZIndex = 3,
			Parent = page,
		})
		local header = Kit.plate({
			Color = info.Main,
			Size = UDim2.new(1, 20, 0, 44),
			Position = UDim2.fromOffset(-10, -14),
			ZIndex = 5,
			Parent = panel,
		})
		Kit.label({
			Text = `ÉQUIPE {info.Name}`,
			Font = Theme.Fonts.Hero,
			TextSize = 32,
			Color = C.White,
			Stroke = 2,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = header,
		})
		local column = Kit.box({
			Size = UDim2.new(1, -32, 1, -76),
			Position = UDim2.fromOffset(16, 52),
			ZIndex = 4,
			Parent = panel,
		})
		Kit.list(column, 8)
		columns[team] = column
	end

	local center = Kit.box({
		Size = UDim2.new(1, -660, 1, -100),
		Position = UDim2.fromOffset(330, 100),
		ZIndex = 3,
		Parent = page,
	})
	local function sectionLabel(text: string, y: number, color: Color3)
		local plate = Kit.plate({
			Color = color,
			Size = UDim2.fromOffset(150, 26),
			Position = UDim2.fromOffset(0, y),
			ShadowOffset = 3,
			ZIndex = 4,
			Parent = center,
		})
		Kit.label({
			Text = text,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Small + 1,
			Color = Theme.onColor(color),
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = plate,
		})
	end
	sectionLabel("POSTE", 0, C.Cyan)

	-- Cartes de poste inclinées.
	local posteRow =
		Kit.box({ Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 36), ZIndex = 4, Parent = center })
	Kit.list(posteRow, 14, true)
	local selected = ""
	local taken: { [string]: boolean } = {}
	local posteCards: { [string]: { Face: Frame, Name: TextLabel, Hint: TextLabel, Stroke: UIStroke } } = {}
	local function paintPostes()
		for id, card in posteCards do
			local color = POSTE_COLORS[id]
			local on = id == selected
			card.Face.BackgroundColor3 = if taken[id] then C.Surface elseif on then color else C.Surface2
			card.Stroke.Color = if on then C.White else color
			card.Stroke.Thickness = if on then 3.5 else 2.5
			card.Name.TextColor3 = if taken[id] then C.TextFaint elseif on then Theme.onColor(color) else color
			card.Hint.Text = if taken[id] then "Déjà pris" else POSTE_HINTS[id]
			card.Hint.TextColor3 = if on then Theme.onColor(color) else C.TextMuted
		end
	end
	for index, id in POSTE_ORDER do
		local holder = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1 / 3, -10, 1, 0),
			LayoutOrder = index,
			ZIndex = 4,
			Parent = posteRow,
		})
		local shadow = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -6, 1, -6),
			Position = UDim2.fromOffset(6, 6),
			Rotation = Theme.Tilt,
			ZIndex = 4,
			Parent = holder,
		})
		Kit.corner(shadow, 8)
		local face = Kit.surface({
			Color = C.Surface2,
			Size = UDim2.new(1, -6, 1, -6),
			Rotation = Theme.Tilt,
			Radius = 8,
			ZIndex = 4,
			Parent = holder,
		})
		local stroke = face:FindFirstChildOfClass("UIStroke") :: UIStroke
		local name = Kit.label({
			Text = string.upper(POSTES[id]),
			Font = Theme.Fonts.Hero,
			TextSize = 38,
			Stroke = 1.5,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 46),
			Position = UDim2.fromOffset(0, 10),
			ZIndex = 5,
			Parent = face,
		})
		local hintLabel = Kit.label({
			Text = POSTE_HINTS[id],
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Tiny + 1,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 56),
			ZIndex = 5,
			Parent = face,
		})
		posteCards[id] = { Face = face, Name = name, Hint = hintLabel, Stroke = stroke }
		holder.MouseEnter:Connect(function()
			if not taken[id] then
				face.Rotation = 0
			end
		end)
		holder.MouseLeave:Connect(function()
			face.Rotation = Theme.Tilt
		end)
		holder.Activated:Connect(function()
			if taken[id] or selected == id then
				return
			end
			selected = id
			paintPostes()
			Kit.slam(holder, 1.15)
			Kit.playSound(Theme.Sounds.Click, 0.4)
			State.request("MatchSetupAction", "Poste", id)
		end)
	end
	paintPostes()
	posteSelector = {
		Select = function(id: string)
			selected = id
			paintPostes()
		end,
		SetEnabled = function(id: string, value: boolean)
			taken[id] = not value
			paintPostes()
		end,
	}

	sectionLabel("ARCHÉTYPE", 148, C.Pink)
	cardRow = Kit.scroll({
		Horizontal = true,
		Size = UDim2.new(1, 0, 0, 226),
		Position = UDim2.fromOffset(0, 184),
		ZIndex = 4,
		Parent = center,
	})
	Kit.list(cardRow, 12, true)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), Parent = cardRow })
	hint = Kit.label({
		Text = "CHOISIS D'ABORD TON POSTE",
		Font = Theme.Fonts.Hero,
		TextSize = 34,
		Color = C.TextMuted,
		Stroke = 1.5,
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 40),
		AlignX = Enum.TextXAlignment.Center,
		ZIndex = 5,
		Parent = center,
	})
	powers =
		Kit.box({ Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 420), ZIndex = 5, Parent = center })
	Kit.list(powers, 12, true)
	ready = Kit.button({
		Text = "JE SUIS PRÊT",
		Variant = "Primary",
		Font = Theme.Fonts.Hero,
		TextSize = 32,
		Size = UDim2.new(1, -6, 0, 60),
		Position = UDim2.new(0, 0, 1, -64),
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
				timer.TextColor3 = if remaining < 6 then C.Danger else C.White
			end
		end
	end)
end

return MatchSetup
