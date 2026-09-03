-- ============================================================
-- PNP.lua - Modul Tab PNP
-- ============================================================

local PNP = {}

function PNP.Setup(Window, DataPetModule, Fluent)
    local PNPTab = Window:AddTab({ Title = "PNP" })

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

    -- Update info
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

    -- Refresh dropdown
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

    -- UI
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

    -- Pengaturan
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

    -- Load awal
    task.wait(0.5)
    refreshPetDropdownPNP()
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

    print("[PNP.lua] Tab PNP siap.")
end

return PNP
