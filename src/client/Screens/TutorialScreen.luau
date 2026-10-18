--!strict
-- Écran TUTORIEL (facultatif) : les règles et les commandes, page par page.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage.Shared.Data.Tutorial)
local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local TutorialScreen = {}

function TutorialScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "TUTORIEL", "チュートリアル", C.Steel, close)
	local content = screen.Content
	local index = 1

	local page =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -90), ZIndex = 22, Parent = content })
	local counter = Kit.text({
		Text = "",
		Font = Theme.Fonts.Heavy,
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.new(0.5, 0, 1, -50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 23,
		Parent = content,
	})

	local previous: Kit.Button
	local nextButton: Kit.Button

	local function render()
		Kit.clear(page)
		local step = Tutorial[index]
		local panel, _ =
			Kit.panel({ Size = UDim2.new(1, 0, 1, 0), Color = C.Paper, ZIndex = 23, Clip = true, Parent = page })
		Kit.text({
			Text = step.Japanese,
			Font = Theme.Fonts.Heavy,
			Color = C.PaperDark,
			Size = UDim2.fromScale(0.6, 0.6),
			Position = UDim2.fromScale(0.98, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			Rotation = -6,
			ZIndex = 23,
			Parent = panel,
		})
		Kit.text({
			Text = step.Title,
			Color = C.Red,
			Stroke = C.Ink,
			StrokeThickness = 3,
			Size = UDim2.new(1, -40, 0, 70),
			Position = UDim2.fromOffset(20, 20),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 24,
			Parent = panel,
		})
		Kit.text({
			Text = step.Body,
			Font = Theme.Fonts.Body,
			Size = UDim2.new(0.62, 0, 0, 180),
			Position = UDim2.fromOffset(24, 110),
			AlignX = Enum.TextXAlignment.Left,
			AlignY = Enum.TextYAlignment.Top,
			MaxSize = 26,
			ZIndex = 24,
			Parent = panel,
		})
		local keys = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.62, 0, 0, 200),
			Position = UDim2.fromOffset(24, 310),
			ZIndex = 24,
			Parent = panel,
		})
		Kit.list(keys, 10)
		for order, key in step.Keys do
			local chip = Kit.new("Frame", {
				BackgroundColor3 = C.Ink,
				Size = UDim2.fromOffset(420, 40),
				LayoutOrder = order,
				ZIndex = 25,
				Parent = keys,
			})
			Kit.text({
				Text = key,
				Font = Theme.Fonts.Body,
				Color = C.Yellow,
				Size = UDim2.new(1, -20, 1, -10),
				Position = UDim2.fromOffset(10, 5),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 26,
				Parent = chip,
			})
		end
		counter.Text = `{index} / {#Tutorial}`
		previous.SetEnabled(index > 1)
		nextButton.SetText(if index == #Tutorial then "TERMINER" else "SUIVANT ▶")
		Kit.pop(panel.Parent :: GuiObject, 0.94)
	end

	previous = Kit.button({
		Text = "◀ PRÉCÉDENT",
		Color = C.PaperDark,
		Size = UDim2.fromOffset(240, 60),
		Position = UDim2.new(0, 0, 1, -64),
		ZIndex = 23,
		Parent = content,
		OnClick = function()
			index = math.max(1, index - 1)
			render()
		end,
	})
	nextButton = Kit.button({
		Text = "SUIVANT ▶",
		Color = C.Yellow,
		Size = UDim2.fromOffset(240, 60),
		Position = UDim2.new(1, -240, 1, -64),
		ZIndex = 23,
		Parent = content,
		OnClick = function()
			if index == #Tutorial then
				State.request("ProfileAction", "CompleteTutorial")
				close()
				index = 1
				render()
				return
			end
			index += 1
			render()
		end,
	})
	render()
	return screen
end

return TutorialScreen
