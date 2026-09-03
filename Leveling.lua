-- ============================================================
-- Leveling.lua - Modul Tab Leveling (dengan mutual exclusion)
-- ============================================================

local Leveling = {}

function Leveling.Setup(Window, DataPetModule, Fluent)
    local LevelingTab = Window:AddTab({ Title = "Leveling" })

    -- Variabel lokal
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

    -- Update info favorite
    local function updatePetInfoLvl(pets)
        if not infoParagraphLvl then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
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

    -- Update info target
    local function updatePetInfoTarget(pets)
        if not infoParagraphTarget then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
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

    -- Refresh favorite
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

    -- Refresh target
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

    -- Section favorite
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

    -- Section target
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

    -- Pengaturan dengan mutual exclusion
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
            if value then
                -- Matikan AutoShark jika menyala
                if _G.ACTIVE_MODULE == "AutoShark" and _G.AUTO_SHARK_TOGGLE then
                    _G.AUTO_SHARK_TOGGLE:SetValue(false)
                end
                _G.ACTIVE_MODULE = "Leveling"
                _G[ENABLE_KEY] = true
                Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling diaktifkan!", Duration = 3 })
            else
                _G[ENABLE_KEY] = false
                if _G.ACTIVE_MODULE == "Leveling" then
                    _G.ACTIVE_MODULE = nil
                end
                Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling dinonaktifkan", Duration = 3 })
            end
        end
    })
    -- Simpan referensi toggle
    _G.LEVELING_TOGGLE = autoToggle

    -- Load awal
    task.wait(0.5)
    refreshPetDropdownLvl()
    refreshPetDropdownTarget()
    if _G[TARGET_KEY] then
        targetLevel = _G[TARGET_KEY]
        targetInput:SetValue(tostring(targetLevel))
    end
    if _G[ENABLE_KEY] ~= nil then
        autoLevelEnabled = _G[ENABLE_KEY]
        autoToggle:SetValue(autoLevelEnabled)
    end

    print("[Leveling.lua] Tab Leveling siap.")
end

return Leveling
