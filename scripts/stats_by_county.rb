require "csv"

class County
  attr_reader :state, :name, :population

  def initialize(state, name, population:)
    @state = state
    @name = name
    @population = population
  end

  def ==(other)
    state == other.state &&
      name == other.name
  end
end

COUNTIES = [
  County.new("Massachusetts", "Essex", population: 789034),
  County.new("Massachusetts", "Middlesex", population: 1611699),
  County.new("New York", "Chautauqua", population: 126903),
  County.new("New York", "Erie", population: 918702),
  County.new("New York", "Madison", population: 70941),
  County.new("Pennsylvania", "Allegheny", population: 1216045),
  County.new("Pennsylvania", "Crawford", population: 84629),
  County.new("Pennsylvania", "Mercer", population: 109424),
  County.new("Virginia", "Loudoun", population: 413539),
]

def select_county?(state:, county:)
  county = County.new(state, county, population: nil)
  COUNTIES.include?(county)
end

rows = CSV.open("us-counties.csv", headers: true)
filtered_rows = rows.select do |row|
  select_county?(state: row["state"], county: row["county"])
end

grouped = filtered_rows.group_by { |row| "#{row['state']}: #{row['county']}" }

grouped.sort.each do |county, rows|
  recent_case_totals = rows.last(20).map { |row| row["cases"] }
  daily_case_deltas = recent_case_totals.each_cons(2).map { |a,b| b.to_i - a.to_i }
  daily_case_delta_3_day_averages = daily_case_deltas.each_cons(3).map { |a,b,c| ((a+b+c) / 3.0).round }
  puts "=" * 80
  puts "#{county} County"
  puts "Past week total cases: #{recent_case_totals.last(7).join(', ')}"
  puts "Past week new cases: #{daily_case_deltas.last(7).join(', ')}"
  puts "Past week new cases 3 day average: #{daily_case_delta_3_day_averages.last(7).join(", ")}"
  puts "=" * 80
end

class StatsByCounty
  def initialize(filtered_rows)
    @filtered_rows = filtered_rows
    @days_to_calculate = 7
  end

  def past_days(days = days_to_calculate)
    ((-days + 1)..0).map do |days_ago|
      Date.today + days_ago
    end
  end

  def recent_case_totals(county:, days: days_to_calculate)
    past_days(days).map do |date|
      case_totals(county: county, date: date)
    end
  end

  def recent_case_totals_per_population(county:, days: days_to_calculate)
    recent_case_totals(county: county).map do |delta|
      if delta
        per_population = delta.to_i / (county.population.to_f / 100_000)
        per_population.round(1)
      end
    end
  end

  def recent_case_deltas(county:)
    recent_case_totals(county: county, days: days_to_calculate + 1).each_cons(2).map do |a,b|
      if a && b
        b.to_i - a.to_i
      end
    end
  end

  def recent_case_deltas_per_population(county:)
    recent_case_deltas(county: county).map do |delta|
      if delta
        per_population = delta / (county.population.to_f / 100_000)
        per_population.round(1)
      end
    end
  end

  private

  attr_reader :days_to_calculate, :filtered_rows

  def case_totals(county:, date:)
    row = filtered_rows.detect do |row|
      row["state"] == county.state &&
        row["county"] == county.name &&
        row["date"] == date.to_s
    end
    row && row["cases"]
  end
end

def print_table_header(file, stats_by_county)
  file.print "| County |"
  stats_by_county.past_days.each do |date|
    file.print " #{date} |"
  end
  file.puts
  file.print "|"

  8.times do
    file.print " --- |"
  end
  file.puts
end

def print_table_data(file, &block)
  COUNTIES.each do |county|
    file.print "| #{county.state}: #{county.name} |"
    block.call(county).each do |case_total|
      file.print " #{case_total} |"
    end
    file.puts
  end
end

stats_by_county = StatsByCounty.new(filtered_rows)

File.open("stats_by_county.md", "w") do |file|
  file.puts "## Total cases by day"
  file.puts
  print_table_header(file, stats_by_county)
  print_table_data(file) do |county|
    stats_by_county.recent_case_totals(county: county)
  end

  file.puts "## Total cases by day (per 100,000 population)"
  file.puts
  print_table_header(file, stats_by_county)
  print_table_data(file) do |county|
    stats_by_county.recent_case_totals_per_population(county: county)
  end

  file.puts
  file.puts "## New cases by day"
  file.puts
  print_table_header(file, stats_by_county)
  print_table_data(file) do |county|
    stats_by_county.recent_case_deltas(county: county)
  end

  file.puts
  file.puts "## New cases by day (per 100,000 population)"
  file.puts
  print_table_header(file, stats_by_county)
  print_table_data(file) do |county|
    stats_by_county.recent_case_deltas_per_population(county: county)
  end
end
