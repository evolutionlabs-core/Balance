module Invoices
  module Discount
    extend ActiveSupport::Concern

    TYPES = %w[percent amount].freeze

    included do
      validates :discount_type, inclusion: { in: TYPES }, allow_nil: true
      validates :discount_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
      validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: -> { discount_type == "percent" }, allow_nil: true
      validate :discount_below_subtotal
    end

    def discounted?
      discount_minor.positive?
    end

    def discount_label
      discount_type == "percent" ? "Discount (#{discount_value.to_s("F").delete_suffix(".0")}%)" : "Discount"
    end

    private
      def calculate_discount
        self.discount_type = nil if discount_value.blank? || discount_value.zero?
        self.discount_value = nil if discount_type.nil?

        self.discount_minor = case discount_type
        when "percent" then (subtotal_minor * discount_value / 100).round
        when "amount" then (discount_value * 100).round
        else 0
        end
      end

      def discount_below_subtotal
        return unless discounted? && discount_minor >= subtotal_minor

        errors.add(:discount_value, "must be less than the subtotal")
      end

      def discounted_income_lines(lines)
        return lines unless discounted?

        remaining = discount_minor
        shares = lines.map do |line|
          share = subtotal_minor.zero? ? 0 : (discount_minor * line[:amount_kobo] / subtotal_minor.to_r).floor
          remaining -= share
          share
        end
        shares[lines.index(lines.max_by { |line| line[:amount_kobo] })] += remaining

        lines.zip(shares).map { |line, share| line.merge(amount_kobo: line[:amount_kobo] - share) }
          .reject { |line| line[:amount_kobo].zero? }
      end
  end
end
