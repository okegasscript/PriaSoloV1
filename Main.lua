-- ============================================================
-- MAIN SCRIPT - Pria Solo HUB (Final)
-- Memuat semua modul terpisah
-- ============================================================

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================
-- INISIALISASI GLOBAL
-- ============================================================
_G.ACTIVE_MODULE = nil
_G.LEVELING_TOGGLE = nil
_G.AUTO_SHARK_TOGGLE = nil
_G.GardenCFrame = nil

-- ============================================================
-- LOAD DATAPETMODULE
-- ============================================================
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

-- ============================================================
-- BUAT WINDOW
-- ============================================================
local Window = Fluent:CreateWindow({
    Title = "Pria Solo HUB",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 400),
    Acrylic = false,
    Theme = "Rose",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ============================================================
-- LOAD LEVELING
-- ============================================================
local LevelingModule
local lvlSuccess, lvlResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/Leveling.lua"))()
end)
if lvlSuccess and lvlResult then
    LevelingModule = lvlResult
    if type(LevelingModule.Setup) == "function" then
        LevelingModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] Leveling.lua berhasil")
    end
else
    warn("[Main] Gagal memuat Leveling.lua:", lvlResult)
    local fallback = Window:AddTab({ Title = "Leveling" })
    fallback:AddParagraph({ Title = "Error", Content = "Gagal memuat Leveling.lua" })
end

-- ============================================================
-- LOAD PNP
-- ============================================================
local PNPModule
local pnpSuccess, pnpResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/PNP.lua"))()
end)
if pnpSuccess and pnpResult then
    PNPModule = pnpResult
    if type(PNPModule.Setup) == "function" then
        PNPModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] PNP.lua berhasil")
    end
else
    warn("[Main] Gagal memuat PNP.lua:", pnpResult)
    local fallback = Window:AddTab({ Title = "PNP" })
    fallback:AddParagraph({ Title = "Error", Content = "Gagal memuat PNP.lua" })
end

-- ============================================================
-- LOAD AUTOSHARK
-- ============================================================
local AutoSharkModule
local sharkSuccess, sharkResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/AutoShark.lua"))()
end)
if sharkSuccess and sharkResult then
    AutoSharkModule = sharkResult
    if type(AutoSharkModule.Setup) == "function" then
        AutoSharkModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] AutoShark.lua berhasil")
    end
else
    warn("[Main] Gagal memuat AutoShark.lua:", sharkResult)
    local fallback = Window:AddTab({ Title = "AutoShark" })
    fallback:AddParagraph({ Title = "Error", Content = "Gagal memuat AutoShark.lua" })
end

-- ============================================================
-- SAVEMANAGER
-- ============================================================
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
