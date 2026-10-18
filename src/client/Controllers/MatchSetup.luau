--!strict
-- Début de partie : chaque joueur choisit son poste (un seul gardien par
-- équipe) puis un archétype de ce poste parmi ceux qu'il possède.

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

local POSTE_NAMES = { Gardien = "GARDIEN", Defenseur = "DÉFENSEUR", Attaquant = "ATTAQUANT" }
local POSTE_COLORS = { Gardien = C.Green, Defenseur = C.Blue, Attaquant = C.Red }

local gui: ScreenGui
local root: Frame
local teamColumns: { [string]: Frame } = {}
local posteRow: Frame
local cardRow: ScrollingFrame
local timerText: TextLabel
local readyButton: Kit.Button
local powersPanel: Frame
local titleText: TextLabel

local function me(setup: any): any
	for _, entry in setup.Participants do
		if entry.UserId == LocalPlayer.UserId then
			return entry
		end
	end
	return nil
end

local function renderTeams(setup: any)
	for team, column in teamColumns do
		Kit.clear(column)
		local order = 0
		for _, entry in setup.Participants do
			if entry.Team == team then
				order += 1
				local archetype = Archetypes.get(entry.Archetype)
				local row = Kit.new("Frame", {
					BackgroundColor3 = if entry.UserId == LocalPlayer.UserId then C.Yellow else C.Paper,
					Size = UDim2.new(1, 0, 0, 64),
					LayoutOrder = order,
					ZIndex = 4,
					Parent = column,
				})
				Kit.stroke(row, 3)
				Kit.text({
					Text = entry.Name,
					Font = Theme.Fonts.Body,
					Size = UDim2.new(1, -80, 0, 28),
					Position = UDim2.fromOffset(10, 4),
					AlignX = Enum.TextXAlignment.Left,
					ZIndex = 5,
					Parent = row,
				})
				Kit.text({
					Text = if entry.Poste
						then `{POSTE_NAMES[entry.Poste]}{if archetype then " · " .. archetype.Name else ""}`
						else "choisit…",
					Font = Theme.Fonts.Heavy,
					Color = if entry.Poste then POSTE_COLORS[entry.Poste] else C.Steel,
					Size = UDim2.new(1, -80, 0, 22),
					Position = UDim2.fromOffset(10, 34),
					AlignX = Enum.TextXAlignment.Left,
					ZIndex = 5,
					Parent = row,
				})
				if entry.Ready then
					local check = Kit.new("Frame", {
						BackgroundColor3 = C.Green,
						Size = UDim2.fromOffset(44, 44),
						Position = UDim2.new(1, -54, 0, 10),
						ZIndex = 5,
						Parent = row,
					})
					Kit.corner(check, 44)
					Kit.stroke(check, 3)
					Kit.text({ Text = "✔", ZIndex = 6, Parent = check })
				end
			end
		end
	end
end

local function renderPowers(archetypeId: string?)
	Kit.clear(powersPanel)
	local archetype = Archetypes.get(archetypeId)
	if not archetype then
		return
	end
	for _, power in archetype.Powers do
		Cards.power(powersPanel, power, { Size = UDim2.new(1, -8, 0, 92), Order = power.Slot, ZIndex = 6 })
	end
end

local function render(setup: any)
	if not setup or setup.Closed then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local mine = me(setup)
	if not mine then
		return
	end
	titleText.Text = `{Config.Modes[setup.Mode].Label}{if setup.Ranked
		then " · CLASSÉ"
		elseif setup.Training then " · ENTRAÎNEMENT"
		else ""}  —  ÉQUIPE {string.upper(mine.Team)}`
	renderTeams(setup)

	-- Postes.
	Kit.clear(posteRow)
	local keeperTaken = false
	for _, entry in setup.Participants do
		if entry.Team == mine.Team and entry.Poste == "Gardien" and entry.UserId ~= LocalPlayer.UserId then
			keeperTaken = true
		end
	end
	for index, poste in Archetypes.PosteOrder do
		local selected = mine.Poste == poste
		local button = Kit.button({
			Text = POSTE_NAMES[poste],
			Color = if selected then C.Yellow else POSTE_COLORS[poste],
			TextColor = if selected then C.Ink else C.Paper,
			TextStroke = if selected then nil else C.Ink,
			Size = UDim2.fromOffset(250, 70),
			Rotation = -1.5,
			Order = index,
			ZIndex = 5,
			Parent = posteRow,
			OnClick = function()
				State.request("MatchSetupAction", "Poste", poste)
			end,
		})
		if poste == "Gardien" and keeperTaken then
			button.SetEnabled(false)
			button.SetText("GARDIEN (PRIS)")
		end
	end

	-- Archétypes du poste choisi.
	Kit.clear(cardRow)
	if mine.Poste then
		local profile = State.Profile
		local list = Archetypes.byPoste(mine.Poste)
		table.sort(list, function(a, b)
			return (Rarities.get(a.Rarity) :: any).Rank < (Rarities.get(b.Rarity) :: any).Rank
		end)
		for index, archetype in list do
			local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
			Cards.archetype(cardRow, archetype, {
				Size = UDim2.fromOffset(150, 210),
				Owned = owned,
				Selected = mine.Archetype == archetype.Id,
				Order = index,
				ZIndex = 5,
				OnClick = if owned
					then function()
						State.request("MatchSetupAction", "Archetype", archetype.Id)
					end
					else nil,
			})
		end
	else
		Kit.text({
			Text = "CHOISIS TON POSTE",
			Color = C.Paper,
			Stroke = C.Ink,
			Size = UDim2.fromOffset(600, 60),
			ZIndex = 5,
			Parent = cardRow,
		})
	end
	renderPowers(mine.Archetype)
	readyButton.SetEnabled(mine.Poste ~= nil and not mine.Ready)
	readyButton.SetText(if mine.Ready then "PRÊT !" else "JE SUIS PRÊT")
end

function MatchSetup.start()
	gui = Kit.screen("ChoixPoste", 40, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	root = Kit.root(gui)

	local background =
		Kit.new("Frame", { BackgroundColor3 = C.Night, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root })
	Kit.sunburst(background, C.Night, Theme.shade(C.Night, 0.06), 20, true).ZIndex = 1

	local banner = Kit.new("Frame", {
		BackgroundColor3 = C.Red,
		Size = UDim2.new(1, 40, 0, 84),
		Position = UDim2.fromOffset(-20, 24),
		Rotation = -1,
		ZIndex = 3,
		Parent = root,
	})
	Kit.stroke(banner, 5)
	titleText = Kit.text({
		Text = "",
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.new(1, -400, 1, -14),
		Position = UDim2.fromOffset(40, 7),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = banner,
	})
	timerText = Kit.text({
		Text = "",
		Color = C.Yellow,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.fromOffset(300, 70),
		Position = UDim2.new(1, -340, 0, 7),
		ZIndex = 4,
		Parent = banner,
	})

	for index, team in { "Rouge", "Bleu" } do
		local face, _ = Kit.panel({
			Size = UDim2.fromOffset(300, 420),
			Position = if index == 1 then UDim2.fromOffset(30, 140) else UDim2.new(1, -330, 0, 140),
			Color = Theme.Team[team].Main,
			ZIndex = 3,
			Parent = root,
		})
		Kit.text({
			Text = `ÉQUIPE {string.upper(team)}`,
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 3,
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.fromOffset(10, 8),
			ZIndex = 4,
			Parent = face,
		})
		local column = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 1, -70),
			Position = UDim2.fromOffset(10, 60),
			ZIndex = 4,
			Parent = face,
		})
		Kit.list(column, 8)
		teamColumns[team] = column
	end

	posteRow = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(800, 80),
		Position = UDim2.new(0.5, 0, 0, 140),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 4,
		Parent = root,
	})
	cardRow = Kit.scroll(
		root,
		{ Horizontal = true, Size = UDim2.fromOffset(820, 240), Position = UDim2.new(0.5, -410, 0, 236), ZIndex = 4 }
	)
	powersPanel = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(820, 300),
		Position = UDim2.new(0.5, -410, 0, 486),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(posteRow, 16, true)
	Kit.list(cardRow, 14, true)
	Kit.list(powersPanel, 8)
	readyButton = Kit.button({
		Text = "JE SUIS PRÊT",
		Color = C.Yellow,
		Size = UDim2.fromOffset(380, 84),
		Position = UDim2.new(0.5, 0, 1, -60),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -2,
		ShadowOffset = 8,
		StrokeThickness = 5,
		ZIndex = 6,
		Parent = root,
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
				timerText.Text = `{math.ceil(remaining)} s`
			end
		end
	end)
end

return MatchSetup
