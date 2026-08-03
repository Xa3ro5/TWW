local env = (getgenv and getgenv()) or _G
env.TWW = env.TWW or {}
local TWW = env.TWW

if TWW._espLoaded then
    return
end
TWW._espLoaded = true

local Services = TWW.Services
if not Services then
    Services = {
        ["Players"] = game:GetService("Players"),
        ["Workspace"] = game:GetService("Workspace"),
        ["RunService"] = game:GetService("RunService"),
        ["CoreGui"] = game:GetService("CoreGui"),
        ["GuiService"] = game:GetService("GuiService"),
        ["PathfindingService"] = game:GetService("PathfindingService"),
        ["Lighting"] = game:GetService("Lighting"),
        ["ReplicatedStorage"] = game:GetService("ReplicatedStorage"),
        ["SoundService"] = game:GetService("SoundService"),
        ["UserInputService"] = game:GetService("UserInputService"),
        ["VirtualInputManager"] = nil,
    }
    TWW.Services = Services
end

pcall(function()
    if Services.VirtualInputManager == nil then
        Services.VirtualInputManager = game:GetService("VirtualInputManager")
    end
end)

local LocalPlayer = TWW.LocalPlayer or Services.Players.LocalPlayer
TWW.LocalPlayer = LocalPlayer

local ESPFolder = Services.Workspace:FindFirstChild("SmugESPFolder")
if not ESPFolder then
    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "SmugESPFolder"
    ESPFolder.Parent = Services.Workspace
else
    ESPFolder:ClearAllChildren()
end

local PathFolder = Instance.new("Folder")
PathFolder.Name = "SmugESPPathFolder"
PathFolder.Parent = ESPFolder

local Const = {}

Const.ANIMAL_MAX_HEALTH = {
    Bear = 300,
    Deer = 50,
    Gator = 300,
    Capybara = 250,
    Bison = 150,
}

Const.ORE_PATH_UPDATE_INTERVAL = 0.12
Const.ORE_PATH_WAYPOINT_SPACING = 4
Const.ORE_PATH_REPATH_DISTANCE = 2.5
Const.ORE_PATH_COLOR = Color3.fromRGB(255, 170, 0)
Const.ORE_PATH_POINT_SIZE = 0.45

local labelEntries = {}
local rainbowHighlights = {}

local function registerLabel(label, adornee, baseText, distanceLabel)
    if not label then
        return
    end
    labelEntries[label] = {
        adornee = adornee,
        baseText = baseText or "",
        distanceLabel = distanceLabel,
    }
end

local function updateLabelEntry(label, adornee, baseText)
    local entry = labelEntries[label]
    if not entry then
        return
    end
    if adornee then
        entry.adornee = adornee
    end
    if baseText then
        entry.baseText = baseText
    end
end

local function unregisterLabel(label)
    labelEntries[label] = nil
end

local function createBillboard(adornee, baseText, color, opts)
    if not adornee then
        return nil, nil
    end

    opts = opts or {}
    local showDistance = opts.DistanceLabel == true
    local distanceTextSize = opts.DistanceTextSize or 12

    local bb = Instance.new("BillboardGui")
    bb.Name = "SmugESP_Label"
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 160, 0, showDistance and 36 or 24)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ESPFolder

    local label = Instance.new("TextLabel")
    label.Size = showDistance and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Text = baseText or ""
    label.Parent = bb

    local distanceLabel = nil
    if showDistance then
        distanceLabel = Instance.new("TextLabel")
        distanceLabel.Size = UDim2.new(1, 0, 0, 16)
        distanceLabel.Position = UDim2.new(0, 0, 0, 18)
        distanceLabel.BackgroundTransparency = 1
        distanceLabel.TextColor3 = color or Color3.new(1, 1, 1)
        distanceLabel.TextStrokeTransparency = 0.45
        distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        distanceLabel.Font = Enum.Font.Gotham
        distanceLabel.TextSize = distanceTextSize
        distanceLabel.Text = ""
        distanceLabel.Parent = bb
    end

    registerLabel(label, adornee, baseText or "", distanceLabel)
    return bb, label, distanceLabel
end

local function destroyLabel(entry)
    if entry and entry.label then
        unregisterLabel(entry.label)
    end
    if entry and entry.labelGui then
        entry.labelGui:Destroy()
    end
end

local function cleanupConnections(connList)
    if not connList then
        return
    end
    for _, conn in ipairs(connList) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(connList)
end

local function createHighlight(parent, adornee, name, fillColor, outlineColor, fillTransparency)
    if not parent or not adornee then
        return nil
    end
    local hl = Instance.new("Highlight")
    hl.Name = name
    hl.Adornee = adornee
    hl.FillColor = fillColor
    hl.OutlineColor = outlineColor or fillColor
    hl.FillTransparency = fillTransparency or 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = parent
    return hl
end

local function getEntitiesFolder()
    return Services.Workspace:FindFirstChild("WORKSPACE_Entities")
end

local function getPlayersFolder()
    local entities = getEntitiesFolder()
    return entities and entities:FindFirstChild("Players") or nil
end

local function getNpcFolder()
    local entities = getEntitiesFolder()
    return entities and entities:FindFirstChild("NPCs") or nil
end

local function getGeometryFolder()
    return Services.Workspace:FindFirstChild("WORKSPACE_Geometry")
end

local function getTrainsFolder()
    local trains = Services.Workspace:FindFirstChild("WORKSPACE_Trains")
    return trains and trains:FindFirstChild("RunningTrains") or nil
end

local function getFortsFolder()
    local geometry = getGeometryFolder()
    return geometry and geometry:FindFirstChild("FORTS") or nil
end

local function getLocalPlayerModel()
    local playersFolder = getPlayersFolder()
    return playersFolder and playersFolder:FindFirstChild(LocalPlayer.Name) or nil
end

local getLocalHumanoid

local function getLocalRootPart()
    local humanoid = getLocalHumanoid()
    local model = humanoid and humanoid.Parent or nil
    if model then
        local root = model:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            return root
        end
    end
    local character = LocalPlayer.Character
    if character then
        local charRoot = character:FindFirstChild("HumanoidRootPart")
        if charRoot and charRoot:IsA("BasePart") then
            return charRoot
        end
    end
    local fallback = getLocalPlayerModel()
    local root = fallback and fallback:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

getLocalHumanoid = function()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid
        end
    end
    local model = getLocalPlayerModel()
    if model then
        return model:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function getModelPart(model)
    if not model then
        return nil
    end
    if model:IsA("BasePart") then
        return model
    end
    if not model:IsA("Model") then
        return nil
    end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

local function getAnimalHead(model)
    if not model then
        return nil
    end
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    return getModelPart(model)
end

local function getAnimalLabelPart(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return getAnimalHead(model)
end

local function getAnimalHealth(model)
    if not model then
        return nil
    end
    local healthValue = model:FindFirstChild("Health")
    if healthValue and healthValue:IsA("ValueBase") then
        return tonumber(healthValue.Value)
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health
    end
    return nil
end

local function nameMatchesFilter(modelName, filterName)
    local modelLower = tostring(modelName or ""):lower()
    local filterLower = tostring(filterName or ""):lower()
    if filterLower == "" then
        return false
    end
    return modelLower:find(filterLower, 1, true) ~= nil
end

local animalState

local function isExcludedAnimal(model)
    if not model then
        return false
    end
    if not animalState or not animalState.exclusions then
        return false
    end
    for filterName, excluded in pairs(animalState.exclusions) do
        if excluded and nameMatchesFilter(model.Name, filterName) then
            return true
        end
    end
    return false
end

local function formatAnimalLabel(model)
    if not model then
        return ""
    end
    local name = tostring(model.Name or "Animal")
    local health = getAnimalHealth(model)
    if not health then
        return name
    end
    local rounded = math.floor(health + 0.5)
    local expected = Const.ANIMAL_MAX_HEALTH[model.Name]
    if expected then
        return string.format("%s [%d/%d]", name, rounded, expected)
    end
    return string.format("%s [%d]", name, rounded)
end

local function isAnimalDead(model)
    if not model or not model.Parent then
        return true
    end
    local health = getAnimalHealth(model)
    if health and health <= 0 then
        return true
    end
    local entities = getEntitiesFolder()
    local deadFolder = entities and entities:FindFirstChild("DeadAnimals") or nil
    if deadFolder and model.Parent == deadFolder then
        return true
    end
    return false
end

animalState = {
    enabled = false,
    entries = {},
    conns = {},
    exclusions = {
        Horse = true,
    },
}

local droppedState = {
    enabled = false,
    entries = {},
    conns = {},
}

local playerEspState = {
    enabled = false,
    entries = {},
    conns = {},
}

local npcState = {
    enabled = false,
    entries = {},
    conns = {},
}

local treeState = {
    enabled = false,
    selections = {},
    entries = {},
    rootsByType = {},
    conns = {},
    checkboxTab = nil,
    checkboxCreated = {},
}

local trainState = {
    enabled = false,
    entries = {},
    conns = {},
}

local fortState = {
    enabled = false,
    entries = {},
    conns = {},
}

local oreState = {
    enabled = false,
    selections = {},
    entries = {},
    folderConns = {},
    oreFolders = {},
    pathByOre = {},
}

local function getPlayerLabelPart(model)
    if not model then
        return nil
    end
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    return getModelPart(model)
end

local function formatPlayerLabel(model)
    if not model then
        return ""
    end
    local name = tostring(model.Name or "Player")
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return string.format("%s [%.0f/%.0f]", name, humanoid.Health, humanoid.MaxHealth)
    end
    return name
end

local function removePlayerEsp(model)
    local entry = playerEspState.entries[model]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    if entry.highlight then
        entry.highlight:Destroy()
    end
    destroyLabel(entry)
    playerEspState.entries[model] = nil
end

local function updatePlayerEntry(entry)
    if not entry or not entry.model or not playerEspState.enabled then
        return
    end
    if not entry.model.Parent then
        removePlayerEsp(entry.model)
        return
    end

    if not entry.highlight or not entry.highlight.Parent then
        entry.highlight = createHighlight(
            entry.model,
            entry.model,
            "SmugESP_Player",
            Color3.fromRGB(0, 170, 255),
            Color3.fromRGB(0, 170, 255),
            0.15
        )
    else
        entry.highlight.Adornee = entry.model
    end

    local labelPart = getPlayerLabelPart(entry.model)
    if labelPart then
        local baseText = formatPlayerLabel(entry.model)
        if not entry.labelGui or not entry.labelGui.Parent then
            entry.labelGui, entry.label, entry.distanceLabel = createBillboard(
                labelPart,
                baseText,
                Color3.new(1, 1, 1),
                { DistanceLabel = true, DistanceTextSize = 12 }
            )
        else
            entry.labelGui.Adornee = labelPart
            updateLabelEntry(entry.label, labelPart, baseText)
        end
    end
end

local function addPlayerEsp(model)
    if not playerEspState.enabled or not model or not model:IsA("Model") then
        return
    end
    if model.Name == LocalPlayer.Name then
        return
    end
    if playerEspState.entries[model] then
        return
    end

    local entry = {
        model = model,
        conns = {},
    }
    playerEspState.entries[model] = entry

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(entry.conns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            updatePlayerEntry(entry)
        end))
        table.insert(entry.conns, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            updatePlayerEntry(entry)
        end))
    end

    table.insert(entry.conns, model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removePlayerEsp(model)
        end
    end))
    table.insert(entry.conns, model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
        updatePlayerEntry(entry)
    end))

    updatePlayerEntry(entry)
end

local function clearPlayerEsp()
    for model in pairs(playerEspState.entries) do
        removePlayerEsp(model)
    end
    playerEspState.entries = {}
    cleanupConnections(playerEspState.conns)
end

local function enablePlayerEsp(state)
    playerEspState.enabled = state
    clearPlayerEsp()
    if not state then
        return
    end

    local playersFolder = getPlayersFolder()
    if not playersFolder then
        return
    end

    table.insert(playerEspState.conns, playersFolder.ChildAdded:Connect(function(child)
        addPlayerEsp(child)
    end))
    table.insert(playerEspState.conns, playersFolder.ChildRemoved:Connect(function(child)
        removePlayerEsp(child)
    end))

    for _, model in ipairs(playersFolder:GetChildren()) do
        addPlayerEsp(model)
    end
end

local function findDescendantPart(model, name)
    if not model then
        return nil
    end
    local part = model:FindFirstChild(name, true)
    if part and part:IsA("BasePart") then
        return part
    end
    return nil
end

local function findHumanoid(model)
    if not model then
        return nil
    end
    return model:FindFirstChildOfClass("Humanoid", true)
end

local function findHealthValue(model)
    if not model then
        return nil
    end
    local value = model:FindFirstChild("Health", true)
    if value and value:IsA("ValueBase") then
        return value
    end
    return nil
end

local function resolveNpcModel(container)
    if not container then
        return nil
    end
    if container:IsA("Model") then
        local hum = findHumanoid(container)
        if hum then
            return container
        end
    end
    local direct = container:FindFirstChild("Model")
    if direct and direct:IsA("Model") then
        return direct
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") then
            local hum = findHumanoid(child)
            if hum then
                return child
            end
        end
    end
    return nil
end

local function getNpcLabelPart(model)
    if not model then
        return nil
    end
    local head = findDescendantPart(model, "Head")
    if head then
        return head
    end
    local root = findDescendantPart(model, "HumanoidRootPart")
    if root then
        return root
    end
    return getModelPart(model)
end

local function getNpcDisplayName(entry)
    if entry and entry.container and entry.container.Name then
        return entry.container.Name
    end
    if entry and entry.model and entry.model.Name then
        return entry.model.Name
    end
    return "NPC"
end

local function formatNpcLabel(entry)
    local model = entry and entry.model
    local name = getNpcDisplayName(entry)
    local humanoid = findHumanoid(model)
    if humanoid then
        return string.format("%s [%.0f/%.0f]", name, humanoid.Health, humanoid.MaxHealth)
    end
    local healthValue = findHealthValue(model)
    if healthValue then
        local value = tonumber(healthValue.Value)
        if value then
            return string.format("%s [%.0f]", name, value)
        end
    end
    return name
end

local function removeNpcEsp(container)
    local entry = npcState.entries[container]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    cleanupConnections(entry.modelConns)
    if entry.highlight then
        entry.highlight:Destroy()
    end
    destroyLabel(entry)
    npcState.entries[container] = nil
end

local function updateNpcEntry(entry)
    if not entry or not npcState.enabled then
        return
    end
    if not entry.container or not entry.container.Parent then
        removeNpcEsp(entry.container)
        return
    end

    local model = resolveNpcModel(entry.container)
    if model ~= entry.model then
        cleanupConnections(entry.modelConns)
        entry.modelConns = {}
        if entry.highlight then
            entry.highlight:Destroy()
            entry.highlight = nil
        end
        destroyLabel(entry)
        entry.model = model
        if model then
            local humanoid = findHumanoid(model)
            if humanoid then
                table.insert(entry.modelConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                    updateNpcEntry(entry)
                end))
                table.insert(entry.modelConns, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
                    updateNpcEntry(entry)
                end))
            end
            local healthValue = findHealthValue(model)
            if healthValue then
                table.insert(entry.modelConns, healthValue.Changed:Connect(function()
                    updateNpcEntry(entry)
                end))
            end
            table.insert(entry.modelConns, model.AncestryChanged:Connect(function()
                updateNpcEntry(entry)
            end))
            table.insert(entry.modelConns, model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
                updateNpcEntry(entry)
            end))
        end
    end

    if not entry.model then
        return
    end

    if not entry.highlight or not entry.highlight.Parent then
        entry.highlight = createHighlight(
            entry.model,
            entry.model,
            "SmugESP_NPC",
            Color3.fromRGB(255, 140, 0),
            Color3.fromRGB(255, 140, 0),
            0.2
        )
    else
        entry.highlight.Adornee = entry.model
    end

    local labelPart = getNpcLabelPart(entry.model)
    if labelPart then
        local baseText = formatNpcLabel(entry)
        if not entry.labelGui or not entry.labelGui.Parent then
            entry.labelGui, entry.label, entry.distanceLabel = createBillboard(
                labelPart,
                baseText,
                Color3.new(1, 1, 1),
                { DistanceLabel = true, DistanceTextSize = 12 }
            )
        else
            entry.labelGui.Adornee = labelPart
            updateLabelEntry(entry.label, labelPart, baseText)
        end
    end
end

local function addNpcEsp(container)
    if not npcState.enabled or not container then
        return
    end
    if npcState.entries[container] then
        return
    end

    local entry = {
        container = container,
        model = nil,
        conns = {},
        modelConns = {},
    }
    npcState.entries[container] = entry

    table.insert(entry.conns, container.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeNpcEsp(container)
        end
    end))
    table.insert(entry.conns, container.ChildAdded:Connect(function()
        updateNpcEntry(entry)
    end))
    table.insert(entry.conns, container.ChildRemoved:Connect(function()
        updateNpcEntry(entry)
    end))

    updateNpcEntry(entry)
end

local function clearNpcEsp()
    for container in pairs(npcState.entries) do
        removeNpcEsp(container)
    end
    npcState.entries = {}
    cleanupConnections(npcState.conns)
end

local function enableNpcEsp(state)
    npcState.enabled = state
    clearNpcEsp()
    if not state then
        return
    end

    local npcFolder = getNpcFolder()
    if not npcFolder then
        return
    end

    table.insert(npcState.conns, npcFolder.ChildAdded:Connect(function(child)
        addNpcEsp(child)
    end))
    table.insert(npcState.conns, npcFolder.ChildRemoved:Connect(function(child)
        removeNpcEsp(child)
    end))

    for _, model in ipairs(npcFolder:GetChildren()) do
        addNpcEsp(model)
    end
end

local function removeRainbow(entry)
    if entry and entry.rainbowHighlight then
        rainbowHighlights[entry.rainbowHighlight] = nil
        entry.rainbowHighlight:Destroy()
        entry.rainbowHighlight = nil
    end
end

local removeAnimal

local function updateAnimalEntry(entry)
    if not entry or not entry.model then
        return
    end
    if not animalState.enabled then
        return
    end

    if isExcludedAnimal(entry.model) then
        removeAnimal(entry.model)
        return
    end

    if isAnimalDead(entry.model) then
        removeAnimal(entry.model)
        return
    end

    if not entry.headHighlight or not entry.headHighlight.Parent then
        local head = getAnimalHead(entry.model)
        if head then
            entry.headHighlight = createHighlight(
                head,
                head,
                "SmugESP_AnimalHead",
                Color3.fromRGB(255, 255, 0),
                Color3.fromRGB(255, 255, 0),
                0.4
            )
        end
    end

    local labelPart = getAnimalLabelPart(entry.model)
    if labelPart then
        local baseText = formatAnimalLabel(entry.model)
        if not entry.labelGui or not entry.labelGui.Parent then
            entry.labelGui, entry.label, entry.distanceLabel = createBillboard(
                labelPart,
                baseText,
                Color3.new(1, 1, 1),
                { DistanceLabel = true, DistanceTextSize = 12 }
            )
        else
            entry.labelGui.Adornee = labelPart
            updateLabelEntry(entry.label, labelPart, baseText)
        end
    end

    local expected = Const.ANIMAL_MAX_HEALTH[entry.model.Name]
    local health = getAnimalHealth(entry.model)
    local shouldRainbow = expected and health and health > expected
    if shouldRainbow then
        if not entry.rainbowHighlight or not entry.rainbowHighlight.Parent then
            entry.rainbowHighlight = createHighlight(
                entry.model,
                entry.model,
                "SmugESP_AnimalRainbow",
                Color3.fromRGB(255, 0, 0),
                Color3.fromRGB(255, 0, 0),
                0.2
            )
            if entry.rainbowHighlight then
                rainbowHighlights[entry.rainbowHighlight] = true
            end
        end
    else
        removeRainbow(entry)
    end
end

removeAnimal = function(model)
    local entry = animalState.entries[model]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    if entry.headHighlight then
        entry.headHighlight:Destroy()
    end
    removeRainbow(entry)
    destroyLabel(entry)
    animalState.entries[model] = nil
end

local function addAnimal(model)
    if not animalState.enabled or not model or not model:IsA("Model") then
        return
    end
    if isExcludedAnimal(model) then
        return
    end
    if animalState.entries[model] then
        return
    end

    local entry = {
        model = model,
        conns = {},
    }

    local healthValue = model:FindFirstChild("Health")
    if healthValue and healthValue:IsA("ValueBase") then
        table.insert(entry.conns, healthValue.Changed:Connect(function()
            if isAnimalDead(model) then
                removeAnimal(model)
            else
                updateAnimalEntry(entry)
            end
        end))
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(entry.conns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if isAnimalDead(model) then
                removeAnimal(model)
            else
                updateAnimalEntry(entry)
            end
        end))
    end

    table.insert(entry.conns, model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeAnimal(model)
        end
    end))

    animalState.entries[model] = entry
    updateAnimalEntry(entry)
end

local function clearAnimals()
    local models = {}
    for model in pairs(animalState.entries) do
        table.insert(models, model)
    end
    for _, model in ipairs(models) do
        removeAnimal(model)
    end
    animalState.entries = {}
    cleanupConnections(animalState.conns)
end

local function enableAnimals(state)
    animalState.enabled = state
    clearAnimals()
    if not state then
        return
    end

    local entities = getEntitiesFolder()
    local animalsFolder = entities and entities:FindFirstChild("Animals") or nil
    if not animalsFolder then
        return
    end

    table.insert(animalState.conns, animalsFolder.ChildAdded:Connect(addAnimal))
    table.insert(animalState.conns, animalsFolder.ChildRemoved:Connect(removeAnimal))

    for _, model in ipairs(animalsFolder:GetChildren()) do
        addAnimal(model)
    end
end

local function setAnimalExcluded(filterName, state)
    animalState.exclusions[filterName] = state or nil
    if state then
        for model in pairs(animalState.entries) do
            if model and nameMatchesFilter(model.Name, filterName) then
                removeAnimal(model)
            end
        end
        return
    end

    if not animalState.enabled then
        return
    end
    local entities = getEntitiesFolder()
    local animalsFolder = entities and entities:FindFirstChild("Animals") or nil
    if not animalsFolder then
        return
    end
    for _, model in ipairs(animalsFolder:GetChildren()) do
        if nameMatchesFilter(model.Name, filterName) then
            addAnimal(model)
        end
    end
end

local function attachSimpleESP(entry, adornee, baseText, highlightName, highlightColor)
    if not entry or not adornee then
        return
    end

    if not entry.highlight or not entry.highlight.Parent then
        local parent = entry.model or adornee
        entry.highlight = createHighlight(
            parent,
            adornee,
            highlightName,
            highlightColor,
            highlightColor,
            0.1
        )
    else
        entry.highlight.Adornee = adornee
    end

    if not entry.labelGui or not entry.labelGui.Parent then
        entry.labelGui, entry.label = createBillboard(adornee, baseText, Color3.new(1, 1, 1))
    else
        entry.labelGui.Adornee = adornee
        updateLabelEntry(entry.label, adornee, baseText)
    end
end

local function removeSimpleESP(entry)
    if entry.highlight then
        entry.highlight:Destroy()
    end
    destroyLabel(entry)
end

Const.TREE_TYPE_FALLBACK = {
    "Cedar01",
    "DeadTree1",
    "DeadTree2",
    "DeadTree3",
    "FirTree",
    "FirTree2",
    "FirTree3",
    "FirTree4",
    "GnarlyTree1",
    "GnarlyTree2",
    "JoshuaTree",
    "JungleTree01",
    "LeafyPlainsTree1",
    "LeafyPlainsTree2",
    "NewDeadTree1",
    "NewPlantationTree",
    "OakTree",
    "PalmTree",
    "Redwood",
    "Redwood2",
    "Redwood3",
    "SaguaroCactus",
    "SanPedroCactus",
    "Sequoia",
    "Spruce01",
    "Spruce02",
    "Spruce1",
    "Spruce2",
    "SwampTree1",
    "SwampTree2",
    "SwampTreeDead",
    "TallMountainTree1",
    "TallMountainTree2",
    "TallMountainTree2Dead",
    "TallPalmTree1",
    "TallPalmTree3",
    "TallTree2",
    "TallTree4",
    "Tree1",
    "Tree2",
    "Tree3",
    "TreeBent01",
    "TreeBent02",
    "TreeBent03",
}

local function attachHighlightOnly(entry, adornee, highlightName, highlightColor, fillTransparency)
    if not entry or not adornee then
        return
    end

    if not entry.highlight or not entry.highlight.Parent then
        local parent = entry.model or adornee
        entry.highlight = createHighlight(
            parent,
            adornee,
            highlightName,
            highlightColor,
            highlightColor,
            fillTransparency or 0.2
        )
    else
        entry.highlight.Adornee = adornee
    end
end

local function removeTree(model)
    local entry = treeState.entries[model]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    if entry.highlight then
        entry.highlight:Destroy()
    end
    treeState.entries[model] = nil
end

local function addTree(model, treeName)
    if not treeState.enabled or not model then
        return
    end
    if not (model:IsA("Model") or model:IsA("BasePart")) then
        return
    end
    if not treeState.selections[treeName] then
        return
    end
    if treeState.entries[model] then
        return
    end

    local entry = {
        model = model,
        treeName = treeName,
        conns = {},
    }
    treeState.entries[model] = entry

    local function refresh()
        if not model.Parent then
            removeTree(model)
            return
        end
        attachHighlightOnly(entry, model, "SmugESP_Tree", Color3.fromRGB(70, 200, 90), 0.5)
    end

    refresh()

    table.insert(entry.conns, model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeTree(model)
        end
    end))
end

local function addTreeCheckbox(treeName)
    if not treeState.checkboxTab then
        return
    end
    if treeState.checkboxCreated[treeName] then
        return
    end
    treeState.checkboxCreated[treeName] = true
    if treeState.selections[treeName] == nil then
        treeState.selections[treeName] = true
    end
    treeState.checkboxTab:Checkbox(treeName, function(state)
        treeState.selections[treeName] = state
        if treeState.enabled then
            for model in pairs(treeState.rootsByType[treeName] or {}) do
                if state then
                    addTree(model, treeName)
                else
                    removeTree(model)
                end
            end
        end
    end, treeState.selections[treeName] == true)
end

local function registerTreeRoot(model)
    if not model then
        return
    end
    local treeName = model.Name
    local set = treeState.rootsByType[treeName]
    if not set then
        set = {}
        treeState.rootsByType[treeName] = set
    end
    if set[model] then
        return
    end
    set[model] = true
    addTreeCheckbox(treeName)
    if treeState.enabled and treeState.selections[treeName] then
        addTree(model, treeName)
    end
end

local function unregisterTreeRoot(model)
    if not model then
        return
    end
    local treeName = model.Name
    local set = treeState.rootsByType[treeName]
    if set then
        set[model] = nil
        if not next(set) then
            treeState.rootsByType[treeName] = nil
        end
    end
    removeTree(model)
end

local function rebuildTreeRoots()
    treeState.rootsByType = {}
    local geometry = getGeometryFolder()
    if not geometry then
        return
    end
    for _, obj in ipairs(geometry:GetDescendants()) do
        if obj.Name == "TreeInfo" then
            registerTreeRoot(obj.Parent)
        end
    end
end

local function clearTrees()
    for model in pairs(treeState.entries) do
        removeTree(model)
    end
    treeState.entries = {}
    cleanupConnections(treeState.conns)
end

local function enableTrees(state)
    treeState.enabled = state
    clearTrees()
    if not state then
        return
    end

    local geometry = getGeometryFolder()
    if not geometry then
        return
    end

    rebuildTreeRoots()

    table.insert(treeState.conns, geometry.DescendantAdded:Connect(function(child)
        if child and child.Name == "TreeInfo" then
            registerTreeRoot(child.Parent)
        end
    end))

    table.insert(treeState.conns, geometry.DescendantRemoving:Connect(function(child)
        if child and child.Name == "TreeInfo" then
            local parent = child.Parent
            task.defer(function()
                if parent and parent.Parent and not parent:FindFirstChild("TreeInfo") then
                    unregisterTreeRoot(parent)
                end
            end)
        end
    end))
end

local function removeTrain(model)
    local entry = trainState.entries[model]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    removeSimpleESP(entry)
    trainState.entries[model] = nil
end

local function addTrain(model)
    if not trainState.enabled or not model then
        return
    end
    if trainState.entries[model] then
        return
    end

    local entry = {
        model = model,
        conns = {},
    }
    trainState.entries[model] = entry

    local function refresh()
        local adornee = getModelPart(model)
        if adornee then
            attachSimpleESP(entry, adornee, model.Name, "SmugESP_Train", Color3.fromRGB(255, 220, 0))
        end
    end

    refresh()

    if model:IsA("Model") then
        table.insert(entry.conns, model:GetPropertyChangedSignal("PrimaryPart"):Connect(refresh))
        table.insert(entry.conns, model.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                refresh()
            end
        end))
    end

    table.insert(entry.conns, model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeTrain(model)
        end
    end))
end

local function clearTrains()
    for model in pairs(trainState.entries) do
        removeTrain(model)
    end
    trainState.entries = {}
    cleanupConnections(trainState.conns)
end

local function enableTrains(state)
    trainState.enabled = state
    clearTrains()
    if not state then
        return
    end

    local trainsFolder = getTrainsFolder()
    if not trainsFolder then
        return
    end

    table.insert(trainState.conns, trainsFolder.ChildAdded:Connect(function(child)
        addTrain(child)
    end))
    table.insert(trainState.conns, trainsFolder.ChildRemoved:Connect(function(child)
        removeTrain(child)
    end))

    for _, model in ipairs(trainsFolder:GetChildren()) do
        addTrain(model)
    end
end

local function removeFort(model)
    local entry = fortState.entries[model]
    if not entry then
        return
    end
    cleanupConnections(entry.conns)
    destroyLabel(entry)
    fortState.entries[model] = nil
end

local function addFort(model)
    if not fortState.enabled or not model then
        return
    end
    if fortState.entries[model] then
        return
    end

    local entry = {
        model = model,
        conns = {},
    }
    fortState.entries[model] = entry

    local function refresh()
        local adornee = getModelPart(model)
        if not adornee then
            return
        end
        if not entry.labelGui or not entry.labelGui.Parent then
            entry.labelGui, entry.label = createBillboard(adornee, model.Name, Color3.new(1, 1, 1))
        else
            entry.labelGui.Adornee = adornee
            updateLabelEntry(entry.label, adornee, model.Name)
        end
    end

    refresh()

    if model:IsA("Model") then
        table.insert(entry.conns, model:GetPropertyChangedSignal("PrimaryPart"):Connect(refresh))
        table.insert(entry.conns, model.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                refresh()
            end
        end))
    end

    table.insert(entry.conns, model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeFort(model)
        end
    end))
end

local function clearForts()
    for model in pairs(fortState.entries) do
        removeFort(model)
    end
    fortState.entries = {}
    cleanupConnections(fortState.conns)
end

local function enableForts(state)
    fortState.enabled = state
    clearForts()
    if not state then
        return
    end

    local fortsFolder = getFortsFolder()
    if not fortsFolder then
        return
    end

    table.insert(fortState.conns, fortsFolder.ChildAdded:Connect(function(child)
        addFort(child)
    end))
    table.insert(fortState.conns, fortsFolder.ChildRemoved:Connect(function(child)
        removeFort(child)
    end))

    for _, model in ipairs(fortsFolder:GetChildren()) do
        addFort(model)
    end
end

local function addDropped(item)
    if not droppedState.enabled or not item then
        return
    end
    if droppedState.entries[item] then
        return
    end

    local entry = {
        model = item,
        conns = {},
    }
    droppedState.entries[item] = entry

    local function refresh()
        local adornee = getModelPart(item)
        if adornee then
            attachSimpleESP(entry, adornee, item.Name, "SmugESP_Dropped", Color3.fromRGB(6, 201, 172))
        end
    end

    refresh()

    if item:IsA("Model") then
        table.insert(entry.conns, item:GetPropertyChangedSignal("PrimaryPart"):Connect(refresh))
        table.insert(entry.conns, item.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                refresh()
            end
        end))
    end

    table.insert(entry.conns, item.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeSimpleESP(entry)
            cleanupConnections(entry.conns)
            droppedState.entries[item] = nil
        end
    end))
end

local function clearDropped()
    for _, entry in pairs(droppedState.entries) do
        removeSimpleESP(entry)
        cleanupConnections(entry.conns)
    end
    droppedState.entries = {}
    cleanupConnections(droppedState.conns)
end

local function enableDropped(state)
    droppedState.enabled = state
    clearDropped()
    if not state then
        return
    end

    local interactables = Services.Workspace:FindFirstChild("WORKSPACE_Interactables")
    local droppedFolder = interactables and interactables:FindFirstChild("DroppedItems") or nil
    if not droppedFolder then
        return
    end

    table.insert(droppedState.conns, droppedFolder.ChildAdded:Connect(addDropped))
    table.insert(droppedState.conns, droppedFolder.ChildRemoved:Connect(function(child)
        local entry = droppedState.entries[child]
        if entry then
            removeSimpleESP(entry)
            cleanupConnections(entry.conns)
            droppedState.entries[child] = nil
        end
    end))

    for _, item in ipairs(droppedFolder:GetChildren()) do
        addDropped(item)
    end
end

local function clearOrePath(oreName)
    local pathEntry = oreState.pathByOre[oreName]
    if not pathEntry then
        return
    end
    if pathEntry.parts then
        for _, part in ipairs(pathEntry.parts) do
            part:Destroy()
        end
    end
    oreState.pathByOre[oreName] = nil
end

local function clearAllOrePaths()
    for oreName in pairs(oreState.pathByOre) do
        clearOrePath(oreName)
    end
    oreState.pathByOre = {}
end

local function createPathParts(waypoints, color)
    if not waypoints or #waypoints < 2 then
        return {}
    end
    local parts = {}
    local thickness = Const.ORE_PATH_POINT_SIZE
    for i = 1, #waypoints - 1 do
        local a = waypoints[i].Position
        local b = waypoints[i + 1].Position
        local delta = b - a
        local dist = delta.Magnitude
        if dist > 0.1 then
            local part = Instance.new("Part")
            part.Name = "SmugESP_PathLine"
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = color or Const.ORE_PATH_COLOR
            part.Transparency = 0.2
            part.Size = Vector3.new(thickness, thickness, dist)
            part.CFrame = CFrame.new(a, b) * CFrame.new(0, 0, -dist / 2)
            part.Parent = PathFolder
            table.insert(parts, part)
        end
    end
    return parts
end

local function getNearestOre(oreName, rootPos)
    local closest = nil
    local closestDist = math.huge
    for model, entry in pairs(oreState.entries) do
        if entry.oreName == oreName then
            local adornee = getModelPart(model)
            if adornee then
                local dist = (rootPos - adornee.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = adornee
                end
            end
        end
    end
    return closest, closestDist
end

local function simplifyWaypoints(waypoints)
    if not waypoints or #waypoints <= 2 then
        return waypoints
    end
    local simplified = { waypoints[1] }
    for i = 2, #waypoints - 1 do
        local prev = simplified[#simplified]
        local curr = waypoints[i]
        local next = waypoints[i + 1]
        if curr.Action ~= Enum.PathWaypointAction.Walk or next.Action ~= Enum.PathWaypointAction.Walk then
            table.insert(simplified, curr)
        else
            local dir1 = curr.Position - prev.Position
            local dir2 = next.Position - curr.Position
            if dir1.Magnitude < 0.05 or dir2.Magnitude < 0.05 then
                -- skip tiny segments
            else
                local dot = dir1.Unit:Dot(dir2.Unit)
                if dot < 0.98 then
                    table.insert(simplified, curr)
                end
            end
        end
    end
    table.insert(simplified, waypoints[#waypoints])
    return simplified
end

local function computePathDetailed(startPos, goalPos, agentRadius, agentHeight)
    local path = Services.PathfindingService:CreatePath({
        AgentRadius = agentRadius or 2,
        AgentHeight = agentHeight or 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = Const.ORE_PATH_WAYPOINT_SPACING,
    })
    local ok = pcall(function()
        path:ComputeAsync(startPos, goalPos)
    end)
    if ok and path.Status == Enum.PathStatus.Success then
        return simplifyWaypoints(path:GetWaypoints()), path
    end
    return nil, path
end

local function getAgentDimensions()
    local root = getLocalRootPart()
    local humanoid = getLocalHumanoid()
    local radius = 2
    local height = 5
    if root and root:IsA("BasePart") then
        radius = math.max(root.Size.X, root.Size.Z) * 0.5
        height = math.max(height, root.Size.Y + 2)
    end
    if humanoid then
        height = math.max(height, (humanoid.HipHeight * 2) + 2)
    end
    return radius, height
end

local function computePath(startPos, goalPos, requireSuccess)
    local radius, height = getAgentDimensions()
    local waypoints = computePathDetailed(startPos, goalPos, radius, height)
    if waypoints then
        return waypoints
    end
    if requireSuccess then
        return nil
    end
    return { { Position = goalPos, Action = Enum.PathWaypointAction.Walk } }
end

local function updateOrePathForType(oreName, root)
    if not oreState.enabled or not oreState.selections[oreName] then
        clearOrePath(oreName)
        return
    end
    if not root then
        clearOrePath(oreName)
        return
    end

    local rootPos = root.Position
    local target = getNearestOre(oreName, rootPos)
    if not target or not target.Parent then
        clearOrePath(oreName)
        return
    end

    local entry = oreState.pathByOre[oreName]
    if not entry then
        entry = {
            lastRootPos = nil,
            lastTargetPos = nil,
            lastCompute = 0,
            busy = false,
            parts = {},
        }
        oreState.pathByOre[oreName] = entry
    end

    local now = os.clock()
    if entry.busy then
        return
    end
    if now - entry.lastCompute < Const.ORE_PATH_UPDATE_INTERVAL then
        return
    end
    if entry.lastRootPos and entry.lastTargetPos then
        local movedRoot = (rootPos - entry.lastRootPos).Magnitude
        local movedTarget = (target.Position - entry.lastTargetPos).Magnitude
        if movedRoot < Const.ORE_PATH_REPATH_DISTANCE and movedTarget < Const.ORE_PATH_REPATH_DISTANCE and entry.parts then
            entry.lastCompute = now
            return
        end
    end

    entry.busy = true
    entry.lastCompute = now
    entry.lastRootPos = rootPos
    entry.lastTargetPos = target.Position

    task.spawn(function()
        local waypoints = computePath(rootPos, target.Position, true)
        if entry.parts then
            for _, part in ipairs(entry.parts) do
                part:Destroy()
            end
        end
        if waypoints and #waypoints >= 2 then
            entry.parts = createPathParts(waypoints, Const.ORE_PATH_COLOR)
        else
            entry.parts = {}
        end
        entry.busy = false
    end)
end

local function findOreRemainingValue(model, oreName)
    local function resolveFromModel(target)
        if not target then
            return nil
        end
        local info = target:FindFirstChild("DepositInfo") or target:FindFirstChild("DepositInfo", true)
        local remaining = info and (info:FindFirstChild("OreRemaining") or info:FindFirstChild("OreRemaining", true))
        if remaining and remaining:IsA("ValueBase") then
            return remaining
        end
        return nil
    end

    local function scanFolderForModel(folder, targetModel)
        if not folder or not folder:IsA("Folder") or not targetModel then
            return nil
        end
        for _, child in ipairs(folder:GetDescendants()) do
            if child:IsA("ValueBase") and child.Name == "OreRemaining" then
                if child:IsDescendantOf(targetModel) or (targetModel.Parent and child:IsDescendantOf(targetModel.Parent)) then
                    return child
                end
            end
        end
        return nil
    end

    local interactables = Services.Workspace:FindFirstChild("WORKSPACE_Interactables")
    local mining = interactables and interactables:FindFirstChild("Mining") or nil
    local deposits = mining and mining:FindFirstChild("OreDeposits") or nil

    local directRemaining = resolveFromModel(model)
        or resolveFromModel(model and model.Parent)
    if directRemaining then
        return directRemaining
    end

    if deposits and oreName then
        local namedFolder = deposits:FindFirstChild(oreName)
        local remaining = scanFolderForModel(namedFolder, model)
        if remaining then
            return remaining
        end
    end

    return nil
end

local function formatOreLabel(oreName, remainingValue)
    if not remainingValue then
        return oreName
    end
    local value = tonumber(remainingValue.Value)
    if not value then
        return oreName
    end
    return string.format("%s [%d]", oreName, math.floor(value + 0.5))
end

local function addOre(item, oreName)
    if not oreState.enabled or not item then
        return
    end
    if oreState.entries[item] then
        return
    end

    local entry = {
        model = item,
        oreName = oreName,
        conns = {},
        remainingValue = nil,
        remainingConn = nil,
    }
    oreState.entries[item] = entry

    local function refresh()
        local adornee = getModelPart(item)
        if adornee then
            if not entry.remainingValue or not entry.remainingValue.Parent then
                local valueObj = findOreRemainingValue(item, oreName)
                if valueObj then
                    entry.remainingValue = valueObj
                    if entry.remainingConn then
                        entry.remainingConn:Disconnect()
                    end
                    entry.remainingConn = valueObj.Changed:Connect(refresh)
                    table.insert(entry.conns, entry.remainingConn)
                end
            end

            if entry.remainingValue then
                local remaining = tonumber(entry.remainingValue.Value)
                if remaining and remaining <= 0 then
                    removeSimpleESP(entry)
                    return
                end
            end

            local labelText = formatOreLabel(oreName, entry.remainingValue)
            attachSimpleESP(entry, adornee, labelText, "SmugESP_Ore", Color3.fromRGB(255, 170, 0))
        end
    end

    refresh()

    if item:IsA("Model") then
        table.insert(entry.conns, item:GetPropertyChangedSignal("PrimaryPart"):Connect(refresh))
        table.insert(entry.conns, item.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                refresh()
            end
        end))
    end

    table.insert(entry.conns, item.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeSimpleESP(entry)
            cleanupConnections(entry.conns)
            oreState.entries[item] = nil
        end
    end))
end

local function disableOreFolder(folder)
    if not folder then
        return
    end
    local conns = oreState.folderConns[folder]
    if conns then
        cleanupConnections(conns)
        oreState.folderConns[folder] = nil
    end

    local items = {}
    for item, entry in pairs(oreState.entries) do
        if entry.oreName == folder.Name then
            table.insert(items, { item = item, entry = entry })
        end
    end
    for _, info in ipairs(items) do
        removeSimpleESP(info.entry)
        cleanupConnections(info.entry.conns)
        oreState.entries[info.item] = nil
    end
end

local function enableOreFolder(folder)
    if not folder then
        return
    end
    if not oreState.folderConns[folder] then
        oreState.folderConns[folder] = {}
        local conns = oreState.folderConns[folder]
        table.insert(conns, folder.ChildAdded:Connect(function(child)
            addOre(child, folder.Name)
        end))
        table.insert(conns, folder.ChildRemoved:Connect(function(child)
            local entry = oreState.entries[child]
            if entry then
                removeSimpleESP(entry)
                cleanupConnections(entry.conns)
                oreState.entries[child] = nil
            end
        end))
    end

    for _, item in ipairs(folder:GetChildren()) do
        addOre(item, folder.Name)
    end
end

local function refreshOreVisibility()
    for name, folder in pairs(oreState.oreFolders) do
        if oreState.enabled and oreState.selections[name] then
            enableOreFolder(folder)
        else
            disableOreFolder(folder)
        end
    end
end

local function rebuildOreFolders()
    oreState.oreFolders = {}
    local interactables = Services.Workspace:FindFirstChild("WORKSPACE_Interactables")
    local mining = interactables and interactables:FindFirstChild("Mining") or nil
    local deposits = mining and mining:FindFirstChild("OreDeposits") or nil
    if not deposits then
        return nil
    end

    for _, folder in ipairs(deposits:GetChildren()) do
        if folder:IsA("Folder") then
            oreState.oreFolders[folder.Name] = folder
        end
    end
    return deposits
end

local function enableOres(state)
    oreState.enabled = state
    for _, entry in pairs(oreState.entries) do
        removeSimpleESP(entry)
        cleanupConnections(entry.conns)
    end
    oreState.entries = {}

    local folders = {}
    for folder in pairs(oreState.folderConns) do
        table.insert(folders, folder)
    end
    for _, folder in ipairs(folders) do
        disableOreFolder(folder)
    end
    oreState.folderConns = {}
    clearAllOrePaths()

    if not state then
        return
    end

    rebuildOreFolders()
    refreshOreVisibility()
end

local function setOreSelection(oreName, state)
    oreState.selections[oreName] = state
    if oreState.enabled then
        refreshOreVisibility()
    end
    if not state then
        clearOrePath(oreName)
    end
end

local function buildTreeCheckboxes(tab)
    treeState.checkboxTab = tab
    tab:Separator("Trees")

    rebuildTreeRoots()

    for _, name in ipairs(Const.TREE_TYPE_FALLBACK) do
        addTreeCheckbox(name)
    end
end

local function buildOreCheckboxes(tab)
    local deposits = rebuildOreFolders()
    if not deposits then
        tab:Label("OreDeposits folder not found.")
        return
    end

    local oreNames = {}
    for name in pairs(oreState.oreFolders) do
        table.insert(oreNames, name)
    end
    table.sort(oreNames)

    tab:Separator("Ores")
    for _, name in ipairs(oreNames) do
        local oreName = name
        oreState.selections[oreName] = true
        tab:Checkbox(oreName, function(state)
            setOreSelection(oreName, state)
        end, true)
    end
end

local function buildAnimalExcludeCheckboxes(tab)
    local names = {}
    local seen = {}

    for name in pairs(Const.ANIMAL_MAX_HEALTH) do
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end

    if not seen.Horse then
        seen.Horse = true
        table.insert(names, "Horse")
    end

    local entities = getEntitiesFolder()
    local animalsFolder = entities and entities:FindFirstChild("Animals") or nil
    if animalsFolder then
        for _, model in ipairs(animalsFolder:GetChildren()) do
            local name = model.Name
            if name and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end

    table.sort(names)

    tab:Separator("Animal Exclusions")
    for _, name in ipairs(names) do
        local filterName = name
        local defaultState = animalState.exclusions[filterName] == true
        tab:Checkbox(filterName, function(state)
            setAnimalExcluded(filterName, state)
        end, defaultState)
    end
end

local function startLoops()
    if TWW._espLoopsStarted then
        return
    end
    TWW._espLoopsStarted = true

    task.spawn(function()
        while true do
            if oreState.enabled then
                local root = getLocalRootPart()
                for oreName in pairs(oreState.selections) do
                    updateOrePathForType(oreName, root)
                    task.wait(0.01)
                end
            else
                clearAllOrePaths()
            end
            task.wait(Const.ORE_PATH_UPDATE_INTERVAL)
        end
    end)

    task.spawn(function()
        while true do
            local root = getLocalRootPart()
            for label, data in pairs(labelEntries) do
                if not label.Parent or not data.adornee or not data.adornee.Parent then
                    labelEntries[label] = nil
                else
                    local baseText = data.baseText or ""
                    if root then
                        local distance = (root.Position - data.adornee.Position).Magnitude
                        local distText = string.format(" [%d]", math.floor(distance + 0.5))
                        if data.distanceLabel then
                            label.Text = baseText
                            data.distanceLabel.Text = distText
                        else
                            label.Text = baseText .. distText
                        end
                    else
                        label.Text = baseText
                        if data.distanceLabel then
                            data.distanceLabel.Text = ""
                        end
                    end
                end
            end
            task.wait(0.2)
        end
    end)

    Services.RunService.Heartbeat:Connect(function()
        if not next(rainbowHighlights) then
            return
        end
        local hue = (os.clock() * 0.5) % 1
        local color = Color3.fromHSV(hue, 1, 1)
        for highlight in pairs(rainbowHighlights) do
            if highlight.Parent then
                highlight.FillColor = color
                highlight.OutlineColor = color
            else
                rainbowHighlights[highlight] = nil
            end
        end
    end)
end

TWW.Esp = TWW.Esp or {}
local Esp = TWW.Esp

Esp.enableAnimals = enableAnimals
Esp.enableDropped = enableDropped
Esp.enablePlayerEsp = enablePlayerEsp
Esp.enableNpcEsp = enableNpcEsp
Esp.enableTrees = enableTrees
Esp.enableTrains = enableTrains
Esp.enableForts = enableForts
Esp.enableOres = enableOres
Esp.rebuildOreFolders = rebuildOreFolders
Esp.findOreRemainingValue = findOreRemainingValue
Esp.getModelPart = getModelPart
Esp.getLocalRootPart = getLocalRootPart
Esp.getLocalHumanoid = getLocalHumanoid
Esp.getLocalPlayerModel = getLocalPlayerModel
Esp.getPlayersFolder = getPlayersFolder
Esp.getEntitiesFolder = getEntitiesFolder
Esp.oreState = oreState
Esp.buildTreeCheckboxes = buildTreeCheckboxes
Esp.buildOreCheckboxes = buildOreCheckboxes
Esp.buildAnimalExcludeCheckboxes = buildAnimalExcludeCheckboxes
Esp.setOreSelection = setOreSelection

TWW.startLoops = startLoops
