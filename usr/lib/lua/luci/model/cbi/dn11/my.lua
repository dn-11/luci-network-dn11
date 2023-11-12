m = Map("dn11", translate("本 AS 信息"))
d = m:section(NamedSection, "dn11", "dn11", "")
d.addremove = false
d.anonymous = true

as_number = d:option(Value, "as_number", "ASN", "AS Number")
as_number.optional = false
as_number.rmempty = false
as_number.datatype = "and(uinteger,min(4211110000))"
as_number.maxlength = 10

tunnel_ip = d:option(Value, "tunnel_ip", "隧道 IP", "隧道IP，不用加 /32")
tunnel_ip.optional = false
tunnel_ip.rmempty = false
tunnel_ip.datatype = "ip4addr"
tunnel_ip.placeholder = "例：172.16.0.254"

entry_domain = d:option(DynamicList, "entry_domain", "接入点", "域名，用于生成交换信息")
entry_domain.optional = false
entry_domain.rmempty = false
entry_domain.datatype = "hostname"

return m
