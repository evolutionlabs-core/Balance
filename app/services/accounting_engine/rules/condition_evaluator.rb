class AccountingEngine::Rules::ConditionEvaluator
  OPERATORS = %w[eq ne gt gte lt lte in].freeze

  def self.matches?(rule, command)
    new(rule, command).matches?
  end

  def initialize(rule, command)
    @rule = rule
    @command = command
  end

  def matches?
    Array(rule.conditions).all? { |condition| satisfied?(condition) }
  end

  private
    attr_reader :rule, :command

    def satisfied?(condition)
      raise ArgumentError, "Malformed condition in rule #{rule.id}" unless condition.is_a?(Hash)

      normalized = condition.transform_keys(&:to_s)
      field = normalized.fetch("field")
      op = normalized.fetch("op")
      raise ArgumentError, "Unknown operator #{op.inspect} in rule #{rule.id}" unless OPERATORS.include?(op)

      compare(op, resolve(field), normalized["value"])
    end

    def resolve(field)
      head, *rest = field.to_s.split(".")

      if head == "metadata"
        rest.reduce(command.metadata) { |hash, key| hash.is_a?(Hash) ? hash[key] : nil }
      elsif rest.empty? && top_level_field?(head)
        top_level_value(head)
      else
        raise ArgumentError, "Unknown field #{field.inspect} in rule #{rule.id}"
      end
    end

    def top_level_field?(head)
      %w[total_debits total_credits source_type source_id action ledger_id].include?(head)
    end

    def top_level_value(head)
      case head
      when "total_debits" then command.lines.sum(&:debit)
      when "total_credits" then command.lines.sum(&:credit)
      when "source_type" then command.source_type
      when "source_id" then command.source_id
      when "action" then command.action
      when "ledger_id" then command.ledger&.id
      end
    end

    def compare(op, actual, expected)
      case op
      when "eq" then actual == expected
      when "ne" then actual != expected
      when "in" then Array(expected).include?(actual)
      when "gt", "gte", "lt", "lte"
        return false unless actual.is_a?(Numeric) && expected.is_a?(Numeric)

        actual.public_send({ "gt" => :>, "gte" => :>=, "lt" => :<, "lte" => :<= }[op], expected)
      end
    end
end
