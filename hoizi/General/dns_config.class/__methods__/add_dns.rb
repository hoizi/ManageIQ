#
# Description: add_dns - Add A record with IP and VM name in ISPConfig
#
# Author: Thomas Holzgruber <thomas@holzgruber.at>
# License: GPL v3
#
# ISPCONFIG - Add A Record of VM
# -----------------------------------------
# Usage - Method belongs to ISPCONFIG (V3).
# -----------------------------------------
#
$evm.log("info", "********* ISPCONFIG - Add DNS STARTED *********")

@debug = true

require 'savon'

SOAP_USER     = $evm.object['soap_user']
SOAP_PASSWORD = $evm.object['soap_password']
ISP_HOST      = $evm.object['isp_host']
ISP_USER      = $evm.object['isp_user']

$evm.log("info", "ISPCONFIG: Config: #{SOAP_USER}, #{SOAP_PASSWORD}, #{ISP_HOST}, #{ISP_USER}") if @debug

prov = $evm.root['miq_provision']

NAME   = prov.get_option(:vm_name)
IPADDR = prov.get_option(:ip_addr)
DOMAIN = prov.get_option(:dns_domain)

# fix variables
CURRENT_TIMESTAMP = Time.now
CURRENT_TIMESTAMP = CURRENT_TIMESTAMP.strftime("%Y-%m-%d %H:%M:%S")
# ID of primary name server - secondary is a copy of the primary!!!
SERVERID = "13"

soap_client = Savon::Client.new do
  ssl_verify_mode :none
  endpoint "https://#{ISP_HOST}/remote/index.php"
  namespace "https://#{ISP_HOST}/remote/"
  namespace_identifier :ns1
  strip_namespaces "true"
  convert_request_keys_to :none
  log "true"
  log_level :debug
  pretty_print_xml "true"
  env_namespace 'SOAP-ENV'
  namespaces 'xmlns:ns2' => 'http://xml.apache.org/xml-soap'
end

# login and store session_id
response = soap_client.call(:login, message: {username: SOAP_USER, password: SOAP_PASSWORD})
session_id = response.body[:login_response][:return]

# get client_id
response = soap_client.call(:client_get_by_username, message: {session_id: session_id, username: ISP_USER})
return_id = response.body[:client_get_by_username_response][:return]
items = Hash.new
return_id[:item].each_with_index do |item, i|
  items[return_id[:item][i][:key]] = return_id[:item][i][:value]
end
client_id = items["client_id"]

# get zone_id
response = soap_client.call(:dns_zone_get_by_user, message: {session_id: session_id, client_id: client_id, server_id: SERVERID})
return_id = response.body[:dns_zone_get_by_user_response][:return]
items = []
return_id[:item].each do |item|
  item3 = Hash.new
  item[:item].each_with_index do |item2, i|
    item3[item[:item][i][:key]] = item[:item][i][:value]
  end
  items.push(item3)
end
get_index = items.index {|h| h['origin'] == "#{DOMAIN}." }
zone_id = items[get_index]['id']

# add a dns record
input = { "item" => [
          { "key" => "server_id", "value" => SERVERID },
          { "key" => "zone", "value" => zone_id },
          { "key" => "name", "value" => NAME },
          { "key" => "type", "value" => "a" },
          { "key" => "data", "value" => IPADDR },
          { "key" => "aux", "value" => "0" },
          { "key" => "ttl", "value" => "7200" },
          { "key" => "active", "value" => "y" },
          { "key" => "stamp", "value" => CURRENT_TIMESTAMP },
          { "key" => "serial", "value" => "1" }
], '@xsi:type' => "ns2:Map"}
response = soap_client.call(:dns_a_add, message: {session_id: session_id, client_id: client_id, params: input})
dns_rr_id = response.body[:dns_a_add_response][:return]
dns_rr_id = dns_rr_id.to_i

# close session
response = soap_client.call(:logout, message: {session: session_id})

prov.set_option(:dns_rr_id, dns_rr_id)
$evm.log("info", "ISPCONFIG: Provision Options: #{prov.options.inspect}") if @debug

$evm.log("info", "********* ISPCONFIG - Add DNS COMPLETED *********")
exit MIQ_OK
