module Math
  def self.abs(number)
    if number<0 then return -1*number end
    return number
  end
  
  def self.max(a, b)
    return [a,b].max
  end
  
  def self.min(a, b)
    return [a,b].min
  end
  
  def self.clamp(min, b, max)
    return [[min,b].max, max].min
  end
end
