# frozen_string_literal: true

require "cassandra"
require "sorted_set"

module CassandraClient
  class << self
    def session
      @session ||= cluster.connect(keyspace)
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
