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

local function sentenceCase(text: string): string
	local lower = string.lower(text)
	return string.upper(string.sub(lower, 1, 1)) .. string.sub(lower, 2)
end

function UpdatesScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local page = Page.modal(parent, "Nouveautés", Vector2.new(880, 640), onClose)
	local list = Kit.scroll({ ZIndex = 33, Parent = page.Content })
	Kit.list(list, 28)
	for order, note in PatchNotes do
		local block = Kit.box({
			Size = UDim2.new(1, -12, 0, 0),
			AutoSize = Enum.AutomaticSize.Y,
			Order = order,
			ZIndex = 33,
			Parent = list,
		})
		Kit.list(block, 6)
		Kit.label({
			Text = `VERSION {note.Version}  ·  {note.Date}`,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = C.Accent,
			Size = UDim2.new(1, 0, 0, 16),
			Order = 1,
			ZIndex = 34,
			Parent = block,
		})
		Kit.label({
			Text = sentenceCase(note.Title),
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Size = UDim2.new(1, 0, 0, 32),
			Order = 2,
			ZIndex = 34,
			Parent = block,
		})
		local row = 2
		for _, section in note.Sections do
			row += 1
			Kit.label({
				Text = section.Heading,
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.H3,
				Size = UDim2.new(1, 0, 0, 34),
				AlignY = Enum.TextYAlignment.Bottom,
				Order = row,
				ZIndex = 34,
				Parent = block,
			})
			for _, line in section.Lines do
				row += 1
				Kit.label({
					Text = `—  {line}`,
					Color = C.TextMuted,
					Wrap = true,
					Size = UDim2.new(1, 0, 0, 22),
					AutoSize = Enum.AutomaticSize.Y,
					Order = row,
					ZIndex = 34,
					Parent = block,
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
