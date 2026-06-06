module Cassandra
  class Uuid
    def as_json(*)
      to_s
    end
  end
end
