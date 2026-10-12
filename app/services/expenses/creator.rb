class Expenses::Creator
  Result = Data.define(:expense, :posted) do
    def success? = posted
  end

  def self.call(workspace:, attributes:)
    new(workspace, attributes).call
  end

  def initialize(workspace, attributes)
    @workspace = workspace
    @attributes = attributes
  end

  def call
    expense = @workspace.expenses.build(@attributes)
    messages = []

    posted = Expense.transaction do
      unless expense.save
        messages.concat(expense.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      receipt = post_to_engine(expense)

      if receipt.success? && receipt.verdict == :allow
        expense.mark_posted!
        true
      else
        messages.concat(receipt.errors.map(&:to_s))
        messages << "This expense requires approval before it can be posted." if receipt.verdict == :pause
        raise ActiveRecord::Rollback
      end
    end

    if posted
      Result.new(expense, true)
    else
      draft = @workspace.expenses.build(@attributes)
      messages.each { |message| draft.errors.add(:base, message) }
      Result.new(draft, false)
    end
  end

  private
    attr_reader :workspace, :attributes

    def post_to_engine(expense)
      command = Engine::Adapters::Expense.call(
        workspace: @workspace,
        attributes: @attributes,
        source_id: expense.id,
        description: expense.description
      )
      Engine.post(command)
    rescue ActiveRecord::RecordNotFound => error
      Engine::Receipt.new(nil, [ error.message ].freeze, :reject, [].freeze)
    end
end
