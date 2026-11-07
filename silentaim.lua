-- silentaim.lua — returns function(Misc) -> SilentAim module
return function(Misc)
    local RunService = game:GetService("RunService")
    local Workspace  = game:GetService("Workspace")

    local SilentAim = {}
    local enabled   = true

    local redirectState   = false
    local targetPosCache  = nil
    local targetPartCache = nil
    local camPosCache     = nil

    local oldNamecall, oldIndex
    local hooked = false

    local FOV = Drawing.new("Circle")
    FOV.Visible      = false
    FOV.Thickness    = 1
    FOV.NumSides     = 64
    FOV.Filled       = false
    FOV.Transparency = 0.8

    local function shouldAttemptRedirect()
        if not enabled then return false end
        if not redirectState then return false end
        if targetPosCache == nil or targetPartCache == nil or camPosCache == nil then return false end
        if type(checkcaller) ~= "function" then return false end
        return not checkcaller()
    end

    local function hook()
        if hooked then return end
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
            warn("[SILENT AIM] Executor missing hookmetamethod")
            return
        end
        local wrap = (type(newcclosure) == "function") and newcclosure or function(f) return f end

        local ok1, err1 = pcall(function()
            oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if not shouldAttemptRedirect() then return oldNamecall(self, ...) end
                if self ~= Workspace then return oldNamecall(self, ...) end

                local method = getnamecallmethod()
                if method ~= "Raycast"
                    and method ~= "FindPartOnRay"
                    and method ~= "FindPartOnRayWithIgnoreList"
                    and method ~= "FindPartOnRayWithWhitelist" then
                    return oldNamecall(self, ...)
                end

                local args = table.pack(...)

                if method == "Raycast" then
                    local origin, direction = args[1], args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        if (origin - camPosCache).Magnitude <= Misc.Config.RayOriginTolerance then
                            local newDir = targetPosCache - origin
                            if newDir.Magnitude > 0.01 then
                                args[2] = newDir
                                return oldNamecall(self, table.unpack(args, 1, args.n))
                            end
                        end
                    end
                else
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        if (ray.Origin - camPosCache).Magnitude <= Misc.Config.RayOriginTolerance then
                            local newDir = targetPosCache - ray.Origin
                            if newDir.Magnitude > 0.01 then
                                args[1] = Ray.new(ray.Origin, newDir)
                                return oldNamecall(self, table.unpack(args, 1, args.n))
                            end
                        end
                    end
                end

                return oldNamecall(self, ...)
            end))
        end)
        if not ok1 then warn("[SILENT AIM] __namecall hook failed:", err1) end

        local ok2, err2 = pcall(function()
            oldIndex = hookmetamethod(game, "__index", wrap(function(t, k)
                if k ~= "Hit" and k ~= "Target" then return oldIndex(t, k) end
                if not shouldAttemptRedirect() then return oldIndex(t, k) end
                if typeof(t) ~= "Instance" then return oldIndex(t, k) end
                local ok, isMouse = pcall(t.IsA, t, "Mouse")
                if not ok or not isMouse then return oldIndex(t, k) end
                if k == "Hit" then return CFrame.new(targetPosCache) end
                return targetPartCache
            end))
        end)
        if not ok2 then warn("[SILENT AIM] __index hook failed:", err2) end

        hooked = true
    end

    local function unhook()
        if not hooked then return end
        if oldNamecall then pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end) end
        if oldIndex    then pcall(function() hookmetamethod(game, "__index",    oldIndex)    end) end
        hooked = false
    end

    function SilentAim:SetEnabled(v)
        enabled = v
        FOV.Visible = v
        if not v then
            redirectState   = false
            targetPosCache  = nil
            targetPartCache = nil
        end
    end

    function SilentAim:Init()
        FOV.Visible = enabled
        hook()

        RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then FOV.Visible = false return end

            FOV.Visible = enabled
            if enabled then
                FOV.Color  = Misc.Config.FOVColor
                FOV.Radius = Misc.Config.FOVRadius
                local vp = cam.ViewportSize
                FOV.Position = Vector2.new(vp.X / 2, vp.Y / 2)
            end

            camPosCache = cam.CFrame.Position

            if not enabled then
                redirectState = false
                return
            end

            local target = Misc.getClosestTarget()
            if target and target.Parent then
                local _, head = Misc.getParts(target)
                if head and head.Parent then
                    targetPosCache  = head.Position
                    targetPartCache = head
                    redirectState   = math.random(1, 100) <= Misc.Config.SilentAimHitChance
                    return
                end
            end
            redirectState   = false
            targetPosCache  = nil
            targetPartCache = nil
        end)
    end

    function SilentAim:Unload()
        enabled = false
        unhook()
        pcall(function()
            FOV.Visible = false
            FOV:Remove()
        end)
    end

    return SilentAim
end
