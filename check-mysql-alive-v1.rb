require 'sensu-plugin/check/cli'
require 'mysql2'
require 'inifile'

class CheckMySQL < Sensu::Plugin::Check::CLI
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS'

  option :ini,
         description: 'My.cnf ini file',
         short: '-i VALUE',
         long: '--ini VALUE'

  option :ini_section,
         description: 'Section in my.cnf ini file',
         long: '--ini-section VALUE',
         default: 'client'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST'

  option :database,
         description: 'Database schema to connect to',
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'test'

  option :port,
         description: 'Port to connect to',
         short: '-P PORT',
         long: '--port PORT',
         default: '3306'

  option :socket,
         description: 'Socket to use',
         short: '-s SOCKET',
         long: '--socket SOCKET'

  def run
    if config[:ini]
      ini = IniFile.load(config[:ini])
      section = ini[config[:ini_section]]
      db_user = section['user']
      db_pass = section['password']
    else
      db_user = config[:user]
      db_pass = config[:password]
    end

    db_opts = {
      host: config[:hostname],
      username: db_user,
      password: db_pass,
      database: config[:database],
      port: config[:port].to_i,
      socket: config[:socket]
    }

    client = nil
    begin
      # The Mysql2::Client constructor takes a hash of options.
      client = Mysql2::Client.new(db_opts)
      
      # The version can be retrieved from the #server_info method.
      info = client.server_info
      
      ok "Server version: #{info[:version]}"
    rescue Mysql2::Error => e
      critical "Error message: #{e.message}"
    ensure
      # Close the connection if it was successfully opened.
      client&.close
    end
  end
end
