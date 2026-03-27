local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

local tsmsmscomm = {}

function tsmsmscomm.init(app)
    tsmsmscomm.app = app
end

function tsmsmscomm.get_control_data(phone, message)
    local control_data = {
        trusted_phone = "",
        trusted_email = "",
        sms_command = "",
        shell_command = "",
    }

    uci:foreach("tsmsmscomm", "remote_control", function (section)
        if phone == section.trusted_phone then
            control_data.trusted_phone = section.trusted_phone
            control_data.trusted_email = section.trusted_email
        end
    end)

    uci:foreach("tsmsmscomm", "sms_command", function (section)
        if message == section.sms_command then
            control_data.sms_command = section.sms_command
            control_data.shell_command = section.shell_command
        end
    end)

    return control_data
end

function tsmsmscomm.run(control_data)
    if control_data.trusted_phone == nil or control_data.trusted_phone == "" then
        return {
            run = false,
            result = "Номер телефона отсутствует в списке конфига",
            tmp_file = "",
        }
    end

    local shell_cmd = control_data.shell_command
    if shell_cmd == nil or shell_cmd == "" then
        return {
            run = false,
            result = "Команда отсутствует в списке конфига",
            tmp_file = "",
        }
    end

    local tmp_size_cmd = "df -k /tmp | awk 'NR==2 {print $2}'"
    local tmp_size_cmd_result = sys.process.exec({ "/bin/sh", "-c", tmp_size_cmd }, true, true, false)
    local tmp_memory_half

    if tmp_size_cmd_result and tmp_size_cmd_result.code == 0 and tmp_size_cmd_result.stdout then
        local kb_value = tonumber(tmp_size_cmd_result.stdout:match("%d+"))
        if kb_value then
            local bytes = kb_value * 1024
            tmp_memory_half = math.floor(bytes / 2)
        else
            return {
                run = false,
                result = "Ошибка: отсутствует kb_value значение",
                tmp_file = "",
            }
        end
    else
        return {
            run = false,
            result = "Ошибка: " .. tmp_size_cmd_result.stderr,
            tmp_file = "",
        }
    end

    local formattedTime = os.date("%d-%m-%Y_%H_%M_%S")
    local tmp_file = '/tmp/tsmsmscomm_' .. formattedTime .. '.txt'
    local timeout_seconds = 10

    local cmd = string.format("%s | tail -c %d > %s 2>&1", shell_cmd, tmp_memory_half, tmp_file)
    local result = sys.process.exec({ "/usr/bin/timeout", tostring(timeout_seconds), "/bin/sh", "-c", cmd })

    if result and result.code == 124 then
        if result.code == 0 then
            return {
                run = true,
                result = "", -- Пустое значение для избежания нагрузки на ubus. Applogic читает результат из tmp файла.
                tmp_file = tmp_file,
            }
        elseif result.code == 124 then
            return {
                run = false,
                result = "Произошел таймаут",
                tmp_file = "",
            }
        end
    end

    return {
        run = false,
        result = "Ошибка: отсутствует result значение",
        tmp_file = "",
    }
end

function tsmsmscomm.notify(control_data, cmd_result)
    tsmsmscomm.app.conn:notify(
        tsmsmscomm.app.ubus_methods["tsmsmscomm"].__ubusobj, 'result', {
            trusted_phone = control_data.trusted_phone,
            trusted_email = control_data.trusted_email,
            sms_command = control_data.sms_command,
            shell_command = control_data.shell_command,

            run = cmd_result.run,
            result = cmd_result.result,
            tmp_file = cmd_result.tmp_file,
        }
    )
end

return tsmsmscomm
