-- ============================================================
-- MAIN SCRIPT - Leveling UI dengan Fluent (Multi-Select Dropdown)
-- Memuat DataPetModule dari GitHub (versi terbaru dengan berat otomatis)
-- Format pet: "Mutation Name Weightkg LvLevel"
-- Tema: Rose (pink), Ukuran diperkecil
-- ============================================================

-- Load Library Fluent
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================
-- LOAD DATAPETMODULE DARI GITHUB (versi terbaru)
-- ============================================================
local DataPetModule
local loadSuccess, loadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"))()
end)

if loadSuccess and loadResult then
    DataPetModule = loadResult
    print("[Leveling Script] DataPetModule berhasil dimuat (versi terbaru)")
else
    warn("[Leveling Script] Gagal memuat DataPetModule:", loadResult)
end

-- ============================================================
-- BUAT WINDOW UTAMA dengan judul "Pria Solo HUB" tema ROSE & ukuran kecil
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
-- TAB LEVELING
-- ============================================================
local LevelingTab = Window:AddTab({ Title = "Leveling" })

-- ============================================================
-- LANGSUNG BUKA TAB LEVELING SAAT SCRIPT DIJALANKAN
-- ============================================================
task.wait(0.1)
Window:SelectTab("Leveling")

-- ============================================================
-- VARIABEL GLOBAL LEVELING
-- ============================================================
local petOptionsLvl = {}
local selectedPetsLvl = {}
local selectedUUIDsLvl = {}
local dropdownControlLvl = nil
local infoParagraphLvl = nil

local petOptionsTarget = {}
local selectedPetsTarget = {}
local selectedUUIDsTarget = {}
local dropdownControlTarget = nil
local infoParagraphTarget = nil

local targetLevel = 100
local autoLevelEnabled = false

local SAVE_KEY_LVL = "SelectedPetUUIDs_Leveling"
local SAVE_KEY_TARGET = "SelectedPetUUIDs_Target"
local TARGET_KEY = "TargetLevel"
local ENABLE_KEY = "AutoLevelEnabled"

-- ============================================================
-- FUNGSI UPDATE INFO PET LEVELING (Favorite)
-- ============================================================
local function updatePetInfoLvl(pets)
    if not infoParagraphLvl then return end
    local contentText
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format(
                "%d. %s %s %.2fkg Lv%d",
                i,
                pet.mutation,
                pet.name,
                pet.weight,
                pet.level
            ))
        end
        contentText = "Pet Tim Leveling:\n" .. table.concat(lines, "\n")
    else
        contentText = "Belum ada pet dipilih (Tim Leveling)"
    end

    if infoParagraphLvl.SetContent then
        infoParagraphLvl:SetContent(contentText)
    else
        infoParagraphLvl.Content = contentText
    end
end

-- ============================================================
-- FUNGSI UPDATE INFO TARGET LEVELING
-- ============================================================
local function updatePetInfoTarget(pets)
    if not infoParagraphTarget then return end
    local contentText
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format(
                "%d. %s %s %.2fkg Lv%d",
                i,
                pet.mutation,
                pet.name,
                pet.weight,
                pet.level
            ))
        end
        contentText = "Pet Target (Non-Favorit):\n" .. table.concat(lines, "\n")
    else
        contentText = "Belum ada pet dipilih (Target Non-Favorit)"
    end

    if infoParagraphTarget.SetContent then
        infoParagraphTarget:SetContent(contentText)
    else
        infoParagraphTarget.Content = contentText
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN LEVELING (Favorite)
-- ============================================================
local function refreshPetDropdownLvl()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end

    local pets = DataPetModule.findPets({ isFavorite = true })
    if #pets == 0 then
        Fluent:Notify({ Title = "Info", Description = "Tidak ada pet favorite ditemukan", Duration = 5 })
        if dropdownControlLvl then dropdownControlLvl:SetValues({}) end
        petOptionsLvl = {}; selectedPetsLvl = {}; selectedUUIDsLvl = {}
        updatePetInfoLvl({})
        return
    end

    local values = {}
    petOptionsLvl = {}
    for _, pet in ipairs(pets) do
        local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
        table.insert(values, label)
        petOptionsLvl[label] = pet
    end

    if dropdownControlLvl then
        dropdownControlLvl:SetValues(values)
        local savedUUIDs = _G[SAVE_KEY_LVL]
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptionsLvl) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end
        if #restoredLabels > 0 then
            dropdownControlLvl:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptionsLvl[label] then table.insert(selected, petOptionsLvl[label]) end
            end
            selectedPetsLvl = selected
            selectedUUIDsLvl = {}
            for _, pet in ipairs(selected) do table.insert(selectedUUIDsLvl, pet.uuid) end
            updatePetInfoLvl(selected)
        else
            dropdownControlLvl:SetValue({})
            selectedPetsLvl = {}; selectedUUIDsLvl = {}
            updatePetInfoLvl({})
        end
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN TARGET (Non-Favorit)
-- ============================================================
local function refreshPetDropdownTarget()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end

    local pets = DataPetModule.findPets({ isFavorite = false })
    if #pets == 0 then
        Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit ditemukan", Duration = 5 })
        if dropdownControlTarget then dropdownControlTarget:SetValues({}) end
        petOptionsTarget = {}; selectedPetsTarget = {}; selectedUUIDsTarget = {}
        updatePetInfoTarget({})
        return
    end

    local values = {}
    petOptionsTarget = {}
    for _, pet in ipairs(pets) do
        local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
        table.insert(values, label)
        petOptionsTarget[label] = pet
    end

    if dropdownControlTarget then
        dropdownControlTarget:SetValues(values)
        local savedUUIDs = _G[SAVE_KEY_TARGET]
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptionsTarget) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end
        if #restoredLabels > 0 then
            dropdownControlTarget:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptionsTarget[label] then table.insert(selected, petOptionsTarget[label]) end
            end
            selectedPetsTarget = selected
            selectedUUIDsTarget = {}
            for _, pet in ipairs(selected) do table.insert(selectedUUIDsTarget, pet.uuid) end
            updatePetInfoTarget(selected)
        else
            dropdownControlTarget:SetValue({})
            selectedPetsTarget = {}; selectedUUIDsTarget = {}
            updatePetInfoTarget({})
        end
    end
end

-- ============================================================
-- BUAT KOMPONEN LEVELING
-- ============================================================
local sectionLvl = LevelingTab:AddSection("Pilih Pet Tim Leveling Favorit")
dropdownControlLvl = sectionLvl:AddDropdown("PetDropdownLvl", {
    Title = "Daftar Pet Favorite",
    Values = {},
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}; local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptionsLvl[label] then
                    table.insert(selected, petOptionsLvl[label])
                    table.insert(uuids, petOptionsLvl[label].uuid)
                end
            end
            selectedPetsLvl = selected; selectedUUIDsLvl = uuids
            _G[SAVE_KEY_LVL] = uuids
            updatePetInfoLvl(selected)
        else
            selectedPetsLvl = {}; selectedUUIDsLvl = {}
            _G[SAVE_KEY_LVL] = {}
            updatePetInfoLvl({})
        end
    end
})
sectionLvl:AddButton({ Title = "↻ Refresh Daftar Favorite", Callback = function() refreshPetDropdownLvl() end })
infoParagraphLvl = sectionLvl:AddParagraph({ Title = "Pet Tim Leveling", Content = "Belum ada pet dipilih (Tim Leveling)" })

local sectionTarget = LevelingTab:AddSection("Pilih Target Leveling (Non-Favorit)")
dropdownControlTarget = sectionTarget:AddDropdown("PetDropdownTarget", {
    Title = "Daftar Pet Non-Favorit",
    Values = {},
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}; local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptionsTarget[label] then
                    table.insert(selected, petOptionsTarget[label])
                    table.insert(uuids, petOptionsTarget[label].uuid)
                end
            end
            selectedPetsTarget = selected; selectedUUIDsTarget = uuids
            _G[SAVE_KEY_TARGET] = uuids
            updatePetInfoTarget(selected)
        else
            selectedPetsTarget = {}; selectedUUIDsTarget = {}
            _G[SAVE_KEY_TARGET] = {}
            updatePetInfoTarget({})
        end
    end
})
sectionTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownTarget() end })
infoParagraphTarget = sectionTarget:AddParagraph({ Title = "Pet Target (Non-Favorit)", Content = "Belum ada pet dipilih (Target Non-Favorit)" })

-- Pengaturan Leveling
local controlSectionLvl = LevelingTab:AddSection("Pengaturan Leveling")
local targetInput = controlSectionLvl:AddInput("TargetLevelInput", {
    Title = "Target Level",
    Placeholder = "Masukkan target level (angka)",
    Default = tostring(_G[TARGET_KEY] or 100),
    Numeric = true,
    Finished = false,
    Callback = function(value)
        local num = tonumber(value)
        if num and num > 0 then
            targetLevel = num
            _G[TARGET_KEY] = num
        else
            Fluent:Notify({ Title = "Error", Description = "Masukkan angka yang valid!", Duration = 3 })
        end
    end
})
local autoToggle = controlSectionLvl:AddToggle("AutoLevelToggle", {
    Title = "Auto Leveling",
    Description = "Aktifkan untuk mulai leveling otomatis",
    Default = _G[ENABLE_KEY] or false,
    Callback = function(value)
        autoLevelEnabled = value
        _G[ENABLE_KEY] = value
        if value then
            Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling diaktifkan!", Duration = 3 })
        else
            Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling dinonaktifkan", Duration = 3 })
        end
    end
})

-- ============================================================
-- TAB PNP
-- ============================================================
local PNPTab = Window:AddTab({ Title = "PNP" })

-- ============================================================
-- VARIABEL GLOBAL PNP
-- ============================================================
local petOptionsPNP = {}
local selectedPetsPNP = {}
local selectedUUIDsPNP = {}
local dropdownControlPNP = nil
local infoParagraphPNP = nil

local pickupDelay = 0.5
local placeDelay = 0.5
local autoPNPEnabled = false

local SAVE_KEY_PNP = "SelectedPetUUIDs_PNP"
local PICKUP_DELAY_KEY = "PickupDelay"
local PLACE_DELAY_KEY = "PlaceDelay"
local PNP_ENABLE_KEY = "AutoPNPEnabled"

-- ============================================================
-- FUNGSI UPDATE INFO PET PNP
-- ============================================================
local function updatePetInfoPNP(pets)
    if not infoParagraphPNP then return end
    local contentText
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
        end
        contentText = "Pet Terpilih:\n" .. table.concat(lines, "\n")
    else
        contentText = "Belum ada pet dipilih"
    end
    if infoParagraphPNP.SetContent then
        infoParagraphPNP:SetContent(contentText)
    else
        infoParagraphPNP.Content = contentText
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN PNP
-- ============================================================
local function refreshPetDropdownPNP()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end
    local pets = DataPetModule.findPets({ isFavorite = true })
    if #pets == 0 then
        Fluent:Notify({ Title = "Info", Description = "Tidak ada pet favorite ditemukan", Duration = 5 })
        if dropdownControlPNP then dropdownControlPNP:SetValues({}) end
        petOptionsPNP = {}; selectedPetsPNP = {}; selectedUUIDsPNP = {}
        updatePetInfoPNP({})
        return
    end
    local values = {}
    petOptionsPNP = {}
    for _, pet in ipairs(pets) do
        local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
        table.insert(values, label)
        petOptionsPNP[label] = pet
    end
    if dropdownControlPNP then
        dropdownControlPNP:SetValues(values)
        local savedUUIDs = _G[SAVE_KEY_PNP]
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptionsPNP) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end
        if #restoredLabels > 0 then
            dropdownControlPNP:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptionsPNP[label] then table.insert(selected, petOptionsPNP[label]) end
            end
            selectedPetsPNP = selected
            selectedUUIDsPNP = {}
            for _, pet in ipairs(selected) do table.insert(selectedUUIDsPNP, pet.uuid) end
            updatePetInfoPNP(selected)
        else
            dropdownControlPNP:SetValue({})
            selectedPetsPNP = {}; selectedUUIDsPNP = {}
            updatePetInfoPNP({})
        end
    end
end

-- ============================================================
-- BUAT KOMPONEN PNP
-- ============================================================
local sectionPNP = PNPTab:AddSection("Pilih Pet Favorite (Multi)")
dropdownControlPNP = sectionPNP:AddDropdown("PetDropdownPNP", {
    Title = "Daftar Pet Favorite",
    Values = {},
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}; local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptionsPNP[label] then
                    table.insert(selected, petOptionsPNP[label])
                    table.insert(uuids, petOptionsPNP[label].uuid)
                end
            end
            selectedPetsPNP = selected; selectedUUIDsPNP = uuids
            _G[SAVE_KEY_PNP] = uuids
            updatePetInfoPNP(selected)
        else
            selectedPetsPNP = {}; selectedUUIDsPNP = {}
            _G[SAVE_KEY_PNP] = {}
            updatePetInfoPNP({})
        end
    end
})
sectionPNP:AddButton({ Title = "↻ Refresh Daftar", Callback = function() refreshPetDropdownPNP() end })
infoParagraphPNP = sectionPNP:AddParagraph({ Title = "Pet Terpilih", Content = "Belum ada pet dipilih" })

-- Pengaturan PNP
local controlSectionPNP = PNPTab:AddSection("Pengaturan PNP")
local pickupInput = controlSectionPNP:AddInput("PickupDelayInput", {
    Title = "PickUp Delay (detik)",
    Placeholder = "Masukkan delay pickup",
    Default = tostring(_G[PICKUP_DELAY_KEY] or 0.5),
    Numeric = true,
    Finished = false,
    Callback = function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            pickupDelay = num
            _G[PICKUP_DELAY_KEY] = num
        else
            Fluent:Notify({ Title = "Error", Description = "Masukkan angka yang valid (>=0)!", Duration = 3 })
        end
    end
})
local placeInput = controlSectionPNP:AddInput("PlaceDelayInput", {
    Title = "Place Delay (detik)",
    Placeholder = "Masukkan delay place",
    Default = tostring(_G[PLACE_DELAY_KEY] or 0.5),
    Numeric = true,
    Finished = false,
    Callback = function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            placeDelay = num
            _G[PLACE_DELAY_KEY] = num
        else
            Fluent:Notify({ Title = "Error", Description = "Masukkan angka yang valid (>=0)!", Duration = 3 })
        end
    end
})
local autoPNPToggle = controlSectionPNP:AddToggle("AutoPNPToggle", {
    Title = "Auto PNP",
    Description = "Aktifkan untuk menjalankan PNP otomatis",
    Default = _G[PNP_ENABLE_KEY] or false,
    Callback = function(value)
        autoPNPEnabled = value
        _G[PNP_ENABLE_KEY] = value
        if value then
            Fluent:Notify({ Title = "Auto PNP", Description = "Auto PNP diaktifkan!", Duration = 3 })
        else
            Fluent:Notify({ Title = "Auto PNP", Description = "Auto PNP dinonaktifkan", Duration = 3 })
        end
    end
})

-- ============================================================
-- TAB AUTOSHARK
-- ============================================================
local AutoSharkTab = Window:AddTab({ Title = "AutoShark" })

-- ============================================================
-- VARIABEL GLOBAL AUTOSHARK
-- ============================================================
-- Tim Auto Shark (Favorite)
local petOptionsShark = {}
local selectedPetsShark = {}
local selectedUUIDsShark = {}
local dropdownControlShark = nil
local infoParagraphShark = nil

-- Target Pet (Non-Favorit)
local petOptionsSharkTarget = {}
local selectedPetsSharkTarget = {}
local selectedUUIDsSharkTarget = {}
local dropdownControlSharkTarget = nil
local infoParagraphSharkTarget = nil

-- Target Mutasi (single select)
local mutationOptions = {}  -- label -> mutasi name
local selectedMutation = nil
local dropdownControlMutation = nil

-- Key penyimpanan
local SAVE_KEY_SHARK = "SelectedPetUUIDs_Shark"
local SAVE_KEY_SHARK_TARGET = "SelectedPetUUIDs_SharkTarget"
local SAVE_KEY_MUTATION = "SelectedMutation"

-- ============================================================
-- FUNGSI UPDATE INFO PET SHARK
-- ============================================================
local function updatePetInfoShark(pets)
    if not infoParagraphShark then return end
    local contentText
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
        end
        contentText = "Tim Auto Shark:\n" .. table.concat(lines, "\n")
    else
        contentText = "Belum ada pet dipilih (Tim Auto Shark)"
    end
    if infoParagraphShark.SetContent then
        infoParagraphShark:SetContent(contentText)
    else
        infoParagraphShark.Content = contentText
    end
end

-- ============================================================
-- FUNGSI UPDATE INFO TARGET SHARK
-- ============================================================
local function updatePetInfoSharkTarget(pets)
    if not infoParagraphSharkTarget then return end
    local contentText
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
        end
        contentText = "Target Shark:\n" .. table.concat(lines, "\n")
    else
        contentText = "Belum ada pet dipilih (Target Shark)"
    end
    if infoParagraphSharkTarget.SetContent then
        infoParagraphSharkTarget:SetContent(contentText)
    else
        infoParagraphSharkTarget.Content = contentText
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN SHARK (Favorite)
-- ============================================================
local function refreshPetDropdownShark()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end
    local pets = DataPetModule.findPets({ isFavorite = true })
    if #pets == 0 then
        Fluent:Notify({ Title = "Info", Description = "Tidak ada pet favorite ditemukan", Duration = 5 })
        if dropdownControlShark then dropdownControlShark:SetValues({}) end
        petOptionsShark = {}; selectedPetsShark = {}; selectedUUIDsShark = {}
        updatePetInfoShark({})
        return
    end
    local values = {}
    petOptionsShark = {}
    for _, pet in ipairs(pets) do
        local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
        table.insert(values, label)
        petOptionsShark[label] = pet
    end
    if dropdownControlShark then
        dropdownControlShark:SetValues(values)
        local savedUUIDs = _G[SAVE_KEY_SHARK]
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptionsShark) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end
        if #restoredLabels > 0 then
            dropdownControlShark:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptionsShark[label] then table.insert(selected, petOptionsShark[label]) end
            end
            selectedPetsShark = selected
            selectedUUIDsShark = {}
            for _, pet in ipairs(selected) do table.insert(selectedUUIDsShark, pet.uuid) end
            updatePetInfoShark(selected)
        else
            dropdownControlShark:SetValue({})
            selectedPetsShark = {}; selectedUUIDsShark = {}
            updatePetInfoShark({})
        end
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN SHARK TARGET (Non-Favorit)
-- ============================================================
local function refreshPetDropdownSharkTarget()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end
    local pets = DataPetModule.findPets({ isFavorite = false })
    if #pets == 0 then
        Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit ditemukan", Duration = 5 })
        if dropdownControlSharkTarget then dropdownControlSharkTarget:SetValues({}) end
        petOptionsSharkTarget = {}; selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
        updatePetInfoSharkTarget({})
        return
    end
    local values = {}
    petOptionsSharkTarget = {}
    for _, pet in ipairs(pets) do
        local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
        table.insert(values, label)
        petOptionsSharkTarget[label] = pet
    end
    if dropdownControlSharkTarget then
        dropdownControlSharkTarget:SetValues(values)
        local savedUUIDs = _G[SAVE_KEY_SHARK_TARGET]
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptionsSharkTarget) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end
        if #restoredLabels > 0 then
            dropdownControlSharkTarget:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptionsSharkTarget[label] then table.insert(selected, petOptionsSharkTarget[label]) end
            end
            selectedPetsSharkTarget = selected
            selectedUUIDsSharkTarget = {}
            for _, pet in ipairs(selected) do table.insert(selectedUUIDsSharkTarget, pet.uuid) end
            updatePetInfoSharkTarget(selected)
        else
            dropdownControlSharkTarget:SetValue({})
            selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
            updatePetInfoSharkTarget({})
        end
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN MUTASI (single select)
-- ============================================================
local function refreshMutationDropdown()
    if not DataPetModule then
        Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
        return
    end
    -- Kumpulkan semua mutasi unik dari semua pet
    local allPets = DataPetModule.getAllPets()
    local mutationSet = {}
    for _, pet in pairs(allPets) do
        local petData = pet.PetData or {}
        local rawMut = petData.MutationType or "Normal"
        local mutationName = DataPetModule.getAutoMutationName(rawMut)
        mutationSet[mutationName] = true
    end
    -- Tambahkan "Normal" jika belum ada
    mutationSet["Normal"] = true

    local values = {}
    mutationOptions = {}
    for mutName, _ in pairs(mutationSet) do
        table.insert(values, mutName)
        mutationOptions[mutName] = mutName
    end
    table.sort(values) -- urutkan alfabetis

    if dropdownControlMutation then
        dropdownControlMutation:SetValues(values)
        local saved = _G[SAVE_KEY_MUTATION]
        if saved and mutationOptions[saved] then
            dropdownControlMutation:SetValue(saved)
            selectedMutation = saved
        else
            -- default pilih yang pertama jika tidak ada
            if #values > 0 then
                dropdownControlMutation:SetValue(values[1])
                selectedMutation = values[1]
                _G[SAVE_KEY_MUTATION] = values[1]
            end
        end
    end
end

-- ============================================================
-- BUAT KOMPONEN AUTOSHARK
-- ============================================================
-- Section: Tim Auto Shark (Favorite)
local sectionShark = AutoSharkTab:AddSection("Pilih Tim Auto Shark (Favorit)")
dropdownControlShark = sectionShark:AddDropdown("PetDropdownShark", {
    Title = "Daftar Pet Favorite",
    Values = {},
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}; local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptionsShark[label] then
                    table.insert(selected, petOptionsShark[label])
                    table.insert(uuids, petOptionsShark[label].uuid)
                end
            end
            selectedPetsShark = selected; selectedUUIDsShark = uuids
            _G[SAVE_KEY_SHARK] = uuids
            updatePetInfoShark(selected)
        else
            selectedPetsShark = {}; selectedUUIDsShark = {}
            _G[SAVE_KEY_SHARK] = {}
            updatePetInfoShark({})
        end
    end
})
sectionShark:AddButton({ Title = "↻ Refresh Daftar Shark", Callback = function() refreshPetDropdownShark() end })
infoParagraphShark = sectionShark:AddParagraph({ Title = "Tim Auto Shark", Content = "Belum ada pet dipilih (Tim Auto Shark)" })

-- Section: Target Pet (Non-Favorit)
local sectionSharkTarget = AutoSharkTab:AddSection("Pilih Target Pet (Non-Favorit)")
dropdownControlSharkTarget = sectionSharkTarget:AddDropdown("PetDropdownSharkTarget", {
    Title = "Daftar Pet Non-Favorit",
    Values = {},
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}; local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptionsSharkTarget[label] then
                    table.insert(selected, petOptionsSharkTarget[label])
                    table.insert(uuids, petOptionsSharkTarget[label].uuid)
                end
            end
            selectedPetsSharkTarget = selected; selectedUUIDsSharkTarget = uuids
            _G[SAVE_KEY_SHARK_TARGET] = uuids
            updatePetInfoSharkTarget(selected)
        else
            selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
            _G[SAVE_KEY_SHARK_TARGET] = {}
            updatePetInfoSharkTarget({})
        end
    end
})
sectionSharkTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownSharkTarget() end })
infoParagraphSharkTarget = sectionSharkTarget:AddParagraph({ Title = "Target Shark", Content = "Belum ada pet dipilih (Target Shark)" })

-- Section: Target Mutasi (single select)
local sectionMutation = AutoSharkTab:AddSection("Pilih Target Mutasi")
dropdownControlMutation = sectionMutation:AddDropdown("MutationDropdown", {
    Title = "Daftar Mutasi",
    Values = {},
    Multi = false,
    Default = "",
    Callback = function(selected)
        if selected and mutationOptions[selected] then
            selectedMutation = selected
            _G[SAVE_KEY_MUTATION] = selected
            print("[AutoShark] Mutasi dipilih:", selected)
        else
            selectedMutation = nil
            _G[SAVE_KEY_MUTATION] = nil
        end
    end
})
sectionMutation:AddButton({ Title = "↻ Refresh Daftar Mutasi", Callback = function() refreshMutationDropdown() end })

-- ============================================================
-- MUAT DATA PERTAMA KALI
-- ============================================================
task.wait(1)
refreshPetDropdownLvl()
refreshPetDropdownTarget()
refreshPetDropdownPNP()
refreshPetDropdownShark()
refreshPetDropdownSharkTarget()
refreshMutationDropdown()

-- Restore state Leveling
if _G[TARGET_KEY] then
    targetLevel = _G[TARGET_KEY]
    targetInput:SetValue(tostring(targetLevel))
end
if _G[ENABLE_KEY] ~= nil then
    autoLevelEnabled = _G[ENABLE_KEY]
    autoToggle:SetValue(autoLevelEnabled)
end

-- Restore state PNP
if _G[PICKUP_DELAY_KEY] then
    pickupDelay = _G[PICKUP_DELAY_KEY]
    pickupInput:SetValue(tostring(pickupDelay))
end
if _G[PLACE_DELAY_KEY] then
    placeDelay = _G[PLACE_DELAY_KEY]
    placeInput:SetValue(tostring(placeDelay))
end
if _G[PNP_ENABLE_KEY] ~= nil then
    autoPNPEnabled = _G[PNP_ENABLE_KEY]
    autoPNPToggle:SetValue(autoPNPEnabled)
end

-- ============================================================
-- SETUP SAVEMANAGER & INTERFACEMANAGER
-- ============================================================
pcall(function()
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("LevelingScript")
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
    Description = "Script siap digunakan! (Tema Rose)",
    Duration = 3
})

print("[Pria Solo HUB] UI selesai dimuat (Leveling + PNP + AutoShark)")
