-- main.lua — UI + loader + inline Misc table
-- ═══════════════════════════════════════════════════════════
--  SETUP
-- ═══════════════════════════════════════════════════════════
-- 1. Upload esp.lua + silentaim.lua to a PUBLIC GitHub repo
--    (or gist) at the root.
-- 2. Replace BASE_URL below with the RAW base, e.g.:
--    "https://raw.githubusercontent.com/you/repo/main/"
-- 3. Run THIS file in your executor.
-- ═══════════════════════════════════════════════════════════

local BASE_URL = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/"

-- ═══════════════════════════════════════════════════════════
--  INLINE MISC (move to misc.lua later)
-- ═══════════════════════════════════════════════════════════
local Players     = game:GetService("Players")
local Workspace   = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Misc = {}

Misc.Config = {
    -- Silent Aim
    SilentAimEnabled   = true,
    SilentAimPart      = "Head",
    SilentAimHitChance = 100,
    RayOriginTolerance = 20,

    -- FOV
    FOVRadius          = 70,
    FOVColor           = Color3.fromRGB(0, 255, 150),

    -- ESP
    ESPEnabled         = true,
    BoxColor           = Color3.fromRGB(0, 255, 150),
    DistanceColor      = Color3.fromRGB(230, 230, 230),
    BoxThickness       = 1,
    BoxTransparency    = 0.8,
    MaxDistance        = math.huge,
}

Misc.ActiveModels  = {}
Misc.WatchedModels = {}

function Misc.getParts(model)
    local root = model:FindFirstChild("HumanoidRootPart")
              or model:FindFirstChild("Torso")
              or model:FindFirstChild("UpperTorso")
    local head = model:FindFirstChild(Misc.Config.SilentAimPart)
              or model:FindFirstChild("Head")
    return root, head
end

function Misc.isValidModel(model)
    if not model or not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    if model.Name:lower():find("_corpse") then return false end
    local q = model:FindFirstChild("Query")
    if not q or not q:IsA("BindableFunction") then return false end
    local root, head = Misc.getParts(model)
    return root ~= nil and head ~= nil
end

function Misc.getDistance(part)
    local ch = LocalPlayer.Character
    if not ch then return math.huge end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return math.huge end
    return (root.Position - part.Position).Magnitude
end

function Misc.getScreenPosition(part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return nil, false end
    local pos, visible = cam:WorldToViewportPoint(part.Position)
    return Vector2.new(pos.X, pos.Y), (visible and pos.Z > 0)
end

function Misc.getClosestTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp     = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestDist = nil, Misc.Config.FOVRadius

    for model in pairs(Misc.ActiveModels) do
        if model.Parent and Misc.isValidModel(model) then
            local _, head = Misc.getParts(model)
            if head then
                local screenPos, visible = Misc.getScreenPosition(head)
                if visible then
                    local sdist = (screenPos - center).Magnitude
                    local wdist = Misc.getDistance(head)
                    if sdist <= bestDist and wdist <= Misc.Config.MaxDistance then
                        bestDist = sdist
                        best     = model
                    end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════
--  MODULE LOADER
-- ═══════════════════════════════════════════════════════════
local function loadModule(name)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. name .. ".lua"))()
    end)
    if not ok or res == nil then
        error("[LOADER] Failed to load " .. name .. ": " .. tostring(res))
    end
    return res
end

local ESP       = loadModule("esp")(Misc)
local SilentAim = loadModule("silentaim")(Misc)

ESP:Init()
SilentAim:Init()

-- ═══════════════════════════════════════════════════════════
--  UI (Rayfield)
-- ═══════════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Silent Aim + ESP",
    LoadingTitle = "Silent Aim + ESP",
    LoadingSubtitle = "by you",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SilentAimESP",
        FileName   = "Config",
    },
    KeySystem = false,
})

-- ─── Silent Aim tab ────────────────────────────────────────
local AimTab = Window:CreateTab("Silent Aim", 4483362458)

AimTab:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = true,
    Flag = "AimEnabled",
    Callback = function(v) SilentAim:SetEnabled(v) end,
})

AimTab:CreateSlider({
    Name = "FOV Radius",
    Range = {10, 500},
    Increment = 5,
    Suffix = "px",
    CurrentValue = 70,
    Flag = "FOVRadius",
    Callback = function(v) Misc.Config.FOVRadius = v end,
})

AimTab:CreateSlider({
    Name = "Hit Chance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "HitChance",
    Callback = function(v) Misc.Config.SilentAimHitChance = v end,
})

AimTab:CreateSlider({
    Name = "Ray Origin Tolerance",
    Range = {3, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 20,
    Flag = "RayTol",
    Callback = function(v) Misc.Config.RayOriginTolerance = v end,
})

AimTab:CreateDropdown({
    Name = "Aim Part",
    Options = {"Head", "Torso", "UpperTorso", "HumanoidRootPart"},
    CurrentOption = {"Head"},
    Flag = "AimPart",
    Callback = function(opt)
        local part = type(opt) == "table" and opt[1] or opt
        Misc.Config.SilentAimPart = part
    end,
})

AimTab:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Color3.fromRGB(0, 255, 150),
    Flag = "FOVColor",
    Callback = function(c) Misc.Config.FOVColor = c end,
})

-- ─── ESP tab ───────────────────────────────────────────────
local EspTab = Window:CreateTab("ESP", 4483362458)

EspTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = true,
    Flag = "EspEnabled",
    Callback = function(v) ESP:SetEnabled(v) end,
})

EspTab:CreateColorPicker({
    Name = "Box Color",
    Color = Color3.fromRGB(0, 255, 150),
    Flag = "BoxColor",
    Callback = function(c) Misc.Config.BoxColor = c end,
})

EspTab:CreateColorPicker({
    Name = "Distance Text Color",
    Color = Color3.fromRGB(230, 230, 230),
    Flag = "DistColor",
    Callback = function(c) Misc.Config.DistanceColor = c end,
})

EspTab:CreateSlider({
    Name = "Box Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 1,
    Flag = "BoxThick",
    Callback = function(v) Misc.Config.BoxThickness = v end,
})

EspTab:CreateSlider({
    Name = "Box Transparency",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.8,
    Flag = "BoxTrans",
    Callback = function(v) Misc.Config.BoxTransparency = v end,
})

-- ─── Misc tab ──────────────────────────────────────────────
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Script")
MiscTab:CreateButton({
    Name = "Unload Script",
    Callback = function()
        SilentAim:Unload()
        ESP:Unload()
        pcall(function() Rayfield:Destroy() end)
        print("[MAIN] Unloaded")
    end,
})

MiscTab:CreateSection("About")
MiscTab:CreateParagraph({
    Title = "Silent Aim + ESP",
    Content = "Modular build (main.lua + esp.lua + silentaim.lua).\nRaycasts from the camera are redirected to the closest target inside the FOV. Camera does not move.",
})

pcall(function() Rayfield:LoadConfiguration() end)

pcall(function()
    Rayfield:Notify({
        Title    = "Loaded",
        Content  = "Silent Aim + ESP is ready",
        Duration = 3,
        Image    = 4483362458,
    })
end)

print("[MAIN] Loaded — Silent Aim + ESP with Rayfield UI")
