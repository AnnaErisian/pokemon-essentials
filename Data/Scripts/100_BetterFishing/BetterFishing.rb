def fishingPlus()
  speedup = ($Trainer.first_pokemon && [:STICKYHOLD, :SUCTIONCUPS].include?($Trainer.first_pokemon.ability_id))
  pbFishingBegin
  
  viewport=Spriteset_Map.viewport
  
  fishBitmap=Bitmap.new("Graphics/FishingPlus/shape_fish")
  fishSprite=SpriteWrapper.new(viewport)
  fishSprite.bitmap = fishBitmap
  fishSprite.ox = fishBitmap.width / 2
  fishSprite.oy = fishBitmap.height / 2
  fishSprite.x = Graphics.width/2
  fishSprite.y = Graphics.height/2
  fishSprite.visible=true
  fishSprite.z=-20
  
  speed = 5
  
  def canMoveTo(x, y)
    if(x < 0 or x > Settings::SCREEN_WIDTH or y < 0 or y > Settings::SCREEN_HEIGHT)
      return false
    end
    rx = x*1.0/Game_Map::TILE_WIDTH + $game_map.display_x/128
    ry = y*1.0/Game_Map::TILE_WIDTH + $game_map.display_y/128
    return $game_map.terrain_tag(rx, ry).can_fish
  end
  
  loop do
    Graphics.update
    Input.update
    fishSprite.angle = (fishSprite.angle+1) % 360
    if Input.trigger?(Input::USE)
      break
    end
    if Input.press?(Input::UP)
      if canMoveTo(fishSprite.x, fishSprite.y - speed)
        fishSprite.y -= speed
      end
    end
    if Input.press?(Input::DOWN)
      if canMoveTo(fishSprite.x, fishSprite.y + speed)
        fishSprite.y += speed
      end
    end
    if Input.press?(Input::LEFT)
      if canMoveTo(fishSprite.x - speed, fishSprite.y)
        fishSprite.x -= speed
      end
    end
    if Input.press?(Input::RIGHT)
      if canMoveTo(fishSprite.x + speed, fishSprite.y)
        fishSprite.x += speed
      end
    end
  end
  fishSprite.dispose
  
  pbFishingEnd
  return
end