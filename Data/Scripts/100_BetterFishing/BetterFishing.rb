
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

  def initialize(shape, speed, species, level)
    super(shape, speed)
    @species = species
    @level = level
    
    initKinematics()
    initAi()
  end
  
  def tick()
    ai()
    kinematics()
    super()
  end
    
  @@DRAG = 0.95
  @@ANGLE_DRAG = 0.95
  
  def initKinematics()
    @velocity = Vector.new(0.0, 0.0)
    @v_angle = 0.0
    @could_move = true
  end
  
  def initAi()
    @target_pos = nil
    @target_angle = 0
    @bobber = nil
  end
  
  def kinematics()
    #update position
    @angle = (@angle+@v_angle) % 360
    @could_move = tryMoveV(@position + @velocity)
    
    #apply drag
    @v_angle *= @@ANGLE_DRAG
    @velocity *= if @velocity.mag > 0.01 then @@DRAG else 0 end
  end
  
  def ai()
    #pick a target position if we don't have one
    if !@bobber.nil? && @bobber.state == FP_Bobber::BOBBER
      @target_pos = @bobber.position
    else
      randomSeek()
    end
    #move towards target point
    if @target_pos != nil
      #echoln("Current Position: #{@position.x.round(3)}, #{@position.y.round(3)}")
      #echoln("Target Position:  #{@target_pos.x.round(3)}, #{@target_pos.y.round(3)}")
      target_v = @target_pos - @position
      target_v.normalize!
      target_v *= @speed
      #echoln("Target Velocity: #{target_v.x.round(3)}, #{target_v.y.round(3)}")
      steering_dir = target_v - @velocity
      steering_dir.normalize!
      #echoln("Steering Vector: #{steering_dir.x.round(3)}, #{steering_dir.y.round(3)}")
      @velocity += steering_dir * @speed / 30.0
      #echoln("Velocity: #{@velocity.x.round(3)}, #{@velocity.y.round(3)}")
    end
    #just make angle match current velocity
    if @velocity.mag != 0
      target_angle = 360 - ((@velocity.angleR + Math::PI) * 360 / (2*Math::PI))
      diff = Math.abs(@angle-target_angle)
      angle_accel = 0
      if Math.abs(diff) > 10
        if(diff < 180)
          angle_accel = if target_angle > @angle then 1 else -1 end
        else
          angle_accel = if target_angle > @angle then -1 else 1 end
        end
      end
      @v_angle += angle_accel
      
    end
    #if we're super near the target, drop the target
    if @target_pos != nil
      if (@target_pos - @position).mag < 10
        @target_pos = nil
      end
    end
  end
  
  def randomSeek()
    if !@could_move || @target_pos == nil
      if rand(100) < 5
        @target_pos = @position + Vector.new(rand(100)-rand(100), rand(100)-rand(100))
      end
    end
  end
end

class FP_Bobber < FP_Entity
  
  CURSOR = 0
  BOBBER = 1
  CATCHING = 2
  
  attr_reader :state
  
  @@ACCELERATION = 0.4
  @@DRAG = 0.93
  
  def initialize(shape, speed)
    super(shape, speed)
    @state = CURSOR
    @velocity = Vector.new(0, 0)
    @angle = 0
    @maxSpeed2 = @speed * @speed
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
  end
    
  loop do
    Graphics.update
    Input.update
    fish.each do |f|
      f.tick()
    end
    if bobber.tick()
      break # for now, just end it on second A press
    end
  end
  
  fish.each {|f| f.die()}
  bobber.die()
  
  #Sprite stuff cleanup
  pbFishingEnd
  $game_player.setDefaultCharName(nil,oldpattern)
  
  return
end