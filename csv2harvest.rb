#!/usr/bin/env ruby

require "harvested"
require 'csv'
require 'net/https'
require 'net/http/post/multipart'
require 'json'
require 'open-uri'
require 'capybara'
require 'capybara/poltergeist'

config_file = "./harvest_cfg.json"
receipt_dir = "./receipts"
transactions_file = "./transactions.db"

if ARGV.empty?
  puts "Please enter a csv file."
  exit
elsif !File.exists?(ARGV[0])
  puts "The file '#{ARGV[0]}' doesn't exist."
  exit
elsif !File.exists?(config_file)
  puts "Config file (#{config_file}) doens't exist."
  exit
end

config = JSON.parse(File.read(config_file))

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app,
                                    js_errors: false,
                                    timeout: 120
  )
end

Capybara.current_driver = :poltergeist

data = CSV.read(ARGV[0], headers:true, header_converters: :symbol )

transactions = Hash.new
if File.exists?(transactions_file)
  transactions = Marshal.load(File.binread(transactions_file))
  puts "Loaded previous transactions"
end

harvest = Harvest.hardy_client(subdomain: config['subdomain'], username: config['username'], password: config['password'])

uri_root = "https://#{config['subdomain']}.harvestapp.com"

puts "retrieving categories"
categories = harvest.expense_categories.all

puts "reticulating splines"
cat_name = Hash[categories.map{ |c| [c[:name].strip, c]}]

projects_expensed = Hash.new
total_expensed = 0.0

data.each do |r|
  id = r[:id]
  cname = "AMEX - " + r[:category]
  raise KeyError.new("Not found: '#{cname}'") unless cat_name.has_key?(cname)
  if ( r[:tag].nil? ) or ( !r[:tag].include? ' - ' )
    puts "ERROR: Project ID #{r[:tag]} does not contain delimiter!, skipping #{id}:"
    puts r
    next
  end
  project_id = r[:tag].split(' - ').last
  raise KeyError.new("Project ID Not found in '#{r[:tag]}'") if project_id.nil?
  expense_category_id = cat_name[cname][:id]
  spent_at = Time.parse(r[:timestamp])
  total_cost = r[:amount].delete(',').to_f
  billable = true

  expense = nil

  if transactions.has_key?(id)
    begin
      expense = harvest.expenses.find(transactions[id][:h_id])
      if total_cost == expense[:total_cost]
        p "Transaction #{id} with valid harvest #{expense[:id]} for #{total_cost}"
      else
        p "Transaction #{id} with INVALID harvest #{expense[:id]}, #{total_cost} vs #{expense[:total_cost]}"
        p "DELETE #{id} with delete script"
        next
      end
    rescue Harvest::NotFound
      puts "Transaction record with bogus harvest ID"
      p "DELETE #{id} with delete script"
      next
    end
  end

  if expense.nil?
    begin
      expense = Harvest::Expense.new(
          notes:r[:merchant],
          expense_category_id: expense_category_id,
          project_id: project_id,
          spent_at: spent_at,
          total_cost: total_cost,
          billable: billable
      )
      puts "Creating expense"
      expense = harvest.expenses.create(expense)

    rescue Harvest::InformHarvest => e
      error = e.message
      if error.include? "locked for this time period"
        puts "Resubmitting with new date"
        expense = Harvest::Expense.new(
            notes:r[:merchant] + ", Spent at " + r[:timestamp],
            expense_category_id: expense_category_id,
            project_id: project_id,
            spent_at: Time.now,
            total_cost: total_cost,
            billable: billable
        )
        expense = harvest.expenses.create(expense)
        puts "Resubmitted"
      else
        puts "This doesn't look like a locked time period, not reposting"
      end
    end
  end

  h_id = expense[:id]
  transactions[id] = {
      :h_id => h_id,
      :receipt_added => false,
      :error => false
  }
  File.open(transactions_file,'wb') do |f|
    f.write Marshal.dump(transactions)
  end

  unless expense[:has_receipt]
    receipt_file = ""
    receipt_type = ""
    receipt_path = ""
    open(r[:receipt]) {|u|
      case u.content_type
        when "text/html"
          receipt_file = "#{id}.png"
          receipt_path = "#{receipt_dir}/#{receipt_file}"
          session = Capybara::Session.new(:poltergeist)
          puts "Downloading: " + r[:receipt]
          session.visit r[:receipt]
          if session.has_selector?('#receipt')
            receipt = session.find_by_id('receipt')
            if receipt.has_link? 'Download a Copy'
              download_url = receipt.find_link('Download a Copy')['href']
              open(download_url) {|d|
                ext = d.content_type.split('/')[1]
                receipt_file = "#{id}.#{ext}"
                receipt_path = "#{receipt_dir}/#{receipt_file}"
                File.open(receipt_path, 'wb') { |file| file.write(d.read) }
                receipt_type = d.content_type
              }
            elsif receipt.has_selector? "table.ereceipt"
              session.driver.resize(310, 340)
              session.save_screenshot(receipt_path, :selector => 'table.ereceipt')
            end
          else
            puts "#recipt element not found in html, defaulting to full view"
            session.save_screenshot(receipt_path, :full => true)
          end
          puts "Download complete."
          receipt_type = "image/png"
          Capybara.reset_sessions!
        else
          ext = u.content_type.split('/')[1]
          receipt_file = "#{id}.#{ext}"
          receipt_path = "#{receipt_dir}/#{receipt_file}"
          File.open(receipt_path, 'wb') { |file| file.write(u.read) }
          receipt_type = u.content_type
      end
    }

    transactions[id][:receipt_path] = receipt_path
    transactions[id][:content_type] = receipt_type
    transactions[id][:receipt_file] = receipt_file
    File.open(transactions_file,'wb') do |f|
      f.write Marshal.dump(transactions)
    end

    receipt_url = "#{uri_root}/expenses/#{h_id}/receipt"
    puts "Uploading receipt to #{receipt_url}"
    url = URI.parse(receipt_url)
    req = Net::HTTP::Post::Multipart.new url.path,
                                         "expense[receipt]" => UploadIO.new(
                                             File.new(receipt_path), receipt_type, receipt_file)
    req.basic_auth config['username'], config['password']
    req['Accept'] = 'application/json'
    n = Net::HTTP.new(url.host, url.port)
    n.use_ssl = true
    res = n.start do |http|
      http.request(req)
    end

    case res
      when Net::HTTPOK
        puts "Receipt uploaded"
        transactions[id][:reciept_added] = true
      else
        transactions[id][:error] = e.inspect
        puts "Unexpected result from upload:"
        puts e.inspect
    end
    File.open(transactions_file,'wb') do |f|
      f.write Marshal.dump(transactions)
    end
  end
  total_expensed += total_cost
  projects_expensed[r[:tag]] = 0 unless projects_expensed.has_key?(r[:tag])
  projects_expensed[r[:tag]] += total_cost
end

puts projects_expensed

projects_expensed.each_key { |k|
  puts sprintf "%-20s$%.2f", k, projects_expensed[k]
}

puts sprintf "%-20s$%.2f", "Total", total_expensed
