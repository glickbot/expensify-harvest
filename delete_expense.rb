#!/usr/bin/env ruby

require "harvested"
require 'net/https'
require 'open-uri'
require "json"

config_file = "./harvest_cfg.json"
transactions_file = "./transactions.db"

transactions = Hash.new
if File.exists?(transactions_file)
  transactions = Marshal.load(File.binread(transactions_file))
  puts "Loaded previous transactions"
end

if ARGV.empty?
  puts "Please enter a transaction ID"
  exit
elsif !transactions.has_key?(ARGV[0])
  puts "No record of #{$ARGV[0]} in transactions db"
  exit
elsif !File.exists?(config_file)
  puts "Config file (#{config_file}) doens't exist."
  exit
end

id = ARGV[0]

config = JSON.parse(File.read(config_file))

harvest = Harvest.hardy_client(subdomain: config['subdomain'], username: config['username'], password: config['password'])

puts "Retrieving expense #{id}"

begin
  expense = harvest.expenses.find(transactions[id][:h_id])
  p "Deleting expense #{transactions[id][:h_id]}"
  harvest.expenses.delete(expense)
  p "Expense deleted"
rescue Harvest::NotFound
  puts "Unable to find #{transactions[id][:h_id]}"
end

if (transactions.has_key?(id)) and (transactions[id].has_key?(:receipt_path))
  if File.exists? transactions[id][:receipt_path]
    puts "#{transactions[id][:receipt_path]} found, removing"
    File.delete transactions[id][:receipt_path]
    puts "Receipt Deleted"
  end
end

transactions.delete(id)

File.open(transactions_file,'wb') do |f|
  f.write Marshal.dump(transactions)
end