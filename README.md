Expensify-Harvest
================
### Upload Expensify.com's CSV Exports to Harvest

##Purpose:
Expensify has a nice interface for managing receipts, auto-pulls from various banks, and can create eReciepts for some expenses under $75. Hugly useful. It does not, however, have any integrations with Harvest ( at least at the time of this writing ).

## Status: POC

##Expensify Method:

#### Usage
- Manage expenses with Expensify as the system of record for your 
expenses.
- Add "Tags" to expenses that reference Harvest project IDs (i.e. "Acme Client - 1234567")
- Add a custom CSV Export format that include Expensify's ID
- Upload pdf/image attachments to Expensify as the system of record

#### Import to Harvest
- Export expenses to CSV
- Run ```expensify.rb ./<location_of_csv>```
- Profit

##Install

	]$ brew install ruby (maybe optional)
	]$ gem install bundler
	]$ sudo xcode-select --install
	]$ brew install phantomjs
	]$ bundler

##Configure
#### harvest_cfg.json
- an example ```harvest_cfg.json``` (harvest_csv.json.example) is in the repo, fill it out with your info.

## Scripts

#### expensify.rb <csv_file>
- Imports CSV file from Expensify to Harvest

#### list_categories.rb
- Lists available categories for your convenience

#### list_projects.rb
- Lists available projects for your convenience

#### delete_expense.rb
- Deletes expenses in local transaction record, and Harvest, in case a change/update needs to be made to an Expensify expense.

##CSV Only Method
## Scripts
#### expensify.rb
- Gets/Puts/Deletes expenses from/to Harvest using CSV files.
- NOTE: Doesn't currently upload/attach receipts.

#### Method (example use)
- Use ```./harvest.rb --get --file this_week_expenses.csv``` to download expenses
- Modify csv file in excel ( save as MS-DOS csv )
- Use ```./harvest.rb --put --file this_week_expenses-fixed.csv``` to update expenses


#### Uploading new expenses
- Use ```./harvest.rb --put --file new_expenses.csv``` to upload new expenses

#### Downloading Expenses to CSV
- ```harvest.rb``` uses ```--after``` and ```--before``` as date ranges if defined.
- With a --date option, ```harvest.rb``` selects the expenses from the week that date is in. It uses the last monday as ```--after```, and the next sunday as ```--before```, from the perspective of the specified date.
- With no options specified, ```harvest.rb``` uses "now" as ```--date```

#### Updating Expenses
- Use ```./harvest.rb --put --file updates_for_harvest.csv``` to update expenses.

#### Deleteing expenses
- Use ```./harvest.rb --delete --file csv_with_ids.csv``` to delete.

#### ```harvest.rb``` Usage

```
Usage: ./harvest.rb get|put|delete [options] --file <csv file>
    -g, --get            Get expenses from Harvest, by week (of given date), or date range (with after/before)
    -p, --put            Put expenses to Harvest from CSV File
    -x, --delete         Delete expenses from Harvest using CSV File
    -u, --user           Harvest Username
    -w, --password       Harvest Password
    -s, --subdomain      Harvest Subdomain
    -f, --file           CSV file to use (required)
    -c, --config         Config File (default: ./harvest_cfg.json)
    -d, --date           Get expenses from the week of this day (default: today)
    -a, --after          Get expenses after this day
    -b, --before         Get expenses before this day
    -h, --help           Display this help message.
```
