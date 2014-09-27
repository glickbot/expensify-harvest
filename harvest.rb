#!/usr/bin/env ruby

require 'harvested'
require 'csv'
require 'json'
require 'chronic'
require 'slop'

command = nil

opts = Slop.new(:help => true, :strict => true) do
  banner "Usage: #{$0} get|put|delete [options] --file <csv file>"
  on :g, :get, 'Get expenses from Harvest, by week (of given date), or date range (with after/before)'
  on :p, :put, 'Put expenses to Harvest from CSV File'
  on :x, :delete, 'Delete expenses from Harvest using CSV File'
  on :u, :user, 'Harvest Username', :argument => true
  on :w, :password, 'Harvest Password', :argument => true
  on :s, :subdomain, 'Harvest Subdomain', :argument => true
  on :f, :file, 'CSV file to use (required)', :required => true, :argument => true
  on :h, :help, 'Prints this help'
  on :c, :config, 'Config File', :argument => true, :default => "./harvest_cfg.json"
  on :d, :date, 'Get expenses from the week of this day', :argument => true, :default => "today"
  on :a, :after, 'Get expenses after this day', :argument => true
  on :b, :before, 'Get expenses before this day', :argument => true
end

begin
  opts.parse![0]
rescue => e
  puts "\nError: #{e.message}\n\n"
  puts opts.help
  exit!
end

unless opts.put? or opts.get? or opts.delete?
  puts "\nError: Missing command, please use either --get or --put"
  puts opts.help
  exit!
end

if File.exists?(opts[:config])
  harvest_config = JSON.parse(File.read(opts[:config]))
end

%w(username password subdomain).each do |p|
  harvest_config[p] = opts[p.to_sym] if opts.present?(p.to_sym)
  if harvest_config[p].nil?
    puts "#{p} is not defined in either config or options"
    exit!
  end
end

harvest = Harvest.hardy_client(
    subdomain: harvest_config['subdomain'],
    username: harvest_config['username'],
    password: harvest_config['password']
)

if opts.get?

  now = Chronic.parse(opts[:date])

  after = Chronic.parse('last monday', now: now)
  after = Chronic.parse(opts[:after], now: now) if opts.after?

  before = Chronic.parse('this sunday', now: now)
  before = Chronic.parse(opts[:before], now: now) if opts.before?

  puts "Getting expenses between #{after} and #{before}"
  puts "#{now}"


  puts "retrieving categories"
  categories = harvest.expense_categories.all

  puts "retrieving projects"
  projects = harvest.time.trackable_projects

  puts "reticulating splines"
  cat_ids = Hash[categories.map{ |c| [c[:id], c]}]
  proj_ids = Hash[projects.map{ |p| [p[:id], p]}]

  account = harvest.account.who_am_i


  expenses = harvest.reports.expenses_by_user(account[:id], after, before)

  headers = %w(
 spent_at
 client
 total_cost
 category_name
 project_name
 expense_category_id
 project_id
 created_at
 id
 billable
 invoice_id
 is_closed
 notes
 units
 updated_at
 user_id
 has_receipt
 receipt_url
 is_locked
 locked_reason)

  CSV.open(opts[:file], 'wb', { :headers => headers, :write_headers => true }) do |csv|
    expenses.each { |e|
      puts "Loading #{e[:id]}"
      r = []
      headers.each { |h|
        value = nil
        case h
          when 'project_name'
            value = proj_ids[e[:project_id]][:name]
          when 'category_name'
            value = cat_ids[e[:expense_category_id]][:name]
          when 'client'
            value = proj_ids[e[:project_id]][:client]
          else
            case e[h]
              when Date
                value = e[h].strftime('%F')
              else
                value = e[h]
            end
        end
        r.push value
      }
      csv << r
    }
  end

  puts "Harvest entries saved to #{opts[:file]}"

elsif opts.put?

  changeable = %i(
 spent_at
 total_cost
 expense_category_id
 project_id
 billable
 notes
 units)

  begin
    data = CSV.read(opts[:file], headers:true, header_converters: :symbol )
  rescue => e
    "Error Loading CSV file: #{e.message}"
  end
  data.each_with_index do |r,i|

    expense = nil
    id = nil
    create = nil

    if r.include?(:id) and !r[:id].nil?
      puts "Checking updates for #{r[:id]}"
      expense = harvest.expenses.find(r[:id])
      id = r[:id]
      create = false
    else
      puts "Creating new expense"
      expense = Harvest::Expense.new()
      id = i
      create = true
    end

    update = false
    puts "Checking #{id}"
    r.each do |k, v|
      if changeable.include?(k)
        if expense[k].eql? v
          #puts "\tSkipping #{k}: #{v} the same"
        else
          puts "\tUpdating #{k}: #{expense[k]} to #{v}"
          if k.eql?(:spent_at)
            v = Chronic.parse(v)
          end
          expense[k] = v
          update = true
        end
      else
        #puts "\tSkipping #{k}: Non-changeable attribute"
      end
    end
    if update
      puts "Updating #{id}"
      begin
        if create
          expense = harvest.expenses.create(expense)
        else
          expense = harvest.expenses.update(expense)
        end
      rescue => e
        puts "ERROR: Updating #{id} (CSV Row #{i + 1}): #{e.message}"
      end
    end

    puts "Finished Loading from #{opts[:file]}"
  end
elsif opts.delete?

  begin
    data = CSV.read(opts[:file], headers:true, header_converters: :symbol )
  rescue e
    "Error Loading CSV file: #{e.message}"
  end

  data.each_with_index do |r, i|

    next unless r.include?(:id) and !r[:id].nil?

    begin
      expense = harvest.expenses.find(r[:id])
      puts "#{r[:id]} found, deleting"
      expense = harvest.expenses.delete(expense)
    rescue => e
      puts "ERROR: Deleting #{r[:id]} (CSV Row #{i + 1}): #{e.class}"
    end

  end

end