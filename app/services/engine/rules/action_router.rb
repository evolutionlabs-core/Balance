module Engine
  module Rules
    class ActionRouter
      def self.call(command, scoped_rules)
        verdict = :allow
        current = command

        scoped_rules.each do |rule|
          next unless ConditionEvaluator.matches?(rule, current)

          case rule.severity
          when "block"
            raise Engine::Errors::BusinessRuleError.new(rule: rule, warnings: warnings_of(current))
          when "require_approval"
            verdict = :pause
          when "warn"
            current = append_warning(current, rule.message)
          else
            raise ArgumentError, "Unknown severity #{rule.severity.inspect} in rule #{rule.id}"
          end
        end

        Result.new(verdict, current)
      end

      class << self
        private
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
