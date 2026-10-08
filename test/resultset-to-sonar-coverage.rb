require "json"

resultset_path = ARGV[0] || "coverage/.resultset.json"
output_path = ARGV[1] || "coverage/coverage.xml"

data = JSON.parse(File.read(resultset_path))
coverage = data.values.first["coverage"]

root = ENV["TOOLS_PATH"] || "/opt/provisioning-tools"

total_lines = 0
covered_lines = 0

files_xml = coverage.filter_map do |file, line_data|
  lines = line_data.is_a?(Hash) ? line_data["lines"] : line_data
  next unless lines.is_a?(Array)
  relevant = lines.compact
  total_lines += relevant.size
  covered_lines += relevant.count { |l| l > 0 }
  name = "src/#{file.sub("#{root}/", "")}"

  lines_xml = lines.each_with_index.filter_map do |hits, idx|
    next if hits.nil?
    "    <lineToCover lineNumber=\"#{idx + 1}\" covered=\"#{hits > 0}\"/>"
  end.join("\n")

  "  <file path=\"#{name}\">\n#{lines_xml}\n  </file>"
end.join("\n")

xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<coverage version=\"1\">\n#{files_xml}\n</coverage>\n"

File.write(output_path, xml)
overall_rate = total_lines == 0 ? 0 : covered_lines.to_f / total_lines
puts "Coverage XML written to #{output_path} (#{covered_lines}/#{total_lines} lines, #{(overall_rate * 100).round(1)}%)"
