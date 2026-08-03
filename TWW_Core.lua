local env = (getgenv and getgenv()) or _G
env.TWW = env.TWW or {}
local TWW = env.TWW

if TWW._coreLoaded then
    return
end
TWW._coreLoaded = true

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

local TweenService = Services.TweenService
if not TweenService then
    TweenService = game:GetService("TweenService")
    Services.TweenService = TweenService
end

local LocalPlayer = TWW.LocalPlayer or Services.Players.LocalPlayer
TWW.LocalPlayer = LocalPlayer

local function safeRequireModule(pathParts)
    local node = Services.ReplicatedStorage
    for _, name in ipairs(pathParts) do
        node = node and node:FindFirstChild(name) or nil
        if not node then
            return nil
        end
    end
    if node:IsA("ModuleScript") then
        local ok, mod = pcall(require, node)
        if ok then
            return mod
        end
    end
    return nil
end

local function ensureTagHandlerSafe()
    local global = safeRequireModule({ "SharedModules", "Global" })
    if not global then
        return
    end

    local function wrapTagHandler(tagHandler)
        if type(tagHandler) == "table" and type(tagHandler.new) == "function" and not tagHandler.__twwSafe then
            local originalNew = tagHandler.new
            tagHandler.new = function(...)
                local ok, result = pcall(originalNew, ...)
                if ok then
                    return result
                end
                return nil
            end
            tagHandler.__twwSafe = true
        end
    end

    if global.TagHandler then
        wrapTagHandler(global.TagHandler)
        return
    end

    local tagHandler = safeRequireModule({ "SharedModules", "Utils", "TagHandler" })
    if tagHandler then
        global.TagHandler = tagHandler
        wrapTagHandler(tagHandler)
        return
    end

    global.TagHandler = { new = function() return nil end, __twwSafe = true }
end

pcall(ensureTagHandlerSafe)

local Library = TWW.Library
if not Library then
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Xa3ro5/LifeIsRoblox/refs/heads/main/SmugLib.lua"))()
    TWW.Library = Library
end

local disableAllEsp
local function handleUiClosed()
    if disableAllEsp then
        disableAllEsp()
    end
    TWW._uiBuilt = false
    TWW.Tabs = nil
    TWW.Window = nil
end

local Window = TWW.Window
if not Window then
    Window = Library:CreateWindow("TWW ESP", {
        Width = 520,
        Height = 420,
        ConfigKey = "TWW_ESP",
        OnClose = function()
            handleUiClosed()
        end,
    })
    TWW.Window = Window
end

local function attachUiCloseListener()
    local function hookGui(gui)
        if not gui then
            return
        end
        gui.AncestryChanged:Connect(function(_, parent)
            if not parent then
                handleUiClosed()
            end
        end)
    end

    local rootGui = (gethui and gethui()) or Services.CoreGui
    local existing = rootGui:FindFirstChild("SmugLibCore")
    if existing then
        hookGui(existing)
    end

    rootGui.ChildAdded:Connect(function(child)
        if child.Name == "SmugLibCore" then
            hookGui(child)
        end
    end)
end

attachUiCloseListener()

local Tabs = TWW.Tabs
if not Tabs then
    Tabs = {
        Esp = Window:Folder("ESP"),
        Filters = Window:Folder("Filters"),
        Aim = Window:Folder("Aim"),
        Visuals = Window:Folder("Visuals"),
        Config = Window:Folder("Config"),
        Client = Window:Folder("Client"),
        Audio = Window:Folder("Audio"),
    }
    TWW.Tabs = Tabs
end

local function ensureWindowAndTabs()
    local win = TWW.Window
    if not win then
        win = Library:CreateWindow("TWW ESP", {
            Width = 520,
            Height = 420,
            ConfigKey = "TWW_ESP",
            OnClose = function()
                handleUiClosed()
            end,
        })
        TWW.Window = win
    end
    if not TWW.Tabs then
        TWW.Tabs = {
            Esp = win:Folder("ESP"),
            Filters = win:Folder("Filters"),
            Aim = win:Folder("Aim"),
            Visuals = win:Folder("Visuals"),
            Config = win:Folder("Config"),
            Client = win:Folder("Client"),
            Audio = win:Folder("Audio"),
        }
    end
    Tabs = TWW.Tabs
    Window = win
end

local function getLocalPlayerModel()
    local esp = TWW.Esp
    if esp and esp.getLocalPlayerModel then
        return esp.getLocalPlayerModel()
    end
    local entities = Services.Workspace:FindFirstChild("WORKSPACE_Entities")
    local playersFolder = entities and entities:FindFirstChild("Players") or nil
    return playersFolder and playersFolder:FindFirstChild(LocalPlayer.Name) or nil
end

local function getLocalHumanoid()
    local esp = TWW.Esp
    if esp and esp.getLocalHumanoid then
        return esp.getLocalHumanoid()
    end
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

local function getLocalRootPart()
    local esp = TWW.Esp
    if esp and esp.getLocalRootPart then
        return esp.getLocalRootPart()
    end
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

local Const = {}

Const.FULLBRIGHT_VALUES = {
    Brightness = 3,
    ClockTime = 12,
    FogStart = 0,
    FogEnd = 100000,
    GlobalShadows = false,
    Ambient = Color3.new(1, 1, 1),
    OutdoorAmbient = Color3.new(1, 1, 1),
    ColorShift_Top = Color3.new(1, 1, 1),
    ColorShift_Bottom = Color3.new(1, 1, 1),
    ExposureCompensation = 0,
}

Const.FULLBRIGHT_ATMOS = {
    Density = 0,
    Haze = 0,
    Glare = 0,
    Offset = 0,
    Color = Color3.new(1, 1, 1),
    Decay = Color3.new(1, 1, 1),
}

local fullbrightState = {
    enabled = false,
    props = {},
    effects = {},
    conn = nil,
    childConn = nil,
    applying = false,
    lastEnforce = 0,
}

local function applyFullbright()
    if fullbrightState.applying then
        return
    end
    fullbrightState.applying = true

    for key, value in pairs(Const.FULLBRIGHT_VALUES) do
        if Services.Lighting[key] ~= value then
            Services.Lighting[key] = value
        end
    end

    for _, child in ipairs(Services.Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            if not fullbrightState.effects[child] then
                fullbrightState.effects[child] = {
                    Density = child.Density,
                    Haze = child.Haze,
                    Glare = child.Glare,
                    Offset = child.Offset,
                    Color = child.Color,
                    Decay = child.Decay,
                }
            end
            child.Density = Const.FULLBRIGHT_ATMOS.Density
            child.Haze = Const.FULLBRIGHT_ATMOS.Haze
            child.Glare = Const.FULLBRIGHT_ATMOS.Glare
            child.Offset = Const.FULLBRIGHT_ATMOS.Offset
            child.Color = Const.FULLBRIGHT_ATMOS.Color
            child.Decay = Const.FULLBRIGHT_ATMOS.Decay
        elseif child:IsA("BaseEffect") then
            if fullbrightState.effects[child] == nil then
                fullbrightState.effects[child] = child.Enabled
            end
            child.Enabled = false
        end
    end

    fullbrightState.applying = false
end

local function setFullbright(state)
    if state then
        if fullbrightState.enabled then
            return
        end
        fullbrightState.enabled = true
        fullbrightState.props = {
            Brightness = Services.Lighting.Brightness,
            ClockTime = Services.Lighting.ClockTime,
            FogStart = Services.Lighting.FogStart,
            FogEnd = Services.Lighting.FogEnd,
            GlobalShadows = Services.Lighting.GlobalShadows,
            Ambient = Services.Lighting.Ambient,
            OutdoorAmbient = Services.Lighting.OutdoorAmbient,
            ColorShift_Top = Services.Lighting.ColorShift_Top,
            ColorShift_Bottom = Services.Lighting.ColorShift_Bottom,
            ExposureCompensation = Services.Lighting.ExposureCompensation,
        }
        fullbrightState.effects = {}
        fullbrightState.lastEnforce = 0

        applyFullbright()

        if not fullbrightState.conn then
            fullbrightState.conn = Services.Lighting.Changed:Connect(function()
                if not fullbrightState.enabled then
                    return
                end
                local now = os.clock()
                if now - fullbrightState.lastEnforce < 0.25 then
                    return
                end
                fullbrightState.lastEnforce = now
                applyFullbright()
            end)
        end

        if not fullbrightState.childConn then
            fullbrightState.childConn = Services.Lighting.ChildAdded:Connect(function()
                if fullbrightState.enabled then
                    applyFullbright()
                end
            end)
        end
        return
    end

    if not fullbrightState.enabled then
        return
    end
    fullbrightState.enabled = false

    if fullbrightState.conn then
        fullbrightState.conn:Disconnect()
        fullbrightState.conn = nil
    end
    if fullbrightState.childConn then
        fullbrightState.childConn:Disconnect()
        fullbrightState.childConn = nil
    end

    for key, value in pairs(fullbrightState.props) do
        if Services.Lighting[key] ~= nil then
            Services.Lighting[key] = value
        end
    end
    for effect, data in pairs(fullbrightState.effects) do
        if effect and effect.Parent then
            if effect:IsA("Atmosphere") then
                effect.Density = data.Density
                effect.Haze = data.Haze
                effect.Glare = data.Glare
                effect.Offset = data.Offset
                effect.Color = data.Color
                effect.Decay = data.Decay
            else
                effect.Enabled = data
            end
        end
    end
    fullbrightState.props = {}
    fullbrightState.effects = {}
end

local function getCamera()
    return Services.Workspace.CurrentCamera
end

local function getGameSettings()
    local ok, settings = pcall(UserSettings)
    if not ok or not settings then
        return nil
    end
    local okGs, gs = pcall(function()
        return settings.GameSettings
    end)
    if okGs and gs then
        return gs
    end
    return nil
end

local fovState = {
    enabled = false,
    value = 70,
    original = nil,
    conn = nil,
}

local function setFovValue(value)
    local num = tonumber(value)
    if not num then
        return
    end
    fovState.value = num
    if fovState.enabled then
        local cam = getCamera()
        if cam then
            cam.FieldOfView = fovState.value
        end
    end
end

local function setFovEnabled(state)
    fovState.enabled = state
    if fovState.conn then
        fovState.conn:Disconnect()
        fovState.conn = nil
    end
    if not state then
        local cam = getCamera()
        if cam and fovState.original then
            cam.FieldOfView = fovState.original
        end
        fovState.original = nil
        return
    end

    local cam = getCamera()
    if cam then
        fovState.original = cam.FieldOfView
        cam.FieldOfView = fovState.value
    end
    fovState.conn = Services.RunService.RenderStepped:Connect(function()
        local current = getCamera()
        if current then
            current.FieldOfView = fovState.value
        end
    end)
end

local function resetFov()
    setFovEnabled(false)
end

local sfxState = {
    original = nil,
    value = nil,
    usesMaster = false,
}

local function setSfxVolume(value)
    local num = tonumber(value)
    if not num then
        return
    end
    local gs = getGameSettings()
    if gs and gs.MasterVolume ~= nil then
        if sfxState.original == nil then
            sfxState.original = gs.MasterVolume
            sfxState.usesMaster = true
        end
        sfxState.value = num
        gs.MasterVolume = math.clamp(num / 10, 0, 1)
        return
    end

    local ok, current = pcall(function()
        return Services.SoundService.Volume
    end)
    if ok then
        if sfxState.original == nil then
            sfxState.original = current
            sfxState.usesMaster = false
        end
        sfxState.value = num
        pcall(function()
            Services.SoundService.Volume = num
        end)
    else
        warn("SFX volume control not supported on this client.")
    end
end

local function resetSfxVolume()
    if sfxState.original ~= nil then
        if sfxState.usesMaster then
            local gs = getGameSettings()
            if gs and gs.MasterVolume ~= nil then
                gs.MasterVolume = sfxState.original
            end
        else
            pcall(function()
                Services.SoundService.Volume = sfxState.original
            end)
        end
    end
    sfxState.original = nil
    sfxState.value = nil
    sfxState.usesMaster = false
end

local postFxState = {
    enabled = false,
    originals = setmetatable({}, { __mode = "k" }),
}

local function setPostEffectsOff(state)
    if state then
        if postFxState.enabled then
            return
        end
        postFxState.enabled = true
        postFxState.originals = setmetatable({}, { __mode = "k" })
        for _, child in ipairs(Services.Lighting:GetChildren()) do
            if child:IsA("PostEffect") then
                postFxState.originals[child] = child.Enabled
                child.Enabled = false
            end
        end
        return
    end

    if not postFxState.enabled then
        return
    end
    postFxState.enabled = false
    for effect, enabled in pairs(postFxState.originals) do
        if effect and effect.Parent then
            effect.Enabled = enabled
        end
    end
    postFxState.originals = setmetatable({}, { __mode = "k" })
end

local aimAssistState = {
    enabled = false,
    radius = 140,
    showCircle = true,
    onlyVisible = false,
    rotateBody = false,
    circleGui = nil,
    circle = nil,
    conn = nil,
    lastHumanoid = nil,
    autoRotateBackup = nil,
}

local function getMousePosition()
    local pos = Services.UserInputService:GetMouseLocation()
    local inset = Services.GuiService:GetGuiInset()
    return Vector2.new(pos.X - inset.X, pos.Y - inset.Y)
end

local function ensureAimCircle()
    if aimAssistState.circleGui and aimAssistState.circleGui.Parent then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "SmugAimCircle"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = (gethui and gethui()) or Services.CoreGui

    local circle = Instance.new("Frame")
    circle.Name = "Circle"
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 2
    stroke.Parent = circle

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    aimAssistState.circleGui = gui
    aimAssistState.circle = circle
end

local function updateAimCircle()
    if not aimAssistState.circle then
        return
    end
    local r = aimAssistState.radius
    aimAssistState.circle.Size = UDim2.new(0, r * 2, 0, r * 2)
end

local function getPlayersFolder()
    local esp = TWW.Esp
    if esp and esp.getPlayersFolder then
        return esp.getPlayersFolder()
    end
    local entities = Services.Workspace:FindFirstChild("WORKSPACE_Entities")
    return entities and entities:FindFirstChild("Players") or nil
end

local function getOtherPlayerModels()
    local results = {}
    local playersFolder = getPlayersFolder()
    if playersFolder then
        for _, model in ipairs(playersFolder:GetChildren()) do
            if model:IsA("Model") and model.Name ~= LocalPlayer.Name then
                table.insert(results, model)
            end
        end
        return results
    end

    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            table.insert(results, plr.Character)
        end
    end
    return results
end

local function getPlayerHead(model)
    if not model then
        return nil
    end
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    local part = nil
    if model:IsA("Model") then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                part = child
                break
            end
        end
    elseif model:IsA("BasePart") then
        part = model
    end
    return part
end

local function isAlive(model)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid") or nil
    if humanoid and humanoid.Health <= 0 then
        return false
    end
    return true
end

local function isVisibleTarget(cam, head)
    if not cam or not head then
        return false
    end
    local origin = cam.CFrame.Position
    local direction = head.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local ignore = {}
    local localModel = getLocalPlayerModel() or LocalPlayer.Character
    if localModel then
        table.insert(ignore, localModel)
    end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local result = Services.Workspace:Raycast(origin, direction, params)
    if not result then
        return true
    end
    return result.Instance and result.Instance:IsDescendantOf(head.Parent)
end

local function findAimTarget(cam, mousePos, radius)
    local best = nil
    local bestDist = nil
    for _, model in ipairs(getOtherPlayerModels()) do
        if isAlive(model) then
            local head = getPlayerHead(model)
            if head then
                if aimAssistState.onlyVisible and not isVisibleTarget(cam, head) then
                    continue
                end
                local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist <= radius and (not bestDist or dist < bestDist) then
                        best = head
                        bestDist = dist
                    end
                end
            end
        end
    end
    return best
end

local function updateAimAssist()
    if not aimAssistState.enabled then
        return
    end
    local cam = getCamera()
    if not cam then
        return
    end

    ensureAimCircle()
    updateAimCircle()

    local mousePos = getMousePosition()
    if aimAssistState.circle then
        local r = aimAssistState.radius
        aimAssistState.circle.Position = UDim2.new(0, mousePos.X - r, 0, mousePos.Y - r)
        aimAssistState.circle.Visible = aimAssistState.showCircle
    end

    local targetHead = findAimTarget(cam, mousePos, aimAssistState.radius)
    if targetHead then
        cam.CFrame = CFrame.new(cam.CFrame.Position, targetHead.Position)
        if aimAssistState.rotateBody then
            local root = getLocalRootPart()
            local model = getLocalPlayerModel() or LocalPlayer.Character
            if model then
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if aimAssistState.lastHumanoid ~= humanoid then
                        aimAssistState.lastHumanoid = humanoid
                        aimAssistState.autoRotateBackup = humanoid.AutoRotate
                    end
                    humanoid.AutoRotate = false
                end
            end
            if root then
                local pos = root.Position
                root.CFrame = CFrame.new(pos, Vector3.new(targetHead.Position.X, pos.Y, targetHead.Position.Z))
            end
        end
    else
        if aimAssistState.lastHumanoid and aimAssistState.autoRotateBackup ~= nil then
            aimAssistState.lastHumanoid.AutoRotate = aimAssistState.autoRotateBackup
        end
        aimAssistState.lastHumanoid = nil
        aimAssistState.autoRotateBackup = nil
    end
end

local function setAimAssistEnabled(state)
    aimAssistState.enabled = state
    if aimAssistState.conn then
        aimAssistState.conn:Disconnect()
        aimAssistState.conn = nil
    end
    if not state then
        if aimAssistState.circleGui then
            aimAssistState.circleGui:Destroy()
        end
        aimAssistState.circleGui = nil
        aimAssistState.circle = nil
        if aimAssistState.lastHumanoid and aimAssistState.autoRotateBackup ~= nil then
            aimAssistState.lastHumanoid.AutoRotate = aimAssistState.autoRotateBackup
        end
        aimAssistState.lastHumanoid = nil
        aimAssistState.autoRotateBackup = nil
        return
    end
    aimAssistState.conn = Services.RunService.RenderStepped:Connect(updateAimAssist)
end

local function setAimAssistRadius(value)
    local num = tonumber(value)
    if not num then
        return
    end
    aimAssistState.radius = math.clamp(num, 20, 600)
    updateAimCircle()
end

local function setAimAssistShowCircle(state)
    aimAssistState.showCircle = state == true
    if aimAssistState.circle then
        aimAssistState.circle.Visible = aimAssistState.showCircle
    end
end

local function setAimAssistRotateBody(state)
    aimAssistState.rotateBody = state == true
    if not aimAssistState.rotateBody then
        if aimAssistState.lastHumanoid and aimAssistState.autoRotateBackup ~= nil then
            aimAssistState.lastHumanoid.AutoRotate = aimAssistState.autoRotateBackup
        end
        aimAssistState.lastHumanoid = nil
        aimAssistState.autoRotateBackup = nil
    end
end

local scopeHideState = {
    enabled = false,
    conns = {},
    targets = setmetatable({}, { __mode = "k" }),
    originals = setmetatable({}, { __mode = "k" }),
    lastAim = false,
    dotGui = nil,
    dot = nil,
    dotSize = 6,
    dotOpacity = 1,
    dotColorR = 255,
    dotColorG = 255,
    dotColorB = 255,
    dotAlways = false,
}

local function matchesScopeName(name)
    local n = tostring(name or ""):lower()
    return n:find("scope") or n:find("binoc") or n:find("binocular") or n:find("spyglass") or n:find("sniper") or n:find("zoom")
end

local function addScopeTarget(inst)
    if scopeHideState.targets[inst] then
        return
    end
    if inst:IsA("GuiObject") then
        scopeHideState.originals[inst] = { Visible = inst.Visible }
        scopeHideState.targets[inst] = true
    elseif inst:IsA("LayerCollector") then
        scopeHideState.originals[inst] = { Enabled = inst.Enabled }
        scopeHideState.targets[inst] = true
    end
end

local updateScopeDotStyle
local setScopeDotVisible

local function ensureScopeDot()
    if scopeHideState.dotGui and scopeHideState.dotGui.Parent then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "SmugScopeDot"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1000
    gui.Parent = (gethui and gethui()) or Services.CoreGui

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.new(0, scopeHideState.dotSize, 0, scopeHideState.dotSize)
    dot.Position = UDim2.new(0.5, -(scopeHideState.dotSize / 2), 0.5, -(scopeHideState.dotSize / 2))
    dot.BackgroundColor3 = Color3.fromRGB(scopeHideState.dotColorR, scopeHideState.dotColorG, scopeHideState.dotColorB)
    dot.BackgroundTransparency = 1 - math.clamp(scopeHideState.dotOpacity, 0, 1)
    dot.BorderSizePixel = 0
    dot.Visible = false
    dot.ZIndex = 10
    dot.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    scopeHideState.dotGui = gui
    scopeHideState.dot = dot
    updateScopeDotStyle()
end

updateScopeDotStyle = function()
    if not scopeHideState.dot then
        return
    end
    local size = math.max(2, math.floor(scopeHideState.dotSize + 0.5))
    scopeHideState.dot.Size = UDim2.new(0, size, 0, size)
    scopeHideState.dot.Position = UDim2.new(0.5, -(size / 2), 0.5, -(size / 2))
    scopeHideState.dot.BackgroundColor3 = Color3.fromRGB(scopeHideState.dotColorR, scopeHideState.dotColorG, scopeHideState.dotColorB)
    scopeHideState.dot.BackgroundTransparency = 1 - math.clamp(scopeHideState.dotOpacity, 0, 1)
end

local function setScopeDotSize(value)
    local num = tonumber(value)
    if not num then
        return
    end
    scopeHideState.dotSize = math.clamp(num, 2, 20)
    updateScopeDotStyle()
end

local function setScopeDotOpacity(value)
    local num = tonumber(value)
    if not num then
        return
    end
    scopeHideState.dotOpacity = math.clamp(num, 0, 1)
    updateScopeDotStyle()
end

local function setScopeDotColor(r, g, b)
    scopeHideState.dotColorR = math.clamp(math.floor(r + 0.5), 0, 255)
    scopeHideState.dotColorG = math.clamp(math.floor(g + 0.5), 0, 255)
    scopeHideState.dotColorB = math.clamp(math.floor(b + 0.5), 0, 255)
    updateScopeDotStyle()
end

local function setScopeDotAlways(state)
    scopeHideState.dotAlways = state == true
    if scopeHideState.dotAlways then
        ensureScopeDot()
        setScopeDotVisible(true)
    elseif scopeHideState.enabled then
        setScopeDotVisible(scopeHideState.lastAim or scopeHideState.dotAlways)
    else
        setScopeDotVisible(false)
    end
end

setScopeDotVisible = function(visible)
    if scopeHideState.dot then
        scopeHideState.dot.Visible = visible == true
    end
end

local function scanScopeUi(root)
    if not root then
        return
    end
    for _, inst in ipairs(root:GetDescendants()) do
        if matchesScopeName(inst.Name) then
            addScopeTarget(inst)
        end
    end
    table.insert(scopeHideState.conns, root.DescendantAdded:Connect(function(inst)
        if matchesScopeName(inst.Name) then
            addScopeTarget(inst)
        end
    end))
    table.insert(scopeHideState.conns, root.DescendantRemoving:Connect(function(inst)
        scopeHideState.targets[inst] = nil
        scopeHideState.originals[inst] = nil
    end))
end

local function applyScopeHidden(aiming)
    setScopeDotVisible(aiming or scopeHideState.dotAlways)
    for inst in pairs(scopeHideState.targets) do
        if inst and inst.Parent then
            local original = scopeHideState.originals[inst]
            if inst:IsA("GuiObject") then
                if aiming then
                    inst.Visible = false
                elseif original then
                    inst.Visible = original.Visible
                end
            elseif inst:IsA("LayerCollector") then
                if aiming then
                    inst.Enabled = false
                elseif original then
                    inst.Enabled = original.Enabled
                end
            end
        else
            scopeHideState.targets[inst] = nil
            scopeHideState.originals[inst] = nil
        end
    end
end

local function setScopeHideEnabled(state)
    scopeHideState.enabled = state
    for _, conn in ipairs(scopeHideState.conns) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    scopeHideState.conns = {}

    if not state then
        applyScopeHidden(false)
        scopeHideState.targets = setmetatable({}, { __mode = "k" })
        scopeHideState.originals = setmetatable({}, { __mode = "k" })
        scopeHideState.lastAim = false
        if scopeHideState.dotAlways then
            ensureScopeDot()
            setScopeDotVisible(true)
        elseif scopeHideState.dotGui then
            scopeHideState.dotGui:Destroy()
        end
        if not scopeHideState.dotAlways then
            scopeHideState.dotGui = nil
            scopeHideState.dot = nil
        end
        return
    end

    ensureScopeDot()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") or nil
    scanScopeUi(playerGui)
    scanScopeUi(Services.CoreGui)

    local function update()
        local aiming = Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if aiming ~= scopeHideState.lastAim then
            scopeHideState.lastAim = aiming
            applyScopeHidden(aiming)
        end
    end

    table.insert(scopeHideState.conns, Services.RunService.RenderStepped:Connect(update))
    update()
end

local tweenMoveState = {
    enabled = false,
    speed = 18,
    platform = nil,
    tween = nil,
    conn = nil,
    charConn = nil,
    followConn = nil,
    tweenConn = nil,
    weld = nil,
    isTweening = false,
    folder = nil,
}

local function getTweenFolder()
    if tweenMoveState.folder and tweenMoveState.folder.Parent then
        return tweenMoveState.folder
    end
    local folder = Services.Workspace:FindFirstChild("TWW_Movement")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "TWW_Movement"
        folder.Parent = Services.Workspace
    end
    tweenMoveState.folder = folder
    return folder
end

local function buildTweenIgnoreList()
    local ignore = {}
    if LocalPlayer.Character then
        table.insert(ignore, LocalPlayer.Character)
    end
    local model = getLocalPlayerModel()
    if model and model ~= LocalPlayer.Character then
        table.insert(ignore, model)
    end
    if tweenMoveState.platform then
        table.insert(ignore, tweenMoveState.platform)
    end
    return ignore
end

local function ensureTweenPlatform()
    local platform = tweenMoveState.platform
    if platform and platform.Parent then
        return platform
    end
    platform = Instance.new("Part")
    platform.Name = "TWW_TweenPlatform"
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanTouch = false
    platform.CanQuery = false
    platform.Size = Vector3.new(6, 1, 6)
    platform.Material = Enum.Material.SmoothPlastic
    platform.Color = Color3.fromRGB(50, 200, 255)
    platform.Transparency = 0.35
    platform.Parent = getTweenFolder()
    tweenMoveState.platform = platform
    return platform
end

local function detachPlatformWeld()
    if tweenMoveState.weld then
        tweenMoveState.weld:Destroy()
        tweenMoveState.weld = nil
    end
end

local function attachPlatformWeld()
    local root = getLocalRootPart()
    if not root then
        return
    end
    local platform = ensureTweenPlatform()
    if not platform then
        return
    end
    local weld = tweenMoveState.weld
    if not weld or not weld.Parent then
        weld = Instance.new("WeldConstraint")
        weld.Name = "TWW_TweenWeld"
        weld.Parent = platform
        tweenMoveState.weld = weld
    end
    weld.Part0 = platform
    weld.Part1 = root
end

local function placePlatformUnderPlayer()
    local root = getLocalRootPart()
    if not root then
        return nil
    end
    local humanoid = getLocalHumanoid()
    local platform = ensureTweenPlatform()
    if not platform then
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = buildTweenIgnoreList()
    params.IgnoreWater = true

    local groundY = nil
    local hit = Services.Workspace:Raycast(root.Position, Vector3.new(0, -200, 0), params)
    if hit then
        groundY = hit.Position.Y
    else
        local hip = humanoid and humanoid.HipHeight or 2
        groundY = root.Position.Y - (root.Size.Y * 0.5 + hip)
    end
    local y = groundY + (platform.Size.Y * 0.5)
    platform.CFrame = CFrame.new(root.Position.X, y, root.Position.Z)
    return platform
end

local function getClickTarget()
    local cam = getCamera()
    if not cam then
        return nil
    end
    local mousePos = Services.UserInputService:GetMouseLocation()
    local inset = Services.GuiService:GetGuiInset()
    local x = mousePos.X - inset.X
    local y = mousePos.Y - inset.Y
    local ray = cam:ViewportPointToRay(x, y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = buildTweenIgnoreList()
    params.IgnoreWater = true

    local result = Services.Workspace:Raycast(ray.Origin, ray.Direction * 10000, params)
    if not result then
        return nil
    end

    local hitPos = result.Position
    if result.Normal and result.Normal.Y < 0.6 then
        local ground = Services.Workspace:Raycast(hitPos + Vector3.new(0, 6, 0), Vector3.new(0, -200, 0), params)
        if ground then
            hitPos = ground.Position
        end
    end
    return hitPos
end

local function startPlatformTween(targetPos)
    if not targetPos then
        return
    end
    local platform = ensureTweenPlatform()
    if not platform then
        return
    end

    detachPlatformWeld()
    placePlatformUnderPlayer()
    attachPlatformWeld()

    local target = Vector3.new(targetPos.X, targetPos.Y + (platform.Size.Y * 0.5), targetPos.Z)
    local distance = (platform.Position - target).Magnitude
    local speed = math.max(tonumber(tweenMoveState.speed) or 18, 1)
    local duration = math.max(distance / speed, 0.05)

    if tweenMoveState.tween then
        pcall(function()
            tweenMoveState.tween:Cancel()
        end)
        tweenMoveState.tween = nil
    end
    if tweenMoveState.tweenConn then
        tweenMoveState.tweenConn:Disconnect()
        tweenMoveState.tweenConn = nil
    end

    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    tweenMoveState.tween = TweenService:Create(platform, info, { CFrame = CFrame.new(target) })
    tweenMoveState.isTweening = true
    tweenMoveState.tweenConn = tweenMoveState.tween.Completed:Connect(function()
        tweenMoveState.isTweening = false
        detachPlatformWeld()
    end)
    tweenMoveState.tween:Play()
end

local function setTweenMoveSpeed(value)
    local num = tonumber(value)
    if not num then
        return
    end
    tweenMoveState.speed = math.clamp(num, 8, 30)
end

local function setTweenMoveEnabled(state)
    tweenMoveState.enabled = state == true

    if tweenMoveState.conn then
        tweenMoveState.conn:Disconnect()
        tweenMoveState.conn = nil
    end
    if tweenMoveState.charConn then
        tweenMoveState.charConn:Disconnect()
        tweenMoveState.charConn = nil
    end
    if tweenMoveState.followConn then
        tweenMoveState.followConn:Disconnect()
        tweenMoveState.followConn = nil
    end
    if tweenMoveState.tweenConn then
        tweenMoveState.tweenConn:Disconnect()
        tweenMoveState.tweenConn = nil
    end

    if not tweenMoveState.enabled then
        tweenMoveState.isTweening = false
        if tweenMoveState.tween then
            pcall(function()
                tweenMoveState.tween:Cancel()
            end)
            tweenMoveState.tween = nil
        end
        detachPlatformWeld()
        if tweenMoveState.platform then
            tweenMoveState.platform:Destroy()
            tweenMoveState.platform = nil
        end
        return
    end

    placePlatformUnderPlayer()

    tweenMoveState.conn = Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not tweenMoveState.enabled then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = getClickTarget()
            if target then
                startPlatformTween(target)
            end
        end
    end)

    tweenMoveState.charConn = LocalPlayer.CharacterAdded:Connect(function()
        if tweenMoveState.enabled then
            task.wait(0.1)
            placePlatformUnderPlayer()
        end
    end)

    tweenMoveState.followConn = Services.RunService.Heartbeat:Connect(function()
        if not tweenMoveState.enabled or tweenMoveState.isTweening then
            return
        end
        placePlatformUnderPlayer()
    end)
end

disableAllEsp = function()
    local esp = TWW.Esp
    if esp then
        if esp.enableAnimals then
            esp.enableAnimals(false)
        end
        if esp.enableDropped then
            esp.enableDropped(false)
        end
        if esp.enablePlayerEsp then
            esp.enablePlayerEsp(false)
        end
        if esp.enableNpcEsp then
            esp.enableNpcEsp(false)
        end
        if esp.enableTrees then
            esp.enableTrees(false)
        end
        if esp.enableTrains then
            esp.enableTrains(false)
        end
        if esp.enableForts then
            esp.enableForts(false)
        end
        if esp.enableOres then
            esp.enableOres(false)
        end
    end
    setFullbright(false)
    setFovEnabled(false)
    resetSfxVolume()
    setPostEffectsOff(false)
    setAimAssistEnabled(false)
    setScopeHideEnabled(false)
    setTweenMoveEnabled(false)
end

TWW.disableAllEsp = disableAllEsp

local function buildEspTab()
    Tabs.Esp:Separator("Entities")
    Tabs.Esp:Toggle("Player ESP", function(state)
        if TWW.Esp and TWW.Esp.enablePlayerEsp then
            TWW.Esp.enablePlayerEsp(state)
        end
    end, false)

    Tabs.Esp:Toggle("NPC ESP", function(state)
        if TWW.Esp and TWW.Esp.enableNpcEsp then
            TWW.Esp.enableNpcEsp(state)
        end
    end, false)

    Tabs.Esp:Toggle("Animal Heads + Labels", function(state)
        if TWW.Esp and TWW.Esp.enableAnimals then
            TWW.Esp.enableAnimals(state)
        end
    end, false)

    Tabs.Esp:Separator("World")
    Tabs.Esp:Toggle("Tree ESP", function(state)
        if TWW.Esp and TWW.Esp.enableTrees then
            TWW.Esp.enableTrees(state)
        end
    end, false)

    Tabs.Esp:Toggle("Train ESP", function(state)
        if TWW.Esp and TWW.Esp.enableTrains then
            TWW.Esp.enableTrains(state)
        end
    end, false)

    Tabs.Esp:Toggle("Forts Labels", function(state)
        if TWW.Esp and TWW.Esp.enableForts then
            TWW.Esp.enableForts(state)
        end
    end, false)

    Tabs.Esp:Separator("Items")
    Tabs.Esp:Toggle("Dropped Items", function(state)
        if TWW.Esp and TWW.Esp.enableDropped then
            TWW.Esp.enableDropped(state)
        end
    end, false)

    Tabs.Esp:Toggle("Ore ESP", function(state)
        if TWW.Esp and TWW.Esp.enableOres then
            TWW.Esp.enableOres(state)
        end
    end, false)
end

local function buildFiltersTab()
    if TWW.Esp and TWW.Esp.buildTreeCheckboxes then
        TWW.Esp.buildTreeCheckboxes(Tabs.Filters)
    end
    if TWW.Esp and TWW.Esp.buildOreCheckboxes then
        TWW.Esp.buildOreCheckboxes(Tabs.Filters)
    end
    if TWW.Esp and TWW.Esp.buildAnimalExcludeCheckboxes then
        TWW.Esp.buildAnimalExcludeCheckboxes(Tabs.Filters)
    end
end

local function buildConfigTab()
    Tabs.Config:Separator("Config")
    Tabs.Config:Button("Save Config", function()
        if Window and Window.SaveConfig then
            Window:SaveConfig()
        end
        local info = Window and Window.GetConfigInfo and Window:GetConfigInfo() or nil
        local cfg = Window and Window.GetConfig and Window:GetConfig() or {}
        local keys = {}
        for key, value in pairs(cfg) do
            table.insert(keys, string.format("%s=%s", tostring(key), tostring(value)))
        end
        table.sort(keys)
        print(string.format("[Config] Saved %d entries", #keys))
        if info then
            print(string.format("[Config] File: %s | Key: %s | AutoSave: %s", tostring(info.File), tostring(info.Key), tostring(info.AutoSave)))
        end
        for _, line in ipairs(keys) do
            print("[Config] " .. line)
        end
        if Window and Window.Notify then
            Window:Notify("Config saved", 2)
        end
    end)

    Tabs.Config:Button("Load Config", function()
        if Window and Window.LoadConfig then
            Window:LoadConfig()
            if Window and Window.Notify then
                Window:Notify("Config loaded", 2)
            end
        end
    end)

    Tabs.Config:Button("Reset Config", function()
        if Window and Window.ClearConfig then
            Window:ClearConfig()
            if Window and Window.Notify then
                Window:Notify("Config reset", 2)
            end
        end
    end)
end

local function buildVisualsTab()
    Tabs.Visuals:Separator("Lighting")
    Tabs.Visuals:Toggle("Fullbright", function(state)
        setFullbright(state)
    end, false)

    Tabs.Visuals:Toggle("Disable Post Effects", function(state)
        setPostEffectsOff(state)
    end, false)

    Tabs.Visuals:Separator("Crosshair")
    Tabs.Visuals:Toggle("Crosshair Always On", function(state)
        setScopeDotAlways(state)
    end, false)

    Tabs.Visuals:Slider("Crosshair Size", 2, 20, scopeHideState.dotSize, function(value)
        setScopeDotSize(value)
    end, 1)

    Tabs.Visuals:Slider("Crosshair Opacity", 0, 1, scopeHideState.dotOpacity, function(value)
        setScopeDotOpacity(value)
    end, 0.05)

    Tabs.Visuals:Slider("Crosshair Red", 0, 255, scopeHideState.dotColorR, function(value)
        setScopeDotColor(value, scopeHideState.dotColorG, scopeHideState.dotColorB)
    end, 1)

    Tabs.Visuals:Slider("Crosshair Green", 0, 255, scopeHideState.dotColorG, function(value)
        setScopeDotColor(scopeHideState.dotColorR, value, scopeHideState.dotColorB)
    end, 1)

    Tabs.Visuals:Slider("Crosshair Blue", 0, 255, scopeHideState.dotColorB, function(value)
        setScopeDotColor(scopeHideState.dotColorR, scopeHideState.dotColorG, value)
    end, 1)

    Tabs.Visuals:Separator("Scope/Binoculars")
    Tabs.Visuals:Toggle("Hide Scope/Binoculars When Aiming", function(state)
        setScopeHideEnabled(state)
    end, false)
end

local function buildAimTab()
    Tabs.Aim:Separator("Aim Assist")
    Tabs.Aim:Toggle("Aim Lock (Circle)", function(state)
        setAimAssistEnabled(state)
    end, false)

    Tabs.Aim:Toggle("Aim Rotate Body", function(state)
        setAimAssistRotateBody(state)
    end, false)

    Tabs.Aim:Toggle("Only Visible Targets", function(state)
        aimAssistState.onlyVisible = state == true
    end, false)

    Tabs.Aim:Toggle("Show Aim Circle", function(state)
        setAimAssistShowCircle(state)
    end, true)

    Tabs.Aim:Slider("Aim Circle Radius", 40, 400, aimAssistState.radius, function(value)
        setAimAssistRadius(value)
    end, 5)
end

local function buildClientTab()
    Tabs.Client:Separator("Camera")
    Tabs.Client:Toggle("FOV Override", function(state)
        setFovEnabled(state)
    end, false)

    do
        local cam = getCamera()
        if cam then
            fovState.value = cam.FieldOfView
        end
    end

    Tabs.Client:Slider("FOV", 40, 120, fovState.value, function(value)
        setFovValue(value)
    end, 1)

    Tabs.Client:Button("Reset FOV", function()
        resetFov()
    end)

    Tabs.Client:Separator("Movement")
    Tabs.Client:Toggle("Click Tween Move", function(state)
        setTweenMoveEnabled(state)
    end, false)

    Tabs.Client:Slider("Tween Speed", 8, 30, tweenMoveState.speed, function(value)
        setTweenMoveSpeed(value)
    end, 0.5)
end

local function buildAudioTab()
    Tabs.Audio:Separator("Audio")
    do
        local defaultVol = 10
        local gs = getGameSettings()
        if gs and gs.MasterVolume ~= nil then
            defaultVol = math.clamp(gs.MasterVolume * 10, 0, 10)
        else
            local ok, vol = pcall(function()
                return Services.SoundService.Volume
            end)
            if ok and type(vol) == "number" then
                defaultVol = vol
            end
        end
        Tabs.Audio:Slider("SFX Volume", 0, 10, defaultVol, function(value)
            setSfxVolume(value)
        end, 0.1)
    end

    Tabs.Audio:Button("Reset SFX Volume", function()
        resetSfxVolume()
    end)
end

local function buildUi()
    if TWW._uiBuilt then
        return
    end
    ensureWindowAndTabs()
    TWW._uiBuilt = true
    buildEspTab()
    buildFiltersTab()
    buildConfigTab()
    buildVisualsTab()
    buildAimTab()
    buildClientTab()
    buildAudioTab()
end

TWW.buildUi = buildUi
