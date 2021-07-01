
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
  def initialize(shape, speed)
    @sprite = SpriteWrapper.new(Spriteset_Map.viewport)
    setSpriteBitmap(shape)
    @sprite.visible=true
    @sprite.z=-20
    
    @speed = speed
    
    @x = Graphics.width/2
    @y = Graphics.height/2
    @angle = 0
  end
  
  def tick()
    @sprite.x = @x
    @sprite.y = @y
    @sprite.angle = @angle
  end
  
  def setSpriteBitmap(shape)
    entityBitmap = Bitmap.new("Graphics/FishingPlus/shape_%s" % shape)
    @sprite.bitmap = entityBitmap
    @sprite.ox = entityBitmap.width / 2
    @sprite.oy = entityBitmap.height / 2
  end
  
  def canMoveTo(x, y)
    if(x < 0 or x > Settings::SCREEN_WIDTH or y < 0 or y > Settings::SCREEN_HEIGHT)
      return false
    end
    rx = x*1.0/Game_Map::TILE_WIDTH + $game_map.display_x/128
    ry = y*1.0/Game_Map::TILE_WIDTH + $game_map.display_y/128
    return $game_map.terrain_tag(rx, ry).can_fish
  end
  
  def tryMove(x, y)
    if canMoveTo(x, y)
      @x = x
      @y = y
    end
  end
  
  def die()
    @sprite.dispose()
  end
end

class FP_Fish < FP_Entity

  def initialize(shape, speed, species, level)
    super(shape, speed)
    @species = species
    @level = level
  end
  
  def tick()
    ai()
    super()
  end
  
  def ai()
    @angle = (@angle+@speed/2.5) % 360
    tryMove(@sprite.x + @speed * (rand-0.5), @sprite.y + @speed * (rand-0.5))
  end
end

class FP_Bobber < FP_Entity
  
  @@CURSOR = 0
  @@BOBBER = 1
  @@CATCHING = 2
  
  @@ACCELERATION = 0.5
  @@DRAG = 0.9
  
  def initialize(shape, speed)
    super(shape, speed)
    @state = @@CURSOR
    @velocity_x = 0
    @velocity_y = 0
    @angle = 0
    @maxSpeed = @speed * @speed
  end
  
  def tick()
  
    #Apply drag
    @velocity_x *= @@DRAG
    @velocity_y *= @@DRAG
    if @velocity_x.abs() < 0.05
      @velocity_x = 0
    end
    if @velocity_y.abs() < 0.05
      @velocity_y = 0
    end
  
    if Input.press?(Input::UP)
      @velocity_y -= @@ACCELERATION
    end
    if Input.press?(Input::DOWN)
      @velocity_y += @@ACCELERATION
    end
    if Input.press?(Input::LEFT)
      @velocity_x -= @@ACCELERATION
    end
    if Input.press?(Input::RIGHT)
      @velocity_x += @@ACCELERATION
    end
    
    #Limit to @speed
    vsquared = @velocity_y * @velocity_y + @velocity_x * @velocity_x
    if (vsquared) > @maxSpeed
      @velocity_x *= @maxSpeed / vsquared
      @velocity_y *= @maxSpeed / vsquared
    end
    
    #Move
    tryMove(@x + @velocity_x, @y + @velocity_y)
    
    ##update position for real
    super()
    
    if Input.trigger?(Input::USE)
      if @state == @@CURSOR
        setSpriteBitmap("bobber")
        @state = @@BOBBER
        pbFishingBegin
      elsif @state == @@BOBBER
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