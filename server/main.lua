local ESX = exports['es_extended']:getSharedObject()

MySQL.ready(function()
    MySQL.query("CREATE TABLE IF NOT EXISTS votes (identifier VARCHAR(50) UNIQUE, candidate VARCHAR(50))")
end)

-- Kiểm tra người chơi có quyền admin không
function isAdmin(xPlayer)
    local playerGroup = xPlayer.getGroup()
    return playerGroup == "admin" or playerGroup == "superadmin"
end

-- Kiểm tra người chơi đã bỏ phiếu chưa
ESX.RegisterServerCallback("vote:canVote", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false)
        return
    end

    local identifier = xPlayer.identifier
    if not identifier then
        cb(false)
        return
    end

    MySQL.scalar("SELECT candidate FROM votes WHERE identifier = ?", {identifier}, function(result)
        cb(result == nil)
    end)
end)

-- Ghi nhận phiếu bầu của người chơi
RegisterNetEvent("vote:castVote")
AddEventHandler("vote:castVote", function(candidate)
    local _source = source
    if not _source then
        return
    end

    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then
        return
    end

    local identifier = xPlayer.identifier
    if not identifier then
        return
    end

    MySQL.scalar("SELECT candidate FROM votes WHERE identifier = ?", {identifier}, function(result)
        if not result then
            MySQL.insert("INSERT INTO votes (identifier, candidate) VALUES (?, ?)", {identifier, candidate})
            TriggerClientEvent("esx:showNotification", _source, "~y~PHIẾU BẦU ĐƯỢC GỬI CHO " .. candidate .. "!")
        else
            TriggerClientEvent("esx:showNotification", _source, "~y~BẠN ĐÃ BÌNH CHỌN!")
        end
    end)
end)

-- Hiển thị kết quả bình chọn trong game & gửi lên Discord
RegisterNetEvent("vote:showResults")
AddEventHandler("vote:showResults", function(isFinal, targetPlayer)
    local target = targetPlayer or -1

    MySQL.query("SELECT candidate, COUNT(*) as votes FROM votes GROUP BY candidate ORDER BY votes DESC", {}, function(results)
        local message = "**📊 Tạm Kiểm Đếm 📊**\n\n"
        local highestVotes = 0
        local winner = nil
        local isTie = false

        if #results == 0 then
            message = message .. "Chưa có phiếu bầu nào được bình chọn!"
        else
            for _, result in ipairs(results) do
                message = message .. string.format("✅ **%s**: %d phiếu\n", result.candidate, result.votes)

                if result.votes > highestVotes then
                    highestVotes = result.votes
                    winner = result.candidate
                    isTie = false
                elseif result.votes == highestVotes then
                    isTie = true
                end
            end
        end

        -- Nếu được gọi từ điểm cố định, chỉ gửi kết quả cho người chơi đó
        if not isFinal then
            TriggerClientEvent("vote:displayResults", target, message)
        end

        -- Nếu là kết quả cuối cùng hoặc từ showvote, gửi lên Discord
        local webhookTitle = isFinal and "🏆 Bỏ phiếu đã kết thúc!" or "📊 Kết quả bỏ phiếu hiện tại"
        local webhookColor = isFinal and 16776960 or 3447003 -- Vàng nếu là kết quả cuối cùng, Xanh nếu chỉ là cập nhật

        local discordMessage = {
            username = "HỆ THỐNG BÌNH CHỌN",
            embeds = {{
                title = webhookTitle,
                description = message,
                color = webhookColor,
                footer = { text = isFinal and "Đây là kết quả cuối cùng." or "Đây là bản cập nhật kết quả tạm thời." }
            }}
        }

        if isFinal and not isTie and winner then
            for _, candidate in ipairs(Config.Candidates) do
                if candidate.name == winner then
                    discordMessage.embeds[1].image = { url = candidate.image }
                    break
                end
            end
        end

        local jsonData = json.encode(discordMessage)
        print("^3[DEBUG] JSON sent to Discord: " .. jsonData) -- Kiểm tra dữ liệu trước khi gửi

        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers)
            if err ~= 200 then
                print("^1[ERROR] Failed to send results to Discord! Error code: " .. tostring(err))
            else
                print("^2[INFO] Voting results successfully sent to Discord!")
            end
        end, 'POST', json.encode(discordMessage), { ['Content-Type'] = 'application/json' })

        -- Nếu là kết quả cuối cùng, hiển thị cho tất cả người chơi
        if isFinal then
            print("^3[DEBUG] Sending voting results to clients: " .. message)
            TriggerClientEvent("vote:displayResults", -1, message)
        end
    end)
end)

-- Lệnh admin: Hiển thị kết quả và gửi lên Discord
RegisterCommand("showvote", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then
        TriggerClientEvent("esx:showNotification", source, "~y~BẠN KHÔNG CÓ QUYỀN!")
        return
    end
    TriggerEvent("vote:showResults", false) -- Gửi lên Discord luôn
end, false)

-- Lệnh admin: Kết thúc cuộc bình chọn và gửi kết quả cuối cùng
RegisterCommand("endvote", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then
        TriggerClientEvent("esx:showNotification", source, "~y~BẠN KHÔNG CÓ QUYỀN!")
        return
    end
    TriggerEvent("vote:showResults", true)
end, false)

-- Reset bình chọn
RegisterNetEvent("vote:resetVoting")
AddEventHandler("vote:resetVoting", function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then
        TriggerClientEvent("esx:showNotification", source, "~y~BẠN KHÔNG CÓ QUYỀN!")
        return
    end

    MySQL.query("DELETE FROM votes", {}, function(rowsChanged)
        TriggerClientEvent("esx:showNotification", -1, "~y~BÂY GIỜ BẠN CÓ THỂ BỎ PHIẾU LẠI.")
    end)
end)

-- Lệnh admin: Reset bình chọn
RegisterCommand("resetvote", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then
        TriggerClientEvent("esx:showNotification", source, "~y~BẠN KHÔNG CÓ QUYỀN!")
        return
    end
    TriggerEvent("vote:resetVoting")
end, false)

-- Xem kết quả tại điểm cố định
RegisterNetEvent("vote:checkResultsAtLocation")
AddEventHandler("vote:checkResultsAtLocation", function()
    local _source = source
    TriggerEvent("vote:showResults", false, _source)
end)
