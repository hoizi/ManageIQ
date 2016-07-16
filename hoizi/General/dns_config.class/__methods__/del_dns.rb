#
# Description: add_dns - Delete A record of VM in ISPConfig
#
# Author: Thomas Holzgruber <thomas@holzgruber.at>
# License: GPL v3
#
# ISPCONFIG - Delete A Record of VM
# -----------------------------------------
# Usage - Method belongs to ISPCONFIG (V3).
# -----------------------------------------
#
$evm.log("info", "********* ISPCONFIG - Delete DNS STARTED *********")

@debug = true

require 'savon'

SOAP_USER     = $evm.object['soap_user']
SOAP_PASSWORD = $evm.object['soap_password']
ISP_HOST      = $evm.object['isp_host']
ISP_USER      = $evm.object['isp_user']

$evm.log("info", "ISPCONFIG: Config: #{SOAP_USER}, #{SOAP_PASSWORD}, #{ISP_HOST}, #{ISP_USER}") if @debug

vm = $evm.root['vm']
$evm.log("info", "ISPCONFIG: Custom Options: #{vm.custom_keys}") if @debug

# get db dns_rr_id from VM
dns_rr_id = vm.custom_get("DB_DNS_RR_ID")

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

# delete a record of VM
response = soap_client.call(:dns_a_delete, message: {session_id: session_id, dns_rr_id: dns_rr_id})
return_code = response.body[:dns_a_delete_response][:return]
puts return_code

# close session
response = soap_client.call(:logout, message: {session: session_id})

$evm.log("info", "********* ISPCONFIG - Delete DNS COMPLETED *********")
exit MIQ_OK
