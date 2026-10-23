class EmailValidator < ActiveModel::EachValidator
  FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  def validate_each(record, attribute, value)
    return if value.blank? || value.match?(FORMAT)

    record.errors.add(attribute, "isn't a valid email address")
  end
end
