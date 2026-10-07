-- Built-in material textures and drawn costume surfaces need no uploaded IDs.
local Style = {}
local function child(parent, className, name)
	local object = parent:FindFirstChild(name)
	if not object then
		object = Instance.new(className); object.Name = name; object.Parent = parent
	else assert(object:IsA(className), name .. " has an unexpected type") end
	return object
end
local function canvas(part, name, background)
	local gui = child(part, "SurfaceGui", name)
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 0.35; gui.AlwaysOnTop = false; gui.MaxDistance = 85
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = child(gui, "Frame", "Canvas")
	root.Size = UDim2.new(1, 0, 1, 0); root.BackgroundColor3 = background
	root.BorderSizePixel = 0; root.ClipsDescendants = true
	return root
end
local function rectangle(root, name, x, y, width, height, color, rotation)
	local frame = child(root, "Frame", name)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0, math.round(x), 0, math.round(y))
	frame.Size = UDim2.new(0, math.round(width), 0, math.round(height))
	frame.BackgroundColor3 = color; frame.BorderSizePixel = 0; frame.Rotation = rotation or 0
	-- Explicit layers preserve the drawing when Rojo sorts saved GUI children.
	frame.ZIndex = 2
	if string.find(name, "EyeOutline") or string.find(name, "EyeShadow") or name == "ReactorRim"
		or string.find(name, "Spider") or string.find(name, "LegA") or string.find(name, "LegB") then frame.ZIndex = 3 end
	if name == "Eye" or string.match(name, "^Eye%-?%d") or string.find(name, "EyeGlow") or name == "ReactorGlow" then frame.ZIndex = 4 end
	if string.find(name, "Pupil") or name == "ReactorCore" or name == "Teeth" then frame.ZIndex = 5 end
	return frame
end
local function circle(root, name, x, y, diameter, color)
	local frame = rectangle(root, name, x, y, diameter, diameter, color)
	child(frame, "UICorner", "Round").CornerRadius = UDim.new(1, 0)
	return frame
end
local function line(root, name, x1, y1, x2, y2, width, color)
	local dx, dy = x2 - x1, y2 - y1
	return rectangle(root, name, (x1 + x2) / 2, (y1 + y2) / 2,
		math.sqrt(dx * dx + dy * dy), width, color, math.deg(math.atan2(dy, dx)))
end
local BLACK = Color3.fromRGB(18, 22, 30)
local WHITE = Color3.fromRGB(245, 247, 239)
local RED = Color3.fromRGB(184, 36, 40)
local GOLD = Color3.fromRGB(223, 177, 74)
local BLUE = Color3.fromRGB(29, 64, 132)
local GREEN = Color3.fromRGB(100, 166, 67)
local CYAN = Color3.fromRGB(152, 242, 255)
local function fabric(root, base)
	-- Тонкое переплетение и швы рисуются в самом файле, без внешних asset ID.
	for index = 1, 15 do
		local stitch = rectangle(root, "WeaveV" .. index, index * 17, 128, 1, 256, base)
		stitch.BackgroundTransparency = 0.86
		local cross = rectangle(root, "WeaveH" .. index, 128, index * 17, 256, 1, base)
		cross.BackgroundTransparency = 0.86
	end
	for _, side in ipairs({-1, 1}) do
		local seam = line(root, "Seam" .. side, 128 + side * 99, 0, 128 + side * 77, 256, 2, WHITE)
		seam.BackgroundTransparency = 0.78
	end
end
function Style.Face(part, kind)
	local color = if kind == "spider" then RED elseif kind == "symbiote" then BLACK
		elseif kind == "iron" or kind == "iron_gold" then GOLD elseif kind == "hulk" then GREEN
		else Color3.fromRGB(218, 174, 137)
	local root = canvas(part, "CostumeFace", color)
	if kind == "spider" or kind == "symbiote" then fabric(root, WHITE) end
	if kind == "spider" or kind == "symbiote" then
		local web = if kind == "spider" then BLACK else Color3.fromRGB(78, 82, 94)
		for index = 1, 5 do
			line(root, "WebH" .. index, 0, index * 42, 256, index * 42, 2, web)
			line(root, "WebV" .. index, index * 42, 0, index * 42, 256, 2, web)
		end
		line(root, "WebDiagonalA", 0, 0, 256, 256, 3, web)
		line(root, "WebDiagonalB", 256, 0, 0, 256, 3, web)
		for _, side in ipairs({ -1, 1 }) do
			local x = 128 + side * 67
			rectangle(root, "EyeOutline" .. side, x, 109, 102, 66, BLACK, side * -20)
			rectangle(root, "Eye" .. side, x, 107, 82, 43, WHITE, side * -20)
		end
	elseif kind == "iron" or kind == "iron_gold" then
		rectangle(root, "HelmetTop", 128, 22, 256, 43, RED)
		for _, side in ipairs({ -1, 1 }) do
			rectangle(root, "HelmetSide" .. side, 128 + side * 116, 134, 33, 250, RED)
			rectangle(root, "EyeShadow" .. side, 128 + side * 59, 113, 85, 23, BLACK, side * -9)
			rectangle(root, "EyeGlow" .. side, 128 + side * 59, 110, 73, 12, CYAN, side * -9)
		end
		line(root, "NoseLeft", 113, 117, 107, 173, 4, Color3.fromRGB(165, 127, 49))
		line(root, "NoseRight", 143, 117, 149, 173, 4, Color3.fromRGB(165, 127, 49))
		rectangle(root, "Mouth", 128, 193, 72, 8, BLACK)
		rectangle(root, "Chin", 128, 240, 158, 33, RED)
	else
		rectangle(root, "Hair", 128, 17, 256, 49, if kind == "thor" then GOLD else BLACK)
		for _, side in ipairs({ -1, 1 }) do
			rectangle(root, "Brow" .. side, 128 + side * 58, 80, 79, 14, BLACK, side * 12)
			rectangle(root, "Eye" .. side, 128 + side * 56, 106, 53, 24, WHITE)
			circle(root, "Pupil" .. side, 128 + side * 51, 107, 15, BLACK)
		end
		rectangle(root, "Nose", 128, 141, 18, 28, if kind == "hulk" then Color3.fromRGB(65, 117, 41) else Color3.fromRGB(176, 124, 91))
		rectangle(root, "Mouth", 128, 191, 92, 21, BLACK)
		rectangle(root, "Teeth", 128, 184, 78, 10, WHITE)
		if kind == "thor" then rectangle(root, "Beard", 128, 224, 165, 65, Color3.fromRGB(155, 111, 47)) end
	end
end
function Style.Chest(part, kind)
	local color = if kind == "symbiote" then BLACK elseif kind == "hulk" then GREEN
		elseif kind == "thor" then Color3.fromRGB(54, 62, 72) elseif kind == "iron_gold" then GOLD else RED
	local root = canvas(part, "CostumeChest", color)
	if kind == "spider" or kind == "symbiote" or kind == "thor" then fabric(root, WHITE) end
	if kind == "spider" or kind == "symbiote" then
		local emblem = if kind == "symbiote" then WHITE else BLACK
		if kind == "spider" then
			rectangle(root, "SideLeft", 13, 128, 26, 256, BLUE)
			rectangle(root, "SideRight", 243, 128, 26, 256, BLUE)
			for index = 1, 5 do
				line(root, "FabricH" .. index, 26, index * 43, 230, index * 43, 2, BLACK)
				line(root, "FabricV" .. index, index * 42, 0, index * 42, 256, 2, BLACK)
			end
		end
		circle(root, "SpiderHead", 128, 85, 28, emblem)
		rectangle(root, "SpiderBody", 128, 122, 29, 63, emblem)
		for leg = 1, 4 do
			for _, side in ipairs({ -1, 1 }) do
				local id = leg .. "_" .. side; local y = 75 + leg * 17
				line(root, "LegA" .. id, 128, y, 128 + side * 53, y - 14, 7, emblem)
				line(root, "LegB" .. id, 128 + side * 53, y - 14, 128 + side * 72, y + (leg - 2) * 18, 7, emblem)
			end
		end
	elseif kind == "iron" or kind == "iron_gold" then
		for row = 1, 4 do
			for _, side in ipairs({-1, 1}) do
				local panel = rectangle(root, "ArmorSegment" .. row .. "_" .. side, 128 + side * 100, 36 + row * 43, 36, 35, Color3.fromRGB(132, 25, 30), side * 8)
				panel.BackgroundTransparency = 0.25
				circle(root, "Rivet" .. row .. "_" .. side, 128 + side * 99, 33 + row * 43, 5, GOLD)
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			rectangle(root, "ChestPlate" .. side, 128 + side * 86, 69, 71, 101, GOLD, side * 12)
			line(root, "Panel" .. side, 128 + side * 104, 162, 128 + side * 76, 232, 8, BLACK)
		end
		circle(root, "ReactorRim", 128, 104, 88, BLACK)
		circle(root, "ReactorGlow", 128, 104, 68, CYAN)
		circle(root, "ReactorCore", 128, 104, 44, WHITE)
		for row = 1, 3 do rectangle(root, "Abs" .. row, 128, 157 + row * 24, 97, 13, GOLD) end
	elseif kind == "hulk" then
		local shadow = Color3.fromRGB(70, 129, 44)
		line(root, "PecsLeft", 21, 70, 113, 101, 7, shadow)
		line(root, "PecsRight", 235, 70, 143, 101, 7, shadow)
		line(root, "Center", 128, 74, 128, 239, 6, shadow)
		for row = 1, 3 do line(root, "Abs" .. row, 83, 132 + row * 30, 173, 132 + row * 30, 5, shadow) end
	else
		for row = 1, 3 do
			for _, side in ipairs({ -1, 1 }) do
				circle(root, "ArmorDisc" .. row .. side, 128 + side * 68, 40 + row * 47, 42, Color3.fromRGB(163, 177, 194))
			end
		end
		rectangle(root, "Belt", 128, 227, 256, 28, GOLD)
	end
end
function Style.Material(object)
	local name = object.Name
	if string.find(name, "Wall") or string.find(name, "FrontLeft") or string.find(name, "FrontRight")
		or string.find(name, "RearLeft") or string.find(name, "RearRight") or string.find(name, "RearMiddle") then
		object.Material = Enum.Material.Brick
	elseif string.match(name, "Path$") or string.match(name, "^HouseRoad") or string.match(name, "^HouseEntry") then object.Material = Enum.Material.Asphalt
	elseif name == "Plaza" or name == "FrontWalk" or name == "Foundation" or name == "Pedestal" then
		object.Material = Enum.Material.Cobblestone
	elseif name == "MachineBack" or name == "MachineBase" or name == "MachineTop" or name == "Crate" then
		object.Material = Enum.Material.DiamondPlate
	end
end
return Style
