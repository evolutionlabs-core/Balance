module Engine
  module Query
    def self.call(_spec)
      { status: "error", code: "NOT_IMPLEMENTED", http_status: 501,
        message: "read path not implemented yet", errors: [], details: {},
        timestamp: Time.current.iso8601 }
    end
  end
end
