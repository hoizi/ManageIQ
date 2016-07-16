#
# Description: add_custom_attribute
#
# Author: Thomas Holzgruber <thomas@holzgruber.at>
# License: GPL v3
#
$evm.log(:info, "add_custom_attribute started")

@debug = true

case $evm.root['vmdb_object_type']
  when 'miq_provision'                  # called from a VM provision workflow
    # Get provisioning object
    prov = $evm.root["miq_provision"]

    ip_addr   = prov.get_option(:ip_addr)
    dns_rr_id = prov.get_option(:dns_rr_id)

    $evm.log("info", "AddCustomAttribute: Provision Options: #{prov.options.inspect}") if @debug
    
    vm = $evm.root['miq_provision'].destination
    vm.custom_set("PHPIPAM_IP", ip_addr)
    vm.custom_set("DB_DNS_RR_ID", dns_rr_id)
  when 'vm'                             # called from a button
    # Get the VM object
    vm    = $evm.root['vm']
    key   = $evm.root['dialog_key']
    value = $evm.root['dialog_value']

    # Set the custom attribute
    vm.custom_set(key, value)
end

exit MIQ_OK
