# luci-network-dn11(误)

## 依赖

opkg install lyaml

## 注意事项

文件名啥的自己都看一眼，可能有不一样的

防火墙部分自己调整，目前仅供新版（不用加接口，直接在防火墙加设备）的使用

旧版（先加接口，再加防火墙）参考如下

```lua
    -- Add firewall

    local uci = require("luci.model.uci").cursor()
    local new_interface = uci:add("network", "interface")
    uci:set("network", new_interface, "proto", "none")
    uci:set("network", new_interface, "ifname", nickname)
    uci:rename("network", new_interface, nickname)
    uci:commit("network")

    local network = uci:get("firewall", "vpn", "network")
    network = network .. " " .. nickname
    uci:set("firewall", "vpn", "network", network)
    uci:commit("firewall")
```
