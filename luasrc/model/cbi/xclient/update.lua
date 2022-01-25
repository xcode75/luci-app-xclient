
m = Map("xclient")

s = m:section(TypedSection, "xclient")
s.anonymous = true
s.addremove=false

s:append(Template("xclient/xray_update"))

s:append(Template("xclient/update_geoip"))

s:append(Template("xclient/update_geosite"))

return m
