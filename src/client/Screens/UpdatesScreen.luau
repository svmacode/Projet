--!strict
-- NOUVEAUTÉS : notes de mise à jour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local UpdatesScreen = {}

function UpdatesScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local accent = Theme.Section.Updates
	local page = Page.modal(parent, "Nouveautés", Vector2.new(880, 640), onClose, accent)
	local list = Kit.scroll({ ZIndex = 33, Parent = page.Content })
	Kit.list(list, 22)
	Kit.padding(list, 4, 6)
	local palette = { C.Pink, C.Cyan, C.Lime, C.Violet }
	for order, note in PatchNotes do
		local latest = order == 1
		local card = Kit.surface({
			Color = if latest then Theme.darken(accent, 0.72) else C.Surface2,
			Size = UDim2.new(1, -16, 0, 0),
			AutoSize = Enum.AutomaticSize.Y,
			BorderThickness = 3,
			Order = order,
			ZIndex = 33,
			Parent = list,
		})
		Kit.padding(card, 22, 18)
		Kit.list(card, 8)
		-- En-tête : gros numéro de version + date + titre.
		local header = Kit.box({ Size = UDim2.new(1, 0, 0, 64), Order = 1, ZIndex = 34, Parent = card })
		local plate = Kit.plate({
			Color = if latest then accent else C.Surface3,
			Size = UDim2.fromOffset(132, 54),
			Position = UDim2.fromOffset(4, 4),
			Shadow = false,
			ZIndex = 34,
			Parent = header,
		})
		Kit.label({
			Text = note.Version,
			Font = Theme.Fonts.Number,
			TextSize = 36,
			Color = if latest then Theme.onColor(accent) else C.Text,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 35,
			Parent = plate,
		})
		Kit.label({
			Text = string.upper(note.Title),
			Font = Theme.Fonts.Hero,
			TextSize = 36,
			Stroke = 2,
			Size = UDim2.new(1, -160, 0, 38),
			Position = UDim2.fromOffset(156, 0),
			ZIndex = 34,
			Parent = header,
		})
		Kit.label({
			Text = if latest then `{note.Date}  ·  DERNIÈRE VERSION` else note.Date,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Small,
			Color = if latest then accent else C.TextMuted,
			Size = UDim2.new(1, -160, 0, 20),
			Position = UDim2.fromOffset(158, 40),
			ZIndex = 34,
			Parent = header,
		})
		local row = 1
		for sectionIndex, section in note.Sections do
			local color = palette[(sectionIndex - 1) % #palette + 1]
			row += 1
			local holder = Kit.box({ Size = UDim2.new(1, 0, 0, 40), Order = row, ZIndex = 34, Parent = card })
			local tag = Kit.plate({
				Color = color,
				Size = UDim2.fromOffset(18 + #section.Heading * 13, 28),
				Position = UDim2.fromOffset(2, 8),
				BorderThickness = 2.5,
				Shadow = false,
				ZIndex = 34,
				Parent = holder,
			})
			Kit.label({
				Text = string.upper(section.Heading),
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Body,
				Color = Theme.onColor(color),
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 35,
				Parent = tag,
			})
			for _, line in section.Lines do
				row += 1
				local item = Kit.box({
					Size = UDim2.new(1, 0, 0, 0),
					AutoSize = Enum.AutomaticSize.Y,
					Order = row,
					ZIndex = 34,
					Parent = card,
				})
				local bullet = Kit.new("Frame", {
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(9, 9),
					Position = UDim2.fromOffset(6, 7),
					Rotation = 45,
					ZIndex = 35,
					Parent = item,
				})
				Kit.border(bullet, C.Ink, 1.5)
				Kit.label({
					Text = line,
					Font = Theme.Fonts.Semibold,
					Color = C.Text,
					Wrap = true,
					Size = UDim2.new(1, -28, 0, 22),
					Position = UDim2.fromOffset(28, 0),
					AutoSize = Enum.AutomaticSize.Y,
					ZIndex = 35,
					Parent = item,
				})
			end
		end
	end
	local baseOpen = page.Open
	page.Open = function()
		local latest = PatchNotes[1]
		if latest then
			State.request("ProfileAction", "SeenPatch", latest.Version)
		end
		baseOpen()
	end
	return page
end

return UpdatesScreen
