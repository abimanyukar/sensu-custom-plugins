#!/usr/bin/env ruby
#require 'json'
#require 'erb'
require 'sensu-plugin/check/cli'
require 'mysql2'
#require 'time'
 
class CheckUnroutedQuestions < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Database host',
         short: '-h HOST',
         long: '--host HOST',
         required: true
 
  option :port,
         description: 'Database port',
         short: '-P PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 3306
 
  option :user,
         description: 'Database username',
         short: '-u USER',
         long: '--user USER',
         default: 'azureuser'
 
  option :password,
         description: 'Database password',
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         required: true
 
  option :database,
         description: 'Database name',
         short: '-d DATABASE',
         long: '--database DATABASE',
         required: true
 
  def run
    begin
      client = Mysql2::Client.new(
        host: config[:host],
        port: config[:port],
        username: config[:user],
        password: config[:password],
        database: config[:database]
      )
 
      query = <<-SQL
        SELECT c.id, c.name, COUNT(*) AS question_count
        FROM question q
        LEFT JOIN routing_log rl ON rl.question_id = q.id
        JOIN company c ON c.id = q.company_id
        WHERE q.date_created > DATE_FORMAT(DATE_ADD(now(), Interval  -1 day),'%Y-%m-%d') 
          AND q.date_created < DATE_FORMAT(DATE_ADD(now(), Interval  -1 hour),'%Y-%m-%d') 
          AND q.reroute_type IS NULL
          AND q.status = 0
          AND rl.question_id IS NULL
          AND q.company_id NOT IN (56)
          AND q.class = 'net.insidr.question.OneOnOneQuestion'
        GROUP BY c.name
        ORDER BY question_count DESC;
      SQL
 
      results = client.query(query)
 
      if results.count.zero?
        ok('No unrouted questions found.')
      else
        output_lines = []
        results.each do |row|
          output_lines << "#{row['name']}: #{row['question_count']}"
        end
 
        message = output_lines.join(' | ')
        critical("Unrouted questions found → #{message}")
      end
 
    rescue Mysql2::Error => e
      unknown("Database error: #{e.message}")
    ensure
      client&.close
    end
  end
end