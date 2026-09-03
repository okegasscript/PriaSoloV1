-- ============================================================
-- MAIN SCRIPT - Pria Solo HUB
-- ============================================================

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

_G.ACTIVE_MODULE = nil
_G.LEVELING_TOGGLE = nil
_G.AUTO_SHARK_TOGGLE = nil
_G.GardenCFrame = nil

local DataPetModule
local loadSuccess, loadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"))()
end)
if loadSuccess and loadResult then
    DataPetModule = loadResult
    print("[Main] DataPetModule berhasil dimuat")
else
    warn("[Main] Gagal memuat DataPetModule:", loadResult)
end

local Window = Fluent:CreateWindow({
    Title = "Pria Solo HUB",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 400),
    Acrylic = false,
    Theme = "Rose",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Load Leveling
local lvlSuccess, lvlResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/Leveling.lua"))()
end)
if lvlSuccess and lvlResult then
    local LevelingModule = lvlResult
    if type(LevelingModule.Setup) == "function" then
        LevelingModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] Leveling.lua berhasil")
    end
else
    warn("[Main] Gagal memuat Leveling.lua:", lvlResult)
end

-- Load PNP
local pnpSuccess, pnpResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/PNP.lua"))()
end)
if pnpSuccess and pnpResult then
    local PNPModule = pnpResult
    if type(PNPModule.Setup) == "function" then
        PNPModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] PNP.lua berhasil")
    end
else
    warn("[Main] Gagal memuat PNP.lua:", pnpResult)
end

-- Load AutoShark
local sharkSuccess, sharkResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/AutoShark.lua"))()
end)
if sharkSuccess and sharkResult then
    local AutoSharkModule = sharkResult
    if type(AutoSharkModule.Setup) == "function" then
        AutoSharkModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] AutoShark.lua berhasil")
    end
else
    warn("[Main] Gagal memuat AutoShark.lua:", sharkResult)
end

pcall(function()
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("PriaSoloHUB")
    InterfaceManager:BuildInterfaceSection(Window)
    Window:OnClose(function()
        SaveManager:Save()
        InterfaceManager:Save()
    end)
    SaveManager:Load()
    InterfaceManager:Load()
end)

Fluent:Notify({
    Title = "Pria Solo HUB",
    Description = "Script siap digunakan! (Tema Rose)",
    Duration = 3
})

print("[Main] Pria Solo HUB selesai dimuat.")
