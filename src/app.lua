local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)
    io.write("\n")
    print("-----------------------")
    print("Tsmsmscomm debug stopped.")
    print("-----------------------")
    io.write("\n")
    os.exit(128 + signum)
end)

local ubus = require "ubus"
local uloop = require "uloop"

local tsmsmscomm = require "tsmsmscomm.tsmsmscomm"

local if_debug = require("tsmsmscomm.util").if_debug

local app = {}
app.conn = nil

function app.init()
    app.conn = ubus.connect()
    if not app.conn then
        error("Failed to connect to ubus from tsmsmscomm")
    else
        tsmsmscomm.init(app)
        if_debug("make ubus")
        app.make_ubus()
        if_debug("make ubus inited")
    end
end

function app.make_ubus()
    local ubus_methods = {
        ["tsmsmscomm"] = {
            run = {
                function (req, msg)
                    local phone = msg["phone"]
                    local message = msg["message"]

                    if_debug("Got ubus 'run' method call")
                    if not (phone and message) then
                        if_debug("[phone] and [message] are required params")
                        app.conn:reply(req, {
                            status = "error",
                            result = "[phone] and [message] are required params.",
                        })
                    else
                        app.conn:reply(req, {
                            status = "started",
                        })

                        local control_data = tsmsmscomm.get_control_data(phone, message)
                        local cmd_result = tsmsmscomm.run(control_data)

                        tsmsmscomm.notify(control_data, cmd_result)
                        if_debug(
                            "'Run' method result ( run = \"" .. tostring(cmd_result.run) ..
                            "\", result = \"" .. tostring(cmd_result.result) ..
                            "\", tmp_file = \"" .. tostring(cmd_result.tmp_file) .. "\" )"
                        )
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
