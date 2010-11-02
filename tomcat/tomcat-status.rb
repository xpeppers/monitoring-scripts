#!/usr/bin/env ruby

require 'net/http'
require 'rexml/document'

def usage
  puts __FILE__ + " <server> <port> <username> <password>"
  exit 
end

def parse_command_line
  if ARGV.size < 4
    usage
  end
  @tomcat_host=ARGV[0]
  @tomcat_port=ARGV[1]
  @tomcat_user=ARGV[2]
  @tomcat_password=ARGV[3]
end

def get_status
  req = Net::HTTP::Get.new('/manager/status?XML=true')
  req.basic_auth @tomcat_user, @tomcat_password
  res = Net::HTTP.start(@tomcat_host, @tomcat_port) {|http|
    http.request(req)
  }
  raise res.message unless Net::HTTPSuccess === res
  res.body
end

def parse_xml(xml)
  @document = REXML::Document.new(xml)
end

def find_by_xpath(xpath)
  REXML::XPath.match(@document.root, xpath)
end

def find_attribute_by_xpath(xpath, attribute_name)
  elements = find_by_xpath(xpath)
  raise "xpath not found '#{xpath}'" if elements.size == 0
  raise "xpath not unique (#{elements.size}) '#{xpath}'" if elements.size > 1
  element = elements[0]
  element.attributes[attribute_name]
end

def format_memory(amount)
  sprintf "%5.1f", amount.to_f / (1000*1000)
end

def total_memory
  find_attribute_by_xpath("/status/jvm/memory", "total").to_i
end

def free_memory
  find_attribute_by_xpath("/status/jvm/memory", "free").to_i
end

def max_memory
  find_attribute_by_xpath("/status/jvm/memory", "max").to_i
end

def memory_status
  sprintf "Mem: %s/%s MB", format_memory(total_memory-free_memory), format_memory(max_memory)
end

def timestamp
  Time.now.strftime("%Y/%m/%d %H:%M:%S")  
end

def current_date
  Time.now.strftime("%Y-%m-%d")  
end

DELTA = Hash.new([0, 0])

def previous_request_count(name)
  DELTA[name].first
end

def previous_processing_time(name)
  DELTA[name].last
end

def update_previous(name, request_count, processing_time)
  DELTA[name] = [request_count.to_f, processing_time.to_f]
end

Connector = Struct.new(:name, :current_threads_busy, :max_threads, :request_count, :processing_time, :error_count) do
  def to_s
    delta_request_count = request_count.to_f - previous_request_count(name)
    average_processing_time = (processing_time.to_f - previous_processing_time(name)) / delta_request_count
    update_previous(name, request_count, processing_time)
    sprintf "(%s thr %3d/%3d requests %d avg %7.2f err %d)", name, current_threads_busy, max_threads, delta_request_count, average_processing_time, error_count
  end
end

def find_connectors
  find_by_xpath("/status/connector").map do |element|
    name = element.attributes["name"]
    this_connector = "/status/connector[@name='#{name}']"
    current_threads_busy = find_by_xpath("#{this_connector}/workers/worker[@stage!='K']").size
    max_threads = find_attribute_by_xpath("#{this_connector}/threadInfo", "maxThreads")
    processing_time = find_attribute_by_xpath("#{this_connector}/requestInfo", "processingTime")
    request_count = find_attribute_by_xpath("#{this_connector}/requestInfo", "requestCount")
    error_count = find_attribute_by_xpath("#{this_connector}/requestInfo", "errorCount")
    Connector.new(name, current_threads_busy, max_threads, request_count, processing_time, error_count)
  end
end

def status_line
  result = "#{timestamp} #{memory_status}"
  find_connectors.each do |connector|
    result << " " << connector.to_s 
  end
  result
end

def working_url_list
  list = find_by_xpath("/status/connector/workers/worker[@stage!='K']").
  	   map {|w| w.attributes["currentUri"] + "?" + w.attributes["currentQueryString"]}.
  	   reject {|w| w == "???" }.
  	   reject {|w| w == "/manager/status?XML=true" }

  list.join("\n")
end

def add_time_stamp text  
  sprintf("\n------ %s\n%s\n", timestamp, text)
end

def save_xml
  File.open("last_status.xml", "w") do |f|
    f.write @document.to_s
  end
end

def save_to_rolling_file tag, text
  File.open("#{tag}-#{current_date}.txt", "a") do |f|
    f.puts text
  end
end

parse_command_line
while true
  parse_xml(get_status)
  save_to_rolling_file "tomcat-status", status_line    
  save_to_rolling_file "tomcat-open-uris", add_time_stamp(working_url_list)
  sleep 30
end

