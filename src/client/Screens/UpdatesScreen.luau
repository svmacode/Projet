--!strict
-- Écran MISES À JOUR : notes de version (patch notes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local UpdatesScreen = {}

function UpdatesScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "MISES À JOUR", "アップデート", C.Night, close)
	local list = Kit.scroll(screen.Content, { ZIndex = 22 })
	Kit.list(list, 20)
	Kit.padding(list, 8)
	for order, note in PatchNotes do
		local lines = 0
		for _, section in note.Sections do
			lines += 1 + #section.Lines
		end
		local face, _ = Kit.panel({
			Size = UDim2.new(1, -20, 0, 110 + lines * 30),
			Color = C.Paper,
			Order = order,
			ZIndex = 23,
			Parent = list,
		})
		local tag = Kit.new("Frame", {
			BackgroundColor3 = C.Red,
			Size = UDim2.fromOffset(150, 44),
			Position = UDim2.fromOffset(16, 16),
			Rotation = -3,
			ZIndex = 24,
			Parent = face,
		})
		Kit.stroke(tag, 3)
		Kit.text({ Text = `v{note.Version}`, Color = C.Paper, Stroke = C.Ink, ZIndex = 25, Parent = tag })
		Kit.text({
			Text = note.Title,
			Size = UDim2.new(1, -380, 0, 44),
			Position = UDim2.fromOffset(186, 16),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 24,
			Parent = face,
		})
		Kit.text({
			Text = note.Date,
			Font = Theme.Fonts.Heavy,
			Color = C.Steel,
			Size = UDim2.fromOffset(160, 30),
			Position = UDim2.new(1, -176, 0, 22),
			AlignX = Enum.TextXAlignment.Right,
			ZIndex = 24,
			Parent = face,
		})
		local body = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -40, 1, -80),
			Position = UDim2.fromOffset(20, 76),
			ZIndex = 24,
			Parent = face,
		})
		Kit.list(body, 2)
		local row = 0
		for _, section in note.Sections do
			row += 1
			Kit.text({
				Text = string.upper(section.Heading),
				Color = C.Blue,
				Size = UDim2.new(1, 0, 0, 28),
				AlignX = Enum.TextXAlignment.Left,
				Order = row,
				ZIndex = 25,
				Parent = body,
			})
			for _, line in section.Lines do
				row += 1
				Kit.text({
					Text = `• {line}`,
					Font = Theme.Fonts.Body,
					Size = UDim2.new(1, 0, 0, 28),
					AlignX = Enum.TextXAlignment.Left,
					MaxSize = 20,
					Order = row,
					ZIndex = 25,
					Parent = body,
				})
			end
		end
	end
	local open = screen.Open
	screen.Open = function()
		local latest = PatchNotes[1]
		if latest then
			State.request("ProfileAction", "SeenPatch", latest.Version)
		end
		open()
	end
	return screen
end

return UpdatesScreen
