--!strict
-- NOUVEAUTÉS (onglet de la fenêtre Infos) : notes de mise à jour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local UpdatesScreen = {}

-- Vrai si la dernière note n'a pas encore été lue.
function UpdatesScreen.hasUnread(): boolean
	local profile = State.Profile
	local latest = PatchNotes[1]
	return profile ~= nil and latest ~= nil and profile.SeenPatch ~= latest.Version
end

-- Marque la dernière note comme lue.
function UpdatesScreen.markRead()
	local latest = PatchNotes[1]
	if latest and UpdatesScreen.hasUnread() then
		State.request("ProfileAction", "SeenPatch", latest.Version)
	end
end

-- Construit l'onglet dans `parent`.
function UpdatesScreen.build(parent: Instance, z: number)
	local list = Kit.scroll({ ZIndex = z, Parent = parent })
	Kit.list(list, 16)
	Kit.padding(list, 4, 4)
	for order, note in PatchNotes do
		local latest = order == 1
		local card = Kit.surface({
			Color = if latest then Color3.fromRGB(255, 248, 236) else C.Surface2,
			BorderColor = if latest then Color3.fromRGB(255, 210, 160) else C.Border,
			Size = UDim2.new(1, -14, 0, 0),
			AutoSize = Enum.AutomaticSize.Y,
			Radius = 16,
			Order = order,
			ZIndex = z,
			Parent = list,
		})
		Kit.padding(card, 22, 18)
		Kit.list(card, 8)
		local header = Kit.box({ Size = UDim2.new(1, 0, 0, 40), Order = 1, ZIndex = z + 1, Parent = card })
		local version = Kit.plate({
			Color = if latest then C.Accent else C.TextFaint,
			Size = UDim2.fromOffset(96, 34),
			Radius = 17,
			ZIndex = z + 1,
			Parent = header,
		})
		Kit.label({
			Text = `v{note.Version}`,
			Font = Theme.Fonts.Number,
			TextSize = Theme.Text.Body,
			Color = C.White,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z + 2,
			Parent = version,
		})
		Kit.label({
			Text = note.Title,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			Size = UDim2.new(1, -240, 1, 0),
			Position = UDim2.fromOffset(112, 0),
			ZIndex = z + 1,
			Parent = header,
		})
		Kit.label({
			Text = note.Date,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Small,
			Color = C.TextFaint,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(0, 120, 1, 0),
			Position = UDim2.new(1, -120, 0, 0),
			ZIndex = z + 1,
			Parent = header,
		})
		for sectionIndex, section in note.Sections do
			Kit.label({
				Text = string.upper(section.Heading),
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Small,
				Color = if latest then C.AccentDark else C.TextMuted,
				Size = UDim2.new(1, 0, 0, 24),
				Order = sectionIndex * 100,
				ZIndex = z + 1,
				Parent = card,
			})
			for lineIndex, line in section.Lines do
				local row = Kit.box({
					Size = UDim2.new(1, 0, 0, 0),
					AutoSize = Enum.AutomaticSize.Y,
					Order = sectionIndex * 100 + lineIndex,
					ZIndex = z + 1,
					Parent = card,
				})
				local bullet = Kit.new("Frame", {
					BackgroundColor3 = if latest then C.Accent else C.BorderStrong,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(8, 8),
					Position = UDim2.fromOffset(4, 8),
					ZIndex = z + 1,
					Parent = row,
				})
				Kit.round(bullet)
				Kit.label({
					Text = line,
					Font = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Body,
					Color = C.Text,
					Wrap = true,
					AlignY = Enum.TextYAlignment.Top,
					Size = UDim2.new(1, -24, 0, 0),
					Position = UDim2.fromOffset(22, 0),
					AutoSize = Enum.AutomaticSize.Y,
					ZIndex = z + 1,
					Parent = row,
				})
			end
		end
	end
end

return UpdatesScreen
