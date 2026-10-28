module PhoneNumbers
  module_function

  def normalize(value)
    digits = value.to_s.gsub(/\D/, "")
    digits.sub(/\A00/, "")
  end

  def valid?(value)
    normalize(value).length.between?(8, 15)
  end
end
