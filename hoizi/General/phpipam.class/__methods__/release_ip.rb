#
# Description: release_ip - Release IP from PHPIPAM
#
# Author: Thomas Holzgruber <thomas@holzgruber.at>
# License: GPL v3
#
# PHPIPAM - Release IP Address
# -----------------------------------------
# Usage - Method belongs to PHPIPAM (V1.2).
# -----------------------------------------
#
$evm.log("info", "********* PHPIPAM - ReleaseIP STARTED *********")

@debug = true

require 'httpclient'
require 'json'
require 'base64'
require 'mcrypt'

ipam_server = $evm.object['ipam_server']
$api_key = $evm.object['api_key']
$api_token = $evm.object['api_token']
$evm.log("info", "PHPIPAM: Config: #{ipam_server}, #{$api_key}, #{$api_token}") if @debug

prov = $evm.root['vm'].miq_provision

ip_addr = prov.get_option(:ip_addr)

http = HTTPClient.new
http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
uri = "https://#{ipam_server}/api/"

headers = { "Content-Type" => "application/json", "Accept" => "application/json,version=2", "token" => "#{$api_token}" }

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

# ugly hack otherwise http.delete doesn't work!
class HTTPClient
  def delete(uri, *args, &block)
    request(:delete, uri, argument_to_hash(args, :query, :body, :header), &block)
  end
end

# search address
request = {
  :controller => 'addresses',
  :id => 'search',
  :id2 => "#{ip_addr}"
}
data = enc_data(request)
$evm.log(:info, "PHPIPAM SEARCH DATA: <#{data.inspect}>") if @debug
result = JSON.parse(http.get(uri, data, headers).content)
$evm.log(:info, "PHPIPAM SEARCH RESULT : <#{result.inspect}>") if @debug
result2 = result['data'].first
id = result2['id']

# delete address
request = {
  :controller => 'addresses',
  :id => "#{id}"
}
data = enc_data(request)
$evm.log(:info, "PHPIPAM DELETE DATA: <#{data.inspect}>") if @debug
result = JSON.parse(http.delete(uri, data, headers).content)
$evm.log(:info, "PHPIPAM DELETE RESULT: <#{result.inspect}>") if @debug
$evm.log(:info, "PHPIPAM DELETE RESULT: <#{result}>")
code = result['code']
$evm.log(:info, "PHPIPAM DELETE CODE: <#{code}>") if @debug

$evm.log("info", "********* PHPIPAM - ReleaseIP COMPLETED *********")
exit MIQ_OK
