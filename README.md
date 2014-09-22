Expensify-Harvest
================
### Upload Expensify.com's CSV Exports to Harvest

##Purpose:
Expensify has a nice interface for managing receipts, auto-pulls from various banks, and can create eReciepts for some expenses under $75. Hugly useful. It does not, however, have any integrations with Harvest ( at least at the time of this writing ).

## Status: WIP

##Method:

#### Usage
- Manage expenses with Expensify as the system of record for your 
expenses.
- Add "Tags" to expenses that reference Harvest project IDs (i.e. "Acme Client - 1234567")
- Add a custom CSV Export format that include Expensify's ID
- Upload pdf/image attachments to Expensify as the system of record

#### Import to Harvest
- Export expenses to CSV
- Run csv2harvest.rb ./<location_of_csv>
- Profit

##Install
#### Bundler
- untested, check the requirements in the script if you have issues
- probably need PhantomJS, installed with brew, etc, for the 'poltergeist' gem

##Configure
#### harvest_cfg.json
- an example harvest_cfg.json (harvest_csv.json.example) is in the repo, fill it out with your info.

## Scripts

#### csv2harvest.rb <csv_file>
- Imports CSV file from Expensify to Harvest

#### list_categories.rb
- Lists available categories for your convenience

#### list_projects.rb
- Lists available projects for your convenience

#### delete_expense.rb
- Deletes expenses in local transaction record, and Harvest, in case a change/update needs to be made to an Expensify expense.
