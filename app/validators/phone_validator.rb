class PhoneValidator < ActiveModel::EachValidator
  ALLOWED = /\A\+?[\d\s().-]+\z/
  DIGITS = 7..15

  def validate_each(record, attribute, value)
    return if value.blank?

    if !value.match?(ALLOWED)
      record.errors.add(attribute, "can only contain numbers, spaces, +, - and brackets")
    elsif !DIGITS.cover?(value.count("0-9"))
      record.errors.add(attribute, "should have between #{DIGITS.min} and #{DIGITS.max} digits")
    end
  end
end
