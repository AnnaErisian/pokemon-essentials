class Vector

  attr_accessor :x
  attr_accessor :y
  
  def initialize(x, y)
    @x = x
    @y = y
  end
  
  def +(b)
    return Vector.new(@x+b.x,@y+b.y)
  end
  
  def -(b)
    return Vector.new(@x-b.x,@y-b.y)
  end
  
  def *(b)
    return Vector.new(@x*b,@y*b)
  end
  
  def /(b)
    return Vector.new(@x/b,@y/b)
  end
  
  def normalize 
    r = magnitude
    return Vector.new(0,0) if r == 0
    return self/r
  end
  
  def normalize!
    r = Math.sqrt(@x*@x+@y*@y)
    return if r == 0
    @x /= r
    @y /= r
  end
  
  def unit
    return normalize
  end
  
  def unit!
    return normalize!
  end
  
  def magnitude
    return Math.sqrt(magnitude2)
  end
  
  def mag
    return magnitude
  end
  
  def length
    return magnitude
  end
  
  def magnitude2
    return @x*@x+@y*@y
  end
  
  def mag2
    return magnitude2
  end
  
  def length2
    return magnitude2
  end
  
  def angleR
    return Math.atan2(@y, @x)
  end
  
end