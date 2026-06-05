module CassandraSpecHelpers
  TABLES = %w[
    clareo.wallets
    clareo.transactions_by_owner
    clareo.idempotency_keys_by_owner
    clareo.ledger_entries_by_owner
    clareo.payment_intents_by_owner
    clareo.expense_entries
    clareo.expense_attachments
  ]

  def truncate_cassandra!
    # For tests, ensure keyspace exists with RF=1 to work on single-node test clusters
    CassandraClient.ensure_keyspace!(CassandraClient.send(:keyspace), ENV.fetch("CASSANDRA_DC", "datacenter1"), 1)
    TABLES.each do |t|
      CassandraClient.session.execute("TRUNCATE #{t}")
    end
  end
end

RSpec.configure do |config|
  config.include CassandraSpecHelpers

  config.before(:each) do
    truncate_cassandra!
  end
end
