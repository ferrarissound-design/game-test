local DogAppearance = {}

local DOG_FUR = Color3.fromRGB(151, 98, 55)
local DOG_LIGHT_FUR = Color3.fromRGB(205, 151, 91)
local DOG_DARK_FUR = Color3.fromRGB(91, 55, 34)
local DOG_FACE = Color3.fromRGB(30, 25, 23)
local DOG_COLLAR = Color3.fromRGB(205, 48, 48)

local function addDogPart(parent, dogCFrame, name, size, offset, color, shape, rotation)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.CFrame = dogCFrame
		* CFrame.new(offset.X, offset.Y, -offset.Z)
		* (rotation or CFrame.new())
	part.Parent = parent
	return part
end

-- Builds the dog entirely from lightweight Parts. Local offsets use X = right,
-- Y = up, and Z = forward so the silhouette can face the player or front door.
function DogAppearance.create(parent, groundPosition, lookTarget)
	local flatDirection = Vector3.new(
		lookTarget.X - groundPosition.X,
		0,
		lookTarget.Z - groundPosition.Z
	)
	if flatDirection.Magnitude < 0.1 then
		flatDirection = Vector3.new(-1, 0, 0)
	end

	local dogCFrame = CFrame.lookAt(groundPosition, groundPosition + flatDirection.Unit)
	local dogModel = Instance.new("Model")
	dogModel.Name = "Dog"
	dogModel.Parent = parent

	local function add(name, size, offset, color, shape, rotation)
		return addDogPart(dogModel, dogCFrame, name, size, offset, color, shape, rotation)
	end

	-- A broad body, raised head, four separated legs, and an upright tail make
	-- the animal read as a dog even from a distance and in a dark environment.
	local body = add("Body", Vector3.new(1.15, 1.15, 2.25), Vector3.new(0, 1.15, 0), DOG_FUR)
	add("Chest", Vector3.new(0.9, 1.0, 0.55), Vector3.new(0, 1.18, 0.88), DOG_LIGHT_FUR)
	add("Head", Vector3.new(1.15, 1.15, 1.05), Vector3.new(0, 1.75, 1.15), DOG_FUR, Enum.PartType.Ball)
	add("Muzzle", Vector3.new(0.72, 0.55, 0.65), Vector3.new(0, 1.55, 1.64), DOG_LIGHT_FUR, Enum.PartType.Ball)

	for _, side in ipairs({-1, 1}) do
		add(
			"Ear",
			Vector3.new(0.34, 0.72, 0.3),
			Vector3.new(side * 0.48, 1.96, 1.12),
			DOG_DARK_FUR,
			nil,
			CFrame.Angles(0, 0, math.rad(side * 16))
		)
		add("Eye", Vector3.new(0.18, 0.18, 0.18), Vector3.new(side * 0.28, 1.88, 1.63), DOG_FACE, Enum.PartType.Ball)
	end
	add("Nose", Vector3.new(0.28, 0.24, 0.22), Vector3.new(0, 1.63, 1.98), DOG_FACE, Enum.PartType.Ball)
	add("Mouth", Vector3.new(0.34, 0.12, 0.12), Vector3.new(0, 1.41, 1.93), DOG_FACE)

	for _, offset in ipairs({
		Vector3.new(-0.39, 0.52, -0.68),
		Vector3.new(0.39, 0.52, -0.68),
		Vector3.new(-0.39, 0.52, 0.68),
		Vector3.new(0.39, 0.52, 0.68),
	}) do
		add("Leg", Vector3.new(0.3, 0.82, 0.34), offset, DOG_DARK_FUR)
		add("Paw", Vector3.new(0.38, 0.2, 0.48), offset + Vector3.new(0, -0.43, 0.08), DOG_DARK_FUR)
	end

	add("Collar", Vector3.new(1.05, 0.25, 0.3), Vector3.new(0, 1.48, 0.73), DOG_COLLAR)
	add("TailLower", Vector3.new(0.3, 0.3, 0.95), Vector3.new(0, 1.38, -1.38), DOG_FUR, nil, CFrame.Angles(math.rad(-32), 0, 0))
	add("TailTip", Vector3.new(0.26, 0.26, 0.72), Vector3.new(0, 1.82, -1.72), DOG_DARK_FUR, nil, CFrame.Angles(math.rad(-52), 0, 0))

	dogModel.PrimaryPart = body
	return dogModel, body
end

return DogAppearance
