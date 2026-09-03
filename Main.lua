-- ============================================================
-- MAIN SCRIPT - Pria Solo HUB (Final)
-- Memuat semua modul terpisah: DataPetModule, Leveling, PNP, AutoShark
-- Mutual exclusion antara Leveling dan AutoShark
-- ============================================================

-- Load Library Fluent
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================
-- INISIALISASI GLOBAL UNTUK MUTUAL EXCLUSION
-- ============================================================
_G.ACTIVE_MODULE = nil        -- "Leveling" atau "AutoShark"
_G.LEVELING_TOGGLE = nil      -- referensi toggle leveling
_G.AUTO_SHARK_TOGGLE = nil    -- referensi toggle auto shark

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
-- BUAT WINDOW UTAMA
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
-- LANGSUNG BUKA TAB LEVELING (jika ada)
-- ============================================================
task.wait(0.1)
Window:SelectTab("Leveling")

-- ============================================================
-- LOAD & SETUP LEVELING.LUA
-- ============================================================
local LevelingModule
local levelingLoadSuccess, levelingLoadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/Leveling.lua"))()
end)
if levelingLoadSuccess and levelingLoadResult then
    LevelingModule = levelingLoadResult
    if type(LevelingModule.Setup) == "function" then
        LevelingModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] Leveling.lua berhasil dimuat dan dijalankan")
    else
        warn("[Main] Leveling.lua tidak memiliki fungsi Setup")
    end
else
    warn("[Main] Gagal memuat Leveling.lua:", levelingLoadResult)
    local fallbackTab = Window:AddTab({ Title = "Leveling" })
    fallbackTab:AddParagraph({ Title = "Error", Content = "Gagal memuat Leveling.lua" })
end

-- ============================================================
-- LOAD & SETUP PNP.LUA
-- ============================================================
local PNPModule
local pnpLoadSuccess, pnpLoadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/PNP.lua"))()
end)
if pnpLoadSuccess and pnpLoadResult then
    PNPModule = pnpLoadResult
    if type(PNPModule.Setup) == "function" then
        PNPModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] PNP.lua berhasil dimuat dan dijalankan")
    else
        warn("[Main] PNP.lua tidak memiliki fungsi Setup")
    end
else
    warn("[Main] Gagal memuat PNP.lua:", pnpLoadResult)
    local fallbackTab = Window:AddTab({ Title = "PNP" })
    fallbackTab:AddParagraph({ Title = "Error", Content = "Gagal memuat PNP.lua" })
end

-- ============================================================
-- LOAD & SETUP AUTOSHARK.LUA
-- ============================================================
local AutoSharkModule
local sharkLoadSuccess, sharkLoadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/AutoShark.lua"))()
end)
if sharkLoadSuccess and sharkLoadResult then
    AutoSharkModule = sharkLoadResult
    if type(AutoSharkModule.Setup) == "function" then
        AutoSharkModule.Setup(Window, DataPetModule, Fluent)
        print("[Main] AutoShark.lua berhasil dimuat dan dijalankan")
    else
        warn("[Main] AutoShark.lua tidak memiliki fungsi Setup")
    end
else
    warn("[Main] Gagal memuat AutoShark.lua:", sharkLoadResult)
    local fallbackTab = Window:AddTab({ Title = "AutoShark" })
    fallbackTab:AddParagraph({ Title = "Error", Content = "Gagal memuat AutoShark.lua" })
end

-- ============================================================
-- SETUP SAVEMANAGER & INTERFACEMANAGER
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

-- ============================================================
-- NOTIFIKASI AWAL
-- ============================================================
Fluent:Notify({
    Title = "Pria Solo HUB",
    Description = "Script siap digunakan! (Tema Rose - Modular)",
    Duration = 3
})

print("[Main] Pria Solo HUB selesai dimuat (semua modul terpisah)")
