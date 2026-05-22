namespace :cassandra do
  desc "Ensure keyspace exists and apply CQL migrations"
  task migrate: :environment do
    require "pathname"

    root = Pathname.new(Rails.root.join("db/cassandra/migrations"))
    unless root.directory?
      puts "No Cassandra migrations found at #{root}"
      return
    end

    puts "Ensuring keyspace #{ENV.fetch('CASSANDRA_KEYSPACE', 'clareo')} exists..."
    CassandraClient.ensure_keyspace!
    puts "Applying migrations from #{root}..."

    Dir[root.join("*.cql").to_s].sort.each do |file|
      puts "Applying #{file}"
      content = File.read(file)
      # split statements by ';' and execute non-empty statements
      statements = content.split(";").map(&:strip).reject(&:empty?)
      statements.each do |stmt|
        begin
          CassandraClient.session_without_keyspace.execute(stmt)
        rescue => e
          puts "Failed to execute statement in #{file}: #{e.class}: #{e.message}"
          raise
        end
      end
    end

    puts "Cassandra migrations applied."
  end
end
