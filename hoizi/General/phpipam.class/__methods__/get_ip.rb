#
# Description: get_ip - Get IP and create a host record in PHPIPAM
#
# Author: Thomas Holzgruber <thomas@holzgruber.at>
# License: GPL v3
#
# PHPIPAM - Get IP Address
# -----------------------------------------
# Usage - Method belongs to PHPIPAM (V1.2).
# -----------------------------------------
#
$evm.log("info", "********* PHPIPAM - GetIP STARTED *********")

@debug = true

require 'httpclient'
require 'json'
require 'base64'
require 'mcrypt'

ipam_server = $evm.object['ipam_server']
$api_key = $evm.object['api_key']
$api_token = $evm.object['api_token']
$evm.log("info", "PHPIPAM: Config: #{ipam_server}, #{$api_key}, #{$api_token}") if @debug

prov = $evm.root['miq_provision']

hostname    = prov.get_option(:vm_name)
dns_domain  = "byting.com"
subnet_name = prov.get_option(:vlan)
fqdn        = "#{hostname}.#{dns_domain}"
$evm.log("info","PHPIPAM: GetIP --> Hostname = #{fqdn}")

# subnet information, if you have more or you want to select it from a dialog, feel free to change it
subnet      = "192.168.0.0"
subnet_cidr = "24"
subnet_mask = "255.255.255.0"
broadcast   = "192.168.0.255"
gateway     = "192.168.0.1"

## uncomment if you want to set the subnet variables from location tag
#vm = prov.vm_template
#
## get tags from VM
#tags = vm.tags 
#$evm.log("info", "PHPIPAM: Template Tags - #{vm.tags}") if @debug

## get location tag
#tags.each  do  |t|
# s = t.split("/")
#  if s[0] == 'location'
#      @prov_tag = s[1]
#  end
#end
#$evm.log("info", "PHPIPAM: Template is tagged with - #{@prov_tag}") if @debug
#location = @prov_tag
#
## set subnet on location
#case location
#when 'location_1'
#  subnet      = "192.168.0.0"
#  subnet_cidr = "24"
#  subnet_mask = "255.255.255.0"
#  broadcast   = "192.168.0.255"
#  gateway     = "192.168.0.1"
#when 'location_2'
#  subnet      = "192.168.1.0"
#  subnet_cidr = "24"
#  subnet_mask = "255.255.255.0"
#  broadcast   = "192.168.1.255"
#  gateway     = "192.168.1.1"
#end

http = HTTPClient.new
http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
uri = "https://#{ipam_server}/api/"
headers = { "Content-Type" => "application/json", "Accept" => "application/json,version=2", "HTTP_PHPIPAM_TOKEN" => "#{$api_token}" }

# enc_data function
def enc_data(request)
  cipher = Mcrypt.new(:rijndael_256, :ecb, $api_token, nil, :zeros)
  enc_request = cipher.encrypt(request.to_json)
  data = {
    :app_id => $api_key,
    :enc_request => Base64.encode64(enc_request)
  }
  return data
end

# Get subnet
request = {
  :controller => 'subnets',
  :id => 'cidr',
  :id2 => "#{subnet}",
  :id3 => "#{subnet_cidr}",
}
data = enc_data(request)
result = JSON.parse(http.get(uri, data, headers).content)
$evm.log("info", "PHPIPAM: #{result.inspect}") if @debug
result = result['data'].first
id = result['id']
$evm.log("info", "PHPIPAM: Subnet ID: #{id}")

# Get next available IP in subnet
request = {
  :controller => 'subnets',
  :id => "#{id}",
  :id2 => 'first_free',
}
data = enc_data(request)
result = JSON.parse(http.get(uri, data, headers).content)
$evm.log("info", "PHPIPAM: #{result.inspect}") if @debug
ip_addr = result['data']
$evm.log("info", "PHPIPAM: IP Address: #{ip_addr}")

# create Address entry
request = {
  :controller => 'addresses',
  :subnetId => "#{id}",
  :ip => "#{ip_addr}",
  :hostname => "#{fqdn}",
  :owner => "#{$api_key}",
}
request = request.to_json
uri = "https://#{ipam_server}/api/?app_id=#{$api_key}"
response = http.post(uri, request, headers)
result = JSON.parse(response.body)
$evm.log("info", "PHPIPAM: #{result}") if @debug
code = result['code']
$evm.log("info", "PHPIPAM: IP Address created with code: #{code}")

# set options for custom attributes, dns record and cloud-init
prov.set_option(:ip_addr, ip_addr)
prov.set_option(:subnet_mask, subnet_mask)
prov.set_option(:gateway, gateway)
prov.set_option(:dns_domain, dns_domain)
prov.set_option(:host_name, fqdn)
prov.set_option(:linux_host_name, fqdn)
prov.set_option(:vm_target_hostname, fqdn)
prov.set_option(:vm_target_name, hostname)
prov.set_vlan(subnet_name)

$evm.log("info", "PHPIPAM: Provision Options: #{prov.options.inspect}") if @debug

$evm.log("info", "********* PHPIPAM - GetIP COMPLETED *********")
exit MIQ_OK
