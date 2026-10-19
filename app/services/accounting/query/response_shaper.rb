module Accounting
  module Query
    class ResponseShaper
      def self.call(result)
        return { status: "error", errors: result.errors } unless result.ok?

        { status: "success", data: result.data, metadata: result.metadata }
      end
    end
  end
end
