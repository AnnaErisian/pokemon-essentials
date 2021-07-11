
GameData::EncounterType.register({
  :id => :ProgressPole,
  :type => :fishing,
  :old_slots => [100]
})
GameData::EncounterType.register({
  :id => :BambooRod,
  :type => :fishing,
  :old_slots => [100]
})
GameData::EncounterType.register({
  :id => :HorizonStar,
  :type => :fishing,
  :old_slots => [100]
})
GameData::EncounterType.register({
  :id => :AquaRuler,
  :type => :fishing,
  :old_slots => [100]
})

class FP_Entity

  attr_accessor :position
  attr_accessor :angle
  attr_accessor :sprite

  def initialize(shape, speed)
    @sprite = SpriteWrapper.new(Spriteset_Map.viewport)
    setSpriteBitmap(shape)
    @sprite.visible=true
    @sprite.z=-20
    
    @speed = speed
    
    @position = Vector.new(Graphics.width/2, Graphics.height/2)
    @angle = 0
  end
  
  def tick()
    @sprite.x = @position.x
    @sprite.y = @position.y
    @sprite.angle = @angle
  end
  
  def setSpriteBitmap(shape)
    entityBitmap = Bitmap.new("Graphics/FishingPlus/shape_%s" % shape)
    @sprite.bitmap = entityBitmap
    @sprite.ox = entityBitmap.width / 2
    @sprite.oy = entityBitmap.height / 2
  end
  
  def canMoveToV(v)
    return canMoveTo(v.x, v.y)
  end
  
  def canMoveTo(x, y)
    if(x < 0 or x > Settings::SCREEN_WIDTH or y < 0 or y > Settings::SCREEN_HEIGHT)
      return false
    end
    rx = x*1.0/Game_Map::TILE_WIDTH + $game_map.display_x/128
    ry = y*1.0/Game_Map::TILE_WIDTH + $game_map.display_y/128
    return $game_map.terrain_tag(rx, ry).can_fish
  end
  
  def tryMoveV(v)
    return tryMove(v.x, v.y)
  end
  
  def tryMove(x, y)
    if canMoveTo(x, y)
      @position.x = x
      @position.y = y
      return true
    end
    return false
  end
  
  def die()
    @sprite.dispose()
  end
end

class FP_Fish < FP_Entity

  attr_writer :bobber
  attr_reader :hooked
  attr_accessor :watchingBobber
  attr_accessor :interest

  def initialize(shape, speed, species, level)
    super(shape, speed)
    @species = species
    @level = level
    @hooked = false
    
    initKinematics()
    initAi()
    
    case shape
      #Fish and Spinies
      when "fish"
        @angleAdjustor = FP_Angle_Adjustors::Oscillate.new(5)
      when "spiny"
        @angleAdjustor = FP_Angle_Adjustors::Oscillate.new(7)
      #Blobs
      when "blob"
        @angleAdjustor = FP_Angle_Adjustors::RandomSlow.new()
      #Snakes, Others
      else
        @angleAdjustor = FP_Angle_Adjustors::NoOp.new()
    end
  end
  
  def tick()
    ai()
    kinematics()
    #testHUD()
    super()
    angleAdjust()
  end
  
  def angleAdjust()
    @angleAdjustor.adjust(@sprite, @velocity)
  end
  
  @@ANGLE_FORCE_MAX = 1
  @@ANGLE_SPEED_MAX = 4
  
  @@ACCEL_MAX = 5.0
  @@CAUTION_SPEED_MAX = 0.5
  
  @@DRAG = 0.95
  @@ANGLE_DRAG = 0.98
  
  def initKinematics()
    @velocity = Vector.new(0.0, 0.0)
    @v_angle = 0.0
    @could_move = true
    @reach_scale = 10
  end
  
  def initAi()
    @other_fish = []
    @target_pos = nil
    @target_time = -1
    @target_angle = 0
    @bobber = nil
    @sightRange = 30
    @watchingBobber = false
    @interest = 0
    @interestGrowth = 10.1
    @interestDecay = 0.1
    @interestDecayFear = 1.5
    @bobberVelLimit = 0.3
    @bobberWary = 0
    @bobberWaryGrowth = 0.2
    @bobberWaryDecay = 0.05
    @caution = false
    @bobberSeekSpreadTimer = 0
    @seekingBobber = false
    @stun = 0
  end
  
  def testHUD()
    if @HUDSprite == nil
      @HUDBitmap = Bitmap.new(150, 150)
      @HUDSprite = SpriteWrapper.new(Spriteset_Map.viewport)
      @HUDSprite.visible=true
      @HUDSprite.bitmap=@HUDBitmap
      @HUDSprite.z=-19
    end
    @HUDBitmap.clear()
    @HUDBitmap.draw_text(0, 0, 150, 5, "Interest: %d" % [@interest])
    @HUDBitmap.draw_text(0, 10, 150, 5, "Wary: %d" % [@bobberWary])
    @HUDBitmap.draw_text(0, 20, 150, 5, "Watching: %s" % [@watchingBobber])
    @HUDBitmap.draw_text(0, 30, 150, 5, "T Time: %d" % [@target_time])
    @HUDSprite.x = @position.x
    @HUDSprite.y = @position.y
  end
  
  def setOtherFish(others)
    others.each do |o|
      @other_fish << o if o != self
    end
    echoln(@other_fish.length)
  end
  
  def kinematics()
    #update position
    @angle = (@angle+@v_angle) % 360
    @could_move = tryMoveV(@position + @velocity)
    if !@could_move
      @could_move = tryMove(@position.x + @velocity.x, @position.y)
    end
    if !@could_move
      @could_move = tryMove(@position.x, @position.y + @velocity.y)
    end
    
    #apply drag
    @v_angle *= if Math.abs(@v_angle) > 0.02 then @@ANGLE_DRAG else 0 end
    @v_angle = Math.clamp(-@@ANGLE_SPEED_MAX, @v_angle, @@ANGLE_SPEED_MAX)
    @velocity *= if @velocity.mag > 0.01 then @@DRAG else 0 end
  end
  
  def ai()
    aiTargeting()
#		Move towards target
    angularSteering()
    @target_time -= 1 if @target_time >= 0
    @stun -= 1 if @stun > 0
    setTarget(nil) if @target_time == 0
    if @target_pos != nil
      if @target_pos.distance(@position) < @reach_scale
#   		If target reached
# 			clear target
        if @interest > 99999999999 && @seekingBobber
# 			  if interest >99 and it's the bobber, bite!
          @hooked = true
        elsif  @interest > 25 && @seekingBobber
# 			  if interest >25 and it's the bobber, bounce and ripple
          if @target_pos.distance(@bobber.position) < 5
            angleR = (@angle-90)*2*Math::PI/360.0
            @velocity += Vector.new(-3*Math.sin(angleR), -3*Math.cos(angleR))
            @stun = 60
            @bobber.fishTap
          end
        end
        setTarget(nil)
        @target_time = -1
        @caution = false
      end
    end
  end
  
  def aiTargeting()
    bobberDist = @bobber.nil? ? 10000 : @bobber.position.distance(@position)
    if !@bobber.nil? && @bobber.state == FP_Bobber::BOBBER && (bobberDist < @sightRange || (@watchingBobber && bobberDist < 3*@sightRange))
      @watchingBobber = true
#     Check if there's another fish also interested.  If they're more interested, fuck off
      if @target_pos == nil
        otherInterested = @other_fish.find {|i| i.watchingBobber}
        if !otherInterested.nil? && otherInterested.interest >= @interest
          @watchingBobber = false
          randomSeek(40, 60, 100)
          return
        end
      end
#     If the bobber is near
#     their 'interest' (0-100, at 100 they go for a bite) grows 1/2frames
      @interest += @interestGrowth
#	    If the bobber is moving
      if @bobber.velocity.mag > @bobberVelLimit
#	  	  Increment bobber wary counter
        @bobberWary += @bobberWaryGrowth
        if @bobberWary < 20
#				  If the counter is < 1 second, grant +interest
          @interest += @interestGrowth
        else
#				  Else reduce interest by 5% of current, then by 3
          @interest *= 0.95
          @interest = Math.max(0, @interest - 6 * @interestDecay)
        end
      else
#    		Else reduce the counter by 2, min 0
        @bobberWary = Math.max(0, @bobberWary - @bobberWaryDecay)
      end
      @bobberSeekSpreadTimer = Math.max(0, @bobberSeekSpreadTimer-1)
      if @interest > 25
        if rand(100) < 2 && @bobberSeekSpreadTimer < 1
#   			If interest >25, target bobber and apply caution
          setTarget(@bobber.position)
          @seekingBobber = true
          @target_time = 240
          @bobberSeekSpreadTimer = 300
          @caution = true
        else
          if @target_pos.nil?
            randomSeek(20, 30)
          end
        end
      elsif @interest <= 0
#   	  If interest <0, target away from bobber, or totally random if that fails
        @caution = false
        flee_center = @position - (@bobber.position - @position).normalize * 50
        seekScale = 30
        r1 = rand(2*seekScale) - seekScale
        r2 = rand(2*seekScale) - seekScale
        flee_center += Vector.new(r1,r2)
        if canMoveToV(flee_center)
          setTarget(flee_center)
          return
        else
        randomSeek()
        end
      else
        if @target_pos == nil
          randomSeek()
        end
      end
    else    
      @watchingBobber = false
      @interest = Math.max(0, @interest - @interestDecay)
      @bobberWary = Math.max(0, @bobberWary - 4*@bobberWaryGrowth)
      @caution = false
#		  Else if no target and 4% chance, target random water tile
      if @target_pos == nil
        randomSeek()
      end
    end
  end
  
  #steering that adjust our angle and moves forward
  def angularSteering
    if @target_pos != nil
      #move our angle towards the right direction
      target_angle = 360 - (((@target_pos - @position).angleR + Math::PI) * 360 / (2*Math::PI))
      diff = Math.abs(@angle-target_angle)
      target_angle_v = 0
      if Math.abs(diff) > 10
        if(diff < 180)
          target_angle_v = if target_angle > @angle then @@ANGLE_SPEED_MAX else -@@ANGLE_SPEED_MAX end
        else
          target_angle_v = if target_angle > @angle then -@@ANGLE_SPEED_MAX else @@ANGLE_SPEED_MAX end
        end
      end
      if (Math.abs(diff) < 30)
        target_angle_v *= Math.abs(diff) / 45.0
      end
      steering_v = Math.clamp(-@@ANGLE_FORCE_MAX, target_angle_v - @v_angle, @@ANGLE_FORCE_MAX)
      @v_angle += steering_v
      
      #move forward, but arrive
      angleR = (@angle-90)*2*Math::PI/360.0
      target_v = Vector.new(Math.sin(angleR), Math.cos(angleR))
      distance_to_target = @target_pos.distance(@position)
      if(distance_to_target > 70)
        target_v *= @speed / 2.0
      else
        target_v *= @speed / 2.0 * distance_to_target / 70
      end
      if @caution && target_v.mag > @@CAUTION_SPEED_MAX
        target_v = target_v.normalize * @@CAUTION_SPEED_MAX
      end
      steering_dir = target_v - @velocity
      if steering_dir.mag > @@ACCEL_MAX
        steering_dir = steering_dir.normalize * @@ACCEL_MAX
      end
      @velocity += steering_dir
    else
      #if we have no target, brakes on top of drag
      @v_angle *= 0.9
      @velocity *= 0.9
    end
  end
  
  #Can probably use this for spinies and blobs.  Keeping around for now.
  def pureSteering
    if @target_pos != nil
      #echoln("Current Position: #{@position.x.round(3)}, #{@position.y.round(3)}")
      #echoln("Target Position:  #{@target_pos.x.round(3)}, #{@target_pos.y.round(3)}")
      target_v = @target_pos - @position
      target_v.normalize!
      distance_to_target = @target_pos.distance(@position)
      if(distance_to_target > 70)
        target_v *= @speed / 2.0
      else
        target_v *= @speed / 2.0 * distance_to_target / 70
      end
      #echoln("Target Velocity: #{target_v.x.round(3)}, #{target_v.y.round(3)}")
      steering_dir = target_v - @velocity
      #force forward motion at all times
      angleR = (@angle-90)*2*Math::PI/360.0
      steering_dir += Vector.new(Math.sin(angleR), Math.cos(angleR)) * steering_dir.mag / 4
      #echoln("Steering Vector: #{steering_dir.x.round(3)}, #{steering_dir.y.round(3)}")
      @velocity += steering_dir
      #echoln("Velocity: #{@velocity.x.round(3)}, #{@velocity.y.round(3)}")
    else
      #if we have no target, brakes on top of drag
      @velocity *= 0.9
    end
    #just make angle match current velocity
    if @velocity.mag != 0
      target_angle = 360 - ((@velocity.angleR + Math::PI) * 360 / (2*Math::PI))
      diff = Math.abs(@angle-target_angle)
      target_angle_v = 0
      if Math.abs(diff) > 10
        if(diff < 180)
          target_angle_v = if target_angle > @angle then 1 else -1 end
        else
          target_angle_v = if target_angle > @angle then -1 else 1 end
        end
      end
      if (Math.abs(diff) < 30)
        target_angle_v *= Math.abs(diff) / 30.0
      end
      steering_dir_v = target_angle_v - @v_angle
      steering_dir_v /= Math.abs(steering_dir_v) if steering_dir_v != 0
      @v_angle += steering_dir_v
      
    end
  end
  
  def randomSeek(seekScale = 40, forwardScale = 60, chance = 3)
    if !@could_move || @target_pos == nil
      if rand(100) < chance
        #candidate = @position + Vector.new(rand(100)-rand(100), rand(100)-rand(100))
        angleR = (@angle-90)*2*Math::PI/360.0
        r1 = rand(2*seekScale) - seekScale
        r2 = rand(2*seekScale) - seekScale
        #try something in front-ish
        candidate = @position + Vector.new(r1 + forwardScale*Math.sin(angleR), r2 + forwardScale*Math.cos(angleR))
        if canMoveToV(candidate)
          setTarget(candidate)
          return
        else
          #back-ish?
          candidate = candidate = @position + Vector.new(r1 - forwardScale*Math.sin(angleR), r2 - forwardScale*Math.cos(angleR))
        end
        if canMoveToV(candidate)
          setTarget(candidate)
          return
        else
          #totally random
          candidate = candidate = @position + Vector.new(r1*3, r2*3)
        end
        if canMoveToV(candidate)
          setTarget(candidate)
          return
        end
      end
    end
  end
  
  def setTarget(pos)
    if(@stun <= 0 || pos.nil?)
      @target_pos = pos
      @seekingBobber = false
      @target_time = -1
    end
  end
end

class FP_Bobber < FP_Entity
  
  CURSOR = 0
  BOBBER = 1
  CATCHING = 2
  
  attr_reader :state
  attr_reader :velocity
  
  @@ACCELERATION = 0.4
  @@DRAG = 0.8
  
  def initialize(shape, speed)
    super(shape, speed)
    @state = CURSOR
    @velocity = Vector.new(0, 0)
    @angle = 0
    @maxSpeed2 = @speed * @speed
    @fish = nil
    @tapTime = 40
    @@dipAnimBitmap = Bitmap.new("Graphics/FishingPlus/bobber_animation")
  end
  
  def tick()
    #Apply drag
    @velocity *= @@DRAG
    if @velocity.mag2 < 0.03
      @velocity *= 0
    end
  
    if Input.press?(Input::UP)
      @velocity.y -= @@ACCELERATION
    end
    if Input.press?(Input::DOWN)
      @velocity.y += @@ACCELERATION
    end
    if Input.press?(Input::LEFT)
      @velocity.x -= @@ACCELERATION
    end
    if Input.press?(Input::RIGHT)
      @velocity.x += @@ACCELERATION
    end
    
    #Limit to @speed
    if (@velocity.mag2) > @maxSpeed2
      @velocity *= @maxSpeed2 / @velocity.mag2
    end
    
    #Move, bounce if we can't
    if !tryMoveV(@position + @velocity)
      if !tryMove(@position.x + @velocity.x, @position.y)
        @velocity.x *= -1
      end
      if !tryMove(@position.x, @position.y + @velocity.y)
        @velocity.y *= -1
      end
    end
    
    #update everything for tapping
    if @tapTime < 40
      @sprite.bitmap.clear()
      @sprite.bitmap.blt(0, 0, @@dipAnimBitmap, Rect.new(@tapTime/2 * 16, 0, 16, 16))
      @tapTime += 1
    end
    
    ##update position for real
    super()
    
    if Input.trigger?(Input::USE)
      if @state == CURSOR
        setSpriteBitmap("bobber")
        @state = BOBBER
        pbFishingBegin
      elsif @state == BOBBER
        return true
      end
    end
    
    return false
  end
  
  def setFish(fish)
    @fish = fish
  end
  
  def hasFish()
    return !@fish.nil?
  end
  
  def fishTap()
    @tapTime = 0
    pbSEPlay("Voltorb Flip explosion") #TODO get a better dip sound lol
  end
  
end

module FP_Angle_Adjustors
  class NoOp
    def initialize()
    end
    def adjust(sprite, velocity)
    end
  end
  class RandomSlow < NoOp
    def initialize()
      @adjustment = 0
      @vel = 0
    end
    def adjust(sprite, velocity)
      @vel += (rand()-0.5)
      @vel *= 0.85
      if Math.abs(@vel) > 3
        @vel = 3 * @vel / Math.abs(@vel)
      end
      @adjustment += @vel
      sprite.angle += @adjustment
    end
  end
  class Oscillate < NoOp
    def initialize(speed)
      @time = 0
      @speed = speed * 0.05
    end
    def adjust(sprite, velocity)
      @time += @speed * velocity.mag
      sprite.angle += Math.sin(@time) * 15
    end
  end
end

module FishingPlus
  class << self
    attr_accessor :currentLure
  end

  def self.generateFish(encounterRod, lure)
    $PokemonTemp.encounterType = encounterRod
    encounter1 = $PokemonEncounters.choose_wild_pokemon(encounterRod)
    encounter1 = EncounterModifier.trigger(encounter1)
    species = encounter1[0]
    level = encounter1[1]
    shape = getShape(species)
    speed = getSpeed(species, level)
    echoln "Added a level #{level} #{species}, as a speed #{speed} #{shape}"
    return FP_Fish.new(shape, speed, species, level)
  end
  
  def self.getShape(species)
    return case species
      #SNAKES
      when :GYARADOS
        "snake"
      #SPINIES
      when :KRABBY, :CORSOLA, :SHELLDER
        "spiny"
      #BLOBS
      when :CLAMPERL, :CHINCHOU, :WAILMER
        "blob"
      else
        "fish" 
    end
  end
  
  def self.getSpeed(species, level)
    return case species
      when :KRABBY, :GYARADOS
        8
      when :CORSOLA, :SHELLDER, :CLAMPERL
        3
      else
        5
    end
  end
end

def fishingPlus(fishCount)
  speedup = ($Trainer.first_pokemon && [:STICKYHOLD, :SUCTIONCUPS].include?($Trainer.first_pokemon.ability_id))
  
  #Sprite stuff
  oldpattern = $game_player.fullPattern
  
  #Pick rod (or cancel)
  rod = pbChooseItemFromList(_INTL("Hmmm... Which fishing pole should I use?"), 1, :PROGRESSPOLE, :BAMBOOROD, :HORIZONSTAR, :AQUARULER)
  if rod == -1
    pbMessage(_INTL("No rod, no fishing."))
    return
  end
  encounterRod = case rod
    when :PROGRESSPOLE then :ProgressPole
    when :BAMBOOROD then :BambooRod
    when :HORIZONSTAR then :HorizonStar
    when :AQUARULER then :AquaRuler
  end
  
  #Pick lure (or cancel)
  lure = pbChooseItemFromList(_INTL("Alright, then which lure should I use?"),1, :LUREPOKE, :LUREGREAT, :LUREULTRA, :LUREMASTER, :LURECRYSTAL, :LUREANCHOR, :LURESTATIC, :LUREINFUSE, :LURECAMO)
  if lure == -1
    pbMessage(_INTL("No lure, no fishing."))
    return
  end
  FishingPlus.currentLure = lure
  #TODO implement the effects of these things
  
  fish = []
  
  hasEncounter = $PokemonEncounters.has_encounter_type?(encounterRod)
  if hasEncounter
    fishCount.times do
      fish << FishingPlus.generateFish(encounterRod, lure)
    end
  else
    fish << FP_Fish.new("fish", 5, :MAGIKARP, 5)
  end
  
  bobber = FP_Bobber.new("cursor", 5000)
  
  fish.each do |f|
    f.bobber = bobber
    f.setOtherFish(fish)
    f.angle = rand(360)
    f.randomSeek(40,60,100)
  end
    
  loop do
    Graphics.update
    Input.update
    bobber.tick()
    fish.each do |f|
      f.tick()
      if f.hooked
        bobber.setFish(f)
      end
    end
    if bobber.hasFish
      break
    end
  end
  
  #remove all the fish
  fish.each {|f| f.die()}

  catchResult = 0

  loop do
    Graphics.update
    Input.update
    catchResult = bobber.tick()
    if catchResult
      break
    end
  end
  
  #TODO handle catch result
  
  bobber.die()
  
  #Sprite stuff cleanup
  pbFishingEnd
  $game_player.setDefaultCharName(nil,oldpattern)
  
  return
end