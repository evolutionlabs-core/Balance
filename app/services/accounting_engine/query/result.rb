module AccountingEngine
  module Query
    Result = Data.define(:data, :metadata, :errors) do
      def ok? = errors.empty?
    end
  end
end
