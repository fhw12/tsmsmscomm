local uci = require "luci.model.uci".cursor()

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
        return ({
            run = false,
            result = "Номер телефона отсутствует в списке конфига",
        })
    end

    local shell_cmd = control_data.shell_command
    if shell_cmd == nil or shell_cmd == "" then
        return ({
            run = false,
            result = "Команда отсутствует в списке конфига",
        })
    end

    local handle = io.popen("df -k /tmp | awk 'NR==2 {print $2}'")
    local tmp_memory_half
    if handle ~= nil then
        local kb_value = tonumber(handle:read("*a"))
        local bytes = kb_value * 1024
        tmp_memory_half = math.floor(bytes / 2)
        handle:close()
    end


    local tmp_file = '/tmp/sms_command_output.txt'
    local timeout_seconds = 10

    shell_cmd = string.format("%s | tail -c %d", shell_cmd, tmp_memory_half)
    local bash = string.format("timeout %d sh -c '%s' > %s 2>&1", timeout_seconds, shell_cmd, tmp_file)
    local status = os.execute(bash)
    local exit_code = math.floor(status / 256)

    if exit_code == 124 then
        return ({
            run = false,
            result = "Произошел таймаут",
        })
    end

    local file = io.open(tmp_file, "r")
    if file ~= nil then
        local result = file:read("*a")
        file:close()
        return ({
            run = true,
            result = result,
        })
    end

    return ({
        run = false,
        result = "Ошибка открытия временного файла для чтения результата",
    })
end

function tsmsmscomm.notify(cmd_result)
    tsmsmscomm.app.conn:notify(
        tsmsmscomm.app.ubus_methods["tsmsmscomm"].__ubusobj, 'result', {
            run = cmd_result.run,
            result = cmd_result.result,
        }
    )
end

return tsmsmscomm
