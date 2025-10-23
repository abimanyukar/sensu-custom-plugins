#!/usr/bin/env ruby
require 'json'
require 'ms_rest_azure'
require 'erb'
require 'sensu-plugin/check/cli'
require 'sensu-plugins-azurerm'
require 'time'
require 'net/http'

class CheckAzurermMAlbBackendHealth < Sensu::Plugin::Check::CLI
  include SensuPluginsAzureRM
  option :resource_group,
         description: 'ARM Resource Group. Either set ENV[\'ARM_RESOURCE_GROUP\'] or provide it as an option',
         short: '-g ID',
         long: '--resource-group ID',
         default: ENV['ARM_RESOURCE_GROUP']
  option :gateway_name,
         description: 'ARM Application Gateway Name. Either set ENV[\'ARM_GATEWAY_NAME\'] or provide it as an option',
         short: '-n NAME',
         long: '--gateway-name NAME',
         default: ENV['ARM_GATEWAY_NAME']
    option :backend_host,
         description: 'Backend host to check',
         short: '-b HOST',
         long: '--backend-host HOST',
         default: ENV['ARM_BACKEND_HOST']
  def run
    cmd = "az network application-gateway show-backend-health --resource-group #{config[:resource_group]} --name #{config[:gateway_name]} --output json"
    puts "Executing command: #{cmd}"
    begin
      output = `#{cmd}`
      data = JSON.parse(output)

      unhealthy = []
      data['backendAddressPools'].each do |pool|
        pool['backendHttpSettingsCollection'].each do |setting|
          setting['servers'].each do |server|
            if server['health'] != 'Healthy'
              unhealthy << "#{server['address']} (#{server['health']})"
            end
          end
        end
      end

      if unhealthy.empty?
        puts "OK: All backend servers are healthy."
        exit 0
      else
        #puts "CRITICAL: Unhealthy servers detected: #{unhealthy.join(', ')}"
        if unhealthy.include?(config[:backend_host])
          puts "ALERT: Specific unhealthy server detected: #{config[:backend_host]}"
          exit 2
        else
          puts "OK: Target backend server is healthy."
          exit 0
        end
      end
    rescue => e
      puts "UNKNOWN: Error checking backend health - #{e.message}"
      exit 3
    end
  end
end