#!/usr/bin/env ruby

require "harvested"
require "json"

config_file = "./harvest_cfg.json"


unless File.exists?(config_file)
  puts "Config file (#{config_file}) doens't exist."
  exit
end

config = JSON.parse(File.read(config_file))
puts config

harvest = Harvest.hardy_client(subdomain: config['subdomain'], username: config['username'], password: config['password'])

harvest.time.trackable_projects.map { |p| puts sprintf "%s - %-8s ||> %-80s", p[:client], p[:id], p[:name] }