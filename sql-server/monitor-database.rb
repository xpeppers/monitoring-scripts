

DATA_DIR="database-blockers"

def usage
  fail "Usage: #{$0} <server> <username> <password>" 
end

def parse_command_line
  usage if ARGV.size != 3
  @server = ARGV[0]
  @username = ARGV[1]
  @password = ARGV[2]
end

def run_command output_file_name
  command = "EXEC monitoringcgprodb.dbo.sp_blocker_pss08 null, null, 'jTDS'"
  "sqlcmd -S #{@server} -U #{@username} -P #{@password} -Q \"#{command}\" -s\";\" -w2000 -W -o\"#{output_file_name}\""
end

def create_output_file_name
  timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S") 
  File.join(DATA_DIR, "database-blockers-#{timestamp}.csv")
end

def create_data_dir
  begin
    Dir.mkdir DATA_DIR
  rescue
  end
end

def fail(message)
  puts message
  exit
end

parse_command_line
create_data_dir
while true
  system(run_command(create_output_file_name)) || fail("did not work")
  sleep 30
end
