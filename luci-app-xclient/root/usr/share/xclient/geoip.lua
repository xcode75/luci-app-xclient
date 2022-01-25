#!/usr/bin/lua

require 'nixio'
require 'luci.sys'
local luci = luci
local ucic = luci.model.uci.cursor()
local jsonc = require "luci.jsonc"
local name = 'xclient'
local arg1 = arg[1]
local reboot = 0
local geoip_update = 0
local geoip_api =  "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest"
local geodata = "/usr/bin/"


local log = function(...)
    if arg1 then
        local result = os.date("%Y-%m-%d %H:%M:%S: ") .. table.concat({...}, " ")
        if arg1 == "log" then
            local f, err = io.open("/var/run/geositelog", "a")
            if f and err == nil then
                f:write(result .. "\n")
                f:close()
            end
        elseif arg1 == "print" then
            print(result)
        end
    end
end



-- trim
local function trim(text)
    if not text or text == "" then return "" end
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

-- curl
local function curl(url, file)
	local cmd = "curl -skL -w %{http_code} --retry 5 --connect-timeout 30 '" .. url .. "'"
	if file then
		cmd = cmd .. " -o " .. file
	end
	local stdout = luci.sys.exec(cmd)

	if file then
		return tonumber(trim(stdout))
	else
		return trim(stdout)
	end
end



local function fetch_geoip()
	xpcall(function()
		local json_str = curl(geoip_api)
		local json = jsonc.parse(json_str)
		if json.tag_name and json.assets then
			for _, v in ipairs(json.assets) do
				if v.name and v.name == "geoip.dat.sha256sum" then
					local sret = curl(v.browser_download_url, "/tmp/geoip.dat.sha256sum")
					if sret == 200 then
						local f = io.open("/tmp/geoip.dat.sha256sum", "r")
						local content = f:read()
						f:close()
						f = io.open("/tmp/geoip.dat.sha256sum", "w")
						f:write(content:gsub("geoip.dat", "/tmp/geoip.dat"), "")
						f:close()

						if nixio.fs.access(geodata .. "geoip.dat") then
							luci.sys.call(string.format("cp -f %s %s", geodata .. "geoip.dat", "/tmp/geoip.dat"))
							if luci.sys.call('sha256sum -c /tmp/geoip.dat.sha256sum > /dev/null 2>&1') == 0 then
								log("geoip  version is the same, no need to update.")
								return 1
							end
						end
						for _2, v2 in ipairs(json.assets) do
							if v2.name and v2.name == "geoip.dat" then
								sret = curl(v2.browser_download_url, "/tmp/geoip.dat")
								if luci.sys.call('sha256sum -c /tmp/geoip.dat.sha256sum > /dev/null 2>&1') == 0 then
									luci.sys.call(string.format("mkdir -p %s && cp -f %s %s", geodata, "/tmp/geoip.dat", geodata .. "geoip.dat"))
									reboot = 1
									log("geoip Successfully Updated。")
									return 1
								else
									log("geoip Update failed, please try again later")
								end
								break
							end
						end
					end
					break
				end
			end
		end
	end,
	function(e)
	end)

	return 0
end


if arg[2] then
	if arg[2]:find("geoip") then
		geoip_update = 1
	end
else
	geoip_update = 1
end
if geoip_update == 0  then
	os.exit(0)
end

log("Starting To Update Geoip File...")


if tonumber(geoip_update) == 1 then
	log("geoip Starting Update...")
	local status = fetch_geoip()
	os.remove("/tmp/geoip.dat")
	os.remove("/tmp/geoip.dat.sha256sum")
end


if reboot == 1 then
	log("Restarting XClient")
	luci.sys.call("/etc/init.d/" .. name .. " reload > /dev/null 2>&1 &")
end
log("geoip file updated successfully")
