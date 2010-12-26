require 'net/http'


def get_status
  req = Net::HTTP::Get.new('/server-status?auto')
  res = Net::HTTP.start(@apache_host, @apache_port) {|http|
	    http.request(req)
        }
  raise res.message unless Net::HTTPSuccess === res
  res.body
end

def timestamp
  Time.now.strftime("%Y/%m/%d %H:%M:%S")  
end

def current_date
  Time.now.strftime("%Y-%m-%d")  
end

def parse_status status  
  res = status.split
  total_workers = res[1].to_i + res[3].to_i
  "#{timestamp} #{res[0]} #{res[1]}/#{total_workers} "
end

def save_to_rolling_file tag, text
  File.open("#{tag}-#{current_date}.txt", "a") do |f|
    f.puts text
  end
end

def usage
	puts "#{$0} <apache ip> <apache port>"
	exit
end 

def parse_command_line
  if ARGV.size < 2
	  usage
  end
 @apache_host = ARGV[0]
 @apache_port = ARGV[1]
end


parse_command_line
while true
 
 status_line = parse_status(get_status)
 save_to_rolling_file "apache-status", status_line
 sleep 10
end
