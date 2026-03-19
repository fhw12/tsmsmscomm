local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)
    io.write("\n")
    print("-----------------------")
    print("Tsmail debug stopped.")
    print("-----------------------")
    io.write("\n")
    os.exit(128 + signum)
end)

local ubus = require "ubus"
local uloop = require "uloop"
-- local uci = require "luci.model.uci".cursor()

local tsmsmscomm = require "tsmsmscomm"

local app = {}
app.conn = nil

function app.init()
    app.conn = ubus.connect()
    if not app.conn then
        error("Failed to connect to ubus from tsmsmscomm")
    else
        tsmsmscomm.init(app)

        print("make_ubus start")
        app.make_ubus()
        print("make_ubus ok")
    end
end

function app.make_ubus()
    local ubus_methods = {
        ["tsmsmscomm"] = {
            run = {
                function (req, msg)
                    local phone = msg["phone"]
                    local message = msg["message"]

                    if not (phone and message) then
                        app.conn:reply(req, {
                            status = "error",
                            result = "[phone] and [message] are required params.",
                        })
                    else
                        -- local trusted_phone = ""
                        -- local trusted_email = ""
                        -- local sms_command = ""
                        -- local shell_command = ""

                        -- uci:foreach("tsmsmscomm", "remote_control", function (section)
                        --     if phone == section.trusted_phone then
                        --        trusted_phone = section.trusted_phone
                        --        trusted_email = section.trusted_email
                        --     end
                        -- end)

                        -- uci:foreach("tsmsmscomm", "sms_command", function (section)
                        --     if message == section.sms_command then
                        --         sms_command = section.sms_command
                        --         shell_command = section.shell_command
                        --     end
                        -- end)

                        -- print(trusted_phone, trusted_email)
                        -- print(sms_command, shell_command)

                        local control_data = tsmsmscomm.get_control_data(phone, message)
                        local cmd_result = tsmsmscomm.run(control_data)

                        app.conn:reply(req, {
                            status = "ok",
                            -- phone = phone,
                            -- message = message,
                            run = cmd_result.run,
                            result = cmd_result.result,
                        })

                        print('test: code after reply') -- works

                        tsmsmscomm.notify(cmd_result)
                    end
                end, { phone = ubus.STRING, message = ubus.STRING }
            }
        }
    }

    app.conn:add(ubus_methods)
    app.ubus_methods = ubus_methods
end

local metatable = {
    __call = function (app_)
        uloop.init()
        app_.init()
        uloop.run()
        app_.conn:close()
        return app_
    end
}
setmetatable(app, metatable)
app()
