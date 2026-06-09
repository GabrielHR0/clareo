# frozen_string_literal: true

require "cassandra"
require "sorted_set"

module CassandraClient
  class << self
    def session
      @session ||= connect_with_retry { cluster.connect(keyspace) }
    end

    # Connect without keyspace (useful for creating keyspace)
    def session_without_keyspace
      @session_no_keyspace ||= connect_with_retry { cluster.connect }
    end

    # Ensure keyspace exists with given replication map
    def ensure_keyspace!(ks = keyspace, dc = ENV.fetch("CASSANDRA_DC", "datacenter1"), rf = ENV.fetch("CASSANDRA_RF", 1).to_i)
      cql = <<~CQL.strip
        CREATE KEYSPACE IF NOT EXISTS #{ks}
        WITH replication = {'class': 'NetworkTopologyStrategy', '#{dc}': #{rf}}
      CQL
      connect_with_retry { session_without_keyspace.execute(cql) }
      wait_for_keyspace!(ks)
    end

    def wait_for_keyspace!(ks = keyspace, timeout_seconds = 15)
      deadline = Time.now + timeout_seconds

      loop do
        exists = connect_with_retry do
          session_without_keyspace.execute(
            "SELECT keyspace_name FROM system_schema.keyspaces WHERE keyspace_name = '#{ks}'"
          ).any?
        end

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

      username = ENV["CASSANDRA_USERNAME"]
      password = ENV["CASSANDRA_PASSWORD"]
      if username && !username.empty? && password && !password.empty?
        options[:username] = username
        options[:password] = password
      end

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

    def connect_with_retry(max_retries: 30, base_delay: 2, max_delay: 30)
      retries = 0
      delay = base_delay

      loop do
        begin
          return yield
        rescue Cassandra::Errors::NoHostsAvailable, Cassandra::Errors::IOError => e
          retries += 1
          if retries >= max_retries
            Rails.logger&.error("[Cassandra] Falha após #{max_retries} tentativas: #{e.message}")
            raise
          end
          Rails.logger&.warn("[Cassandra] Tentativa #{retries}/#{max_retries} falhou: #{e.message}. Aguardando #{delay}s...")
          sleep delay
          delay = [delay * 2, max_delay].min
        end
      end
    end
  end
end
