# frozen_string_literal: true

require "cassandra"
require "sorted_set"

module CassandraClient
  class << self
    def session
      @session ||= cluster.connect(keyspace)
    end

    # Connect without keyspace (useful for creating keyspace)
    def session_without_keyspace
      @session_no_keyspace ||= cluster.connect
    end

    # Ensure keyspace exists with given replication map
    def ensure_keyspace!(ks = keyspace, dc = ENV.fetch("CASSANDRA_DC", "datacenter1"), rf = 3)
      cql = <<~CQL.strip
        CREATE KEYSPACE IF NOT EXISTS #{ks}
        WITH replication = {'class': 'NetworkTopologyStrategy', '#{dc}': #{rf}}
      CQL
      session_without_keyspace.execute(cql)
      wait_for_keyspace!(ks)
    end

    def wait_for_keyspace!(ks = keyspace, timeout_seconds = 15)
      deadline = Time.now + timeout_seconds

      loop do
        exists = session_without_keyspace.execute(
          "SELECT keyspace_name FROM system_schema.keyspaces WHERE keyspace_name = '#{ks}'"
        ).any?

        return true if exists
        raise "Keyspace '#{ks}' did not become visible in time" if Time.now > deadline

        sleep 0.5
      end
    end

    private

    def cluster
      @cluster ||= Cassandra.cluster(cluster_options)
    end

    def cluster_options
      options = {
        hosts: contact_points,
        port: port
      }

      dc = ENV["CASSANDRA_DC"]
      if dc && !dc.empty?
        options[:load_balancing_policy] =
          Cassandra::LoadBalancing::Policies::DCAwareRoundRobin.new(dc)
      end

      options
    end

    def contact_points
      ENV.fetch("CASSANDRA_CONTACT_POINTS", "127.0.0.1")
        .split(",")
        .map(&:strip)
        .reject(&:empty?)
    end

    def port
      ENV.fetch("CASSANDRA_PORT", "9042").to_i
    end

    def keyspace
      ENV.fetch("CASSANDRA_KEYSPACE")
    end
  end
end
