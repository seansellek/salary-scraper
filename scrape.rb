require 'capybara'
require 'capybara/dsl'
require 'capybara-webkit'
require 'csv'


class SalaryScraper
  include Capybara::DSL

  def initialize url
    Capybara.default_driver = :webkit
    Capybara.javascript_driver = :webkit
    Capybara::Webkit.configure do |config|
      config.allow_url("cognoswww.miamidade.gov")
    end
    @data = []
    @url = url
  end

  def scrape
    prepare_scrape
    
    #Process First Page
    table = find_table
    prepare_headers(table)
    @data = parse(table)
    write_out!

    #Process every other page
    loop do
      #Grab data from first row
      first_record_content = find_first_record(table).text
      click_on('Page down')
      #wait for table to change (async) before continueing
      find_first_record(table).has_no_content?(first_record_content)

      #process this page
      table = find_table
      @data = @data | parse(table)
      write_out!

      #stop once reached the end
      break unless next_page?
    end
  end

  def prepare_scrape
    visit @url
    click_button('Search')
  end

  #grabs the headers from the given table, and adds them to @data, including an additional "Department" column
  def prepare_headers table
    header = []
    table.all(:xpath, "tr[1]/td/span").each do |cell|
      header << cell.text
    end
    header << "Department"
    @data = [header]
  end

  #returns array of row content
  def get_row salary_row
    row = []
    salary_row.all(:xpath, "td").each do |cell|
      row << cell.find(:xpath, "span[1]").text
    end
    row
  end

  #finds table on current page
  def find_table
    find(:xpath, ".//*[@id='rt_NS_']/tbody/tr[1]/td/div[5]/table/tbody/tr/td/table/tbody/tr[2]/td/table/tbody")
  end

  #returns table as 2d array of rows, including the department as a last column
  def parse table
    dept = get_dept(table)
    table.all(:xpath, "tr[position() > 1]").map do |tr|
      p get_row(tr) << dept
    end
  end

  #given a table, navigates up and finds the department
  def get_dept table
    table.find(:xpath, "../../../../tr[1]/td/span[3]").text
  end

  #Checks if next page link exists on page
  def next_page?
    page.has_xpath?(".//*[@id='CVNavLinks_NS_']/table/tbody/tr/td[6]/a")
  end

  #Grabs element from first cell of first row of table, used to track async load progress
  def find_first_record table
    page.find(:xpath, ".//*[@id='rt_NS_']/tbody/tr[1]/td/div[5]/table/tbody/tr/td/table/tbody/tr[2]/td/table/tbody/tr[2]/td[1]/span")
  end

  #append @data to end of csv and clear memory
  def write_out!
    CSV.open("salaries.csv", "ab") do |io| 
      @data.each do |row|
        io << row
      end
    end
    @data = []
  end

end

SalaryScraper.new("https://cognoswww.miamidade.gov/cognos/cgi-bin/cognosisapi.dll?b_action=cognosViewer&ui.action=run&ui.object=%2fcontent%2ffolder%5b%40name%3d%27Financial%20Transparency%20Reports%27%5d%2ffolder%5b%40name%3d%27Production%20Reports%27%5d%2freport%5b%40name%3d%27Employee%20Salaries%27%5d&ui.name=Employee%20Salaries&run.outputFormat=&run.prompt=true").scrape

