module AccountingEngine
  module Rules
    class ActionRouter
      def self.call(command, scoped_rules)
        scoped_rules.reduce(command) do |current, rule|
          if ConditionEvaluator.matches?(rule, current)
            apply(rule, current)
          else
            current
          end
        end
      end

      class << self
        private
          def apply(rule, command)
            case rule.severity
            when "block"
              raise AccountingEngine::Errors::BusinessRuleError.new(rule: rule, warnings: warnings_of(command))
            when "warn"
              append_warning(command, rule.message)
            else
              raise ArgumentError, "Unknown severity #{rule.severity.inspect} in rule #{rule.id}"
            end
          end

          def warnings_of(command)
            command.metadata.fetch("warnings", [])
          end

          def append_warning(command, message)
            command.with(metadata: command.metadata.merge("warnings" => warnings_of(command) + [ message ]))
          end
      end
    end
  end
end
