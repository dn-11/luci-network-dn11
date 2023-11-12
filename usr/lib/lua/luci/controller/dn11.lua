module("luci.controller.dn11", package.seeall)

function index()
    entry({"api", "bsp"}, call("handle_bsp"))
    entry({"api", "bsos"}, call("handle_bsos"))
    entry({"api", "wp"}, call("handle_wp"))
    entry({"api", "genKey"}, call("handle_genkey"))

    if not nixio.fs.access("/etc/config/dn11") then
        return
    end
    local page = entry({"admin", "network", "dn11"}, alias("admin", "network", "dn11", "peer"), _("DN11"), 99)
    entry({"admin", "network", "dn11", "peer"}, call("prepare_content"), _("Peer"), 1).leaf = true
    entry({"admin", "network", "dn11", "config"}, cbi("dn11/my"), _("Config"), 2).leaf = true
    entry({"admin", "network", "dn11", "addPeer"}, call("add_peer"))
end

function handle_bsp()
    local command_output = luci.util.exec("birdc s p")
    luci.http.prepare_content("text/plain")
    luci.http.write(command_output)
end

function handle_bsos()
    local command_output = luci.util.exec("birdc s o s")
    luci.http.prepare_content("text/plain")
    luci.http.write(command_output)
end

function handle_wp()
    local command_output = luci.util.exec("wg show | awk '/interface/ {interface=$2} /listening port/ {print $3, interface}' | sort -nr")
    luci.http.prepare_content("text/plain")
    luci.http.write(command_output)
end

function handle_genkey()
    local private_key = luci.util.exec("wg genkey")
    private_key = private_key:gsub("%s+", "")

    local public_key = luci.util.exec("echo '" .. private_key .. "' | wg pubkey")
    public_key = public_key:gsub("%s+", "")

    luci.http.prepare_content("text/plain")
    luci.http.write(private_key .. "\n" .. public_key)
end

function prepare_content()
    local uci = require("luci.model.uci").cursor()
    local config = uci:get_all("dn11", "dn11")

    local as_number = config.as_number
    local entry_domain = config.entry_domain or {}
    local tunnel_ip = config.tunnel_ip

    luci.template.render("dn11/peer", {
        as_number = as_number,
        entry_domain = entry_domain,
        tunnel_ip = tunnel_ip
    })
end

function add_peer()
    local request_body = luci.http.content()
    local data = luci.jsonc.parse(request_body)

    -- Save wg conf

    local nickname = data.nickname
    if nixio.fs.access("/etc/wireguard/" .. nickname .. ".conf") then
        luci.http.prepare_content("text/plain")
        luci.http.write("Peer already exists")
        return
    end

    local wg_conf = data.wgConfig
    local wg_conf_file = io.open("/etc/wireguard/" .. nickname .. ".conf", "w")
    wg_conf_file:write(wg_conf)
    wg_conf_file:close()

    -- Add firewall

    local uci = require("luci.model.uci").cursor()
    local zones = uci:get_all("firewall")
    local vpn_zone
    for name, zone in pairs(zones) do
        if zone.name == 'vpn' then
            vpn_zone = name
            break
        end
    end
    if vpn_zone then
        local device_list = uci:get("firewall", vpn_zone, "device") or {}
        table.insert(device_list, nickname)
        uci:set_list("firewall", vpn_zone, "device", device_list)
        uci:commit("firewall")
    end

    -- Up wg interface

    luci.util.exec("wg-quick-op bounce " .. nickname)

    -- Append to bird conf

    local bird_conf = data.bgpConfig
    local bird_conf_file  = io.open("/etc/bird/ebgp.conf", "a")
    bird_conf_file:write(bird_conf)
    bird_conf_file:close()

    -- Reconfigure bird

    luci.util.exec("birdc configure")

    -- Add to dn11 config

    local lyaml = require('lyaml')
    local file = io.open("/etc/wg-quick-op.yaml", "r")
    local contents = file:read("*a")
    file:close()
    local data = lyaml.load(contents)
    local enabled = data.enabled
    local ddns = data.ddns
    table.insert(data.enabled, nickname)
    table.insert(data.ddns.iface, nickname)
    local updated_contents = lyaml.dump({data})
    local file = io.open("/etc/wg-quick-op.yaml", "w")
    file:write(updated_contents)
    file:close()
    luci.util.exec("service wg-quick-op restart")

    luci.http.prepare_content("text/plain")
    luci.http.write("OK")
end
