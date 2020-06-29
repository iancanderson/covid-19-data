require "csv"

COUNTIES_TO_PARSE = {
  "Massachusetts" => ["Essex"],
  "New York" => ["Chautauqua", "Erie", "Madison"],
  "Pennsylvania" => ["Allegheny", "Crawford", "Mercer"],
}

def select_county?(state:, county:)
  counties_to_select = COUNTIES_TO_PARSE[state]
  counties_to_select&.include?(county)
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

