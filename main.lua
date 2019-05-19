-- Cette ligne permet d'afficher des traces dans la console pendant l'éxécution
io.stdout:setvbuf('no')

-- Empèche Love de filtrer les contours des images quand elles sont redimentionnées
-- Indispensable pour du pixel art
love.graphics.setDefaultFilter("nearest")

-- Cette ligne permet de déboguer pas à pas dans ZeroBraneStudio
if arg[#arg] == "-debug" then require("mobdebug").start() end

-- Calcul d'un angle entre 2 coordonnées
function math.angle(x1,y1, x2,y2) return math.atan2(y2-y1, x2-x1) end

-- Distance entre 2 coordonnées
function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end

-- Collision simple AABB
function CheckCollision(x1,y1,w1,h1,x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

-- Toutes les entités sprites
local lstSprites = {}
local lstBlood = {}
local imgBlood = love.graphics.newImage("images/blood.png")

-- L'humain
local theHuman = {}

-- Aide de jeu
local imgAlert = love.graphics.newImage("images/alert.png")
local bDebug = false

-- Les états de l'IA des zombies
local ZS = require("zombie_states")

function CreateSprite(pLst, psType, psImageFile, pnFrames)
  mySprite = {}
  mySprite.type = psType
  mySprite.x = 0
  mySprite.y = 0
  mySprite.vx = 0
  mySprite.vy = 0
  mySprite.visible = true
  -- Chargement des frames du sprite
  mySprite.images = {}
  mySprite.currentFrame = 1
  local i
  for i=1,pnFrames do
    mySprite.images[i] = love.graphics.newImage("images/"..psImageFile..tostring(i)..".png")
  end
  mySprite.width = mySprite.images[1]:getWidth()
  mySprite.height = mySprite.images[1]:getHeight()
  table.insert(pLst, mySprite)
  return mySprite
end

function CreateZombie()
  myZombie = CreateSprite(lstSprites, "zombie", "monster_", 2)  
  myZombie.x = math.random(10,screenWidth-10)
  myZombie.y = math.random(10, (screenHeight/6) * 3)
  -- Vitesse
  myZombie.speed = math.random(5,50) / 500
  -- Acuité visuelle / odoras en pixels
  myZombie.range = math.random(10,150)
  -- Au départ il est inerte
  myZombie.state = ZS.NONE
end

function UpdateZombie(psZombie, psEntities)
  -- ======================== --
  -- NONE
  -- ======================== --
  -- Le zombie doit choisir une nouvelle direction
  if psZombie.state == ZS.NONE then
    -- Au prochain tour, il choisira une direction
    psZombie.state = ZS.CHANGE
  -- ======================== --
  -- WALK
  -- ======================== --
  elseif psZombie.state == ZS.WALK then
    -- Sort de l'écran ?
    if psZombie.x < 0 or psZombie.y < 0 or psZombie.x > screenWidth or psZombie.y > screenHeight then
      psZombie.state = ZS.CHANGE
    end
    -- Observe son environnement pour trouver une proie (un humain)
    for i,sprite in ipairs(psEntities) do
      if sprite.type == "human" then
        if math.dist(psZombie.x, psZombie.y, sprite.x, sprite.y) < psZombie.range
            and sprite.dead == false then
          psZombie.state = ZS.ATTACK
          psZombie.target = sprite
        end
      end
    end
  -- ======================== --
  -- ATTACK
  -- ======================== --
  elseif psZombie.state == ZS.ATTACK then
    if psZombie.target == nil then
      psZombie.state = ZS.CHANGE
    elseif psZombie.target.dead == true then
      psZombie.state = ZS.CHANGE
    elseif math.dist(psZombie.x, psZombie.y, psZombie.target.x, psZombie.target.y) > psZombie.range then
      psZombie.state = ZS.CHANGE
    elseif psZombie.target.life <= 0 then
      psZombie.state = ZS.CHANGE
    elseif CheckCollision(psZombie.x, psZombie.y, psZombie.width, psZombie.height,
                          psZombie.target.x, psZombie.target.y, psZombie.target.width, psZombie.target.height)
          and math.dist(psZombie.x, psZombie.y, psZombie.target.x, psZombie.target.y) < 5 then
      psZombie.vx = 0
      psZombie.vy = 0
      psZombie.state = ZS.BITE
    else
      -- Un peu de chaos dans la direction
      local tx = psZombie.target.x + math.random(-30,30)
      local ty = psZombie.target.y + math.random(-30,30)
      -- Vitesse plus rapide quand on est en colère !
      local angle = math.angle(psZombie.x, psZombie.y, tx, ty)
      psZombie.vx = psZombie.speed * 5 * 60 * math.cos(angle)
      psZombie.vy = psZombie.speed * 5 * 60 * math.sin(angle)
    end
  -- ======================== --
  -- BITE
  -- ======================== --
  elseif psZombie.state == ZS.BITE then
    if psZombie.target.life ~= nil then
      psZombie.target.life = psZombie.target.life - 0.1
      -- Dead !!
      if psZombie.target.life <= 0 then
        psZombie.target.visible = false
        psZombie.target.life = 0
        psZombie.target.dead = true
        -- Ajoute un corps
        local myBody = CreateSprite(lstSprites, "body", "dead_", 1)
        myBody.x = psZombie.target.x
        myBody.y = psZombie.target.y
        
        psZombie.state = ZS.CHANGE
      end
      if math.random(1,20) == 1 then
        local myBlood = {}
        myBlood.x = psZombie.target.x + math.random(-10,10)
        myBlood.y = psZombie.target.y + math.random(-10,10)
        table.insert(lstBlood, myBlood)
      end
    end
    if CheckCollision(psZombie.x, psZombie.y, psZombie.width, psZombie.height,
                          psZombie.target.x, psZombie.target.y,
                          psZombie.target.width, psZombie.target.height) == false
        or math.dist(psZombie.x, psZombie.y, psZombie.target.x, psZombie.target.y) > 5 then
      psZombie.state = ZS.ATTACK
    end
  -- ======================== --
  -- CHANGE
  -- ======================== --
  elseif psZombie.state == ZS.CHANGE then
    -- Choix d'une direction aléatoire
    local angle = math.angle(psZombie.x,psZombie.y,math.random(0,screenWidth),math.random(0,screenHeight))
    psZombie.vx = psZombie.speed * 60 * math.cos(angle)
    psZombie.vy = psZombie.speed * 60 * math.sin(angle)
    psZombie.state = ZS.WALK
  end
end

function love.load()
  
  screenWidth = love.graphics.getWidth() / 2
  screenHeight = love.graphics.getHeight() / 2
  
  -- One human
  theHuman = CreateSprite(lstSprites, "human", "player_", 4)  
  theHuman.x = screenWidth/2
  theHuman.y = (screenHeight/6) * 5
  theHuman.life = 100
  theHuman.dead = false
  
  -- And many zombies...
  local n
  for n=1,200 do
    CreateZombie()
  end
  
end

function love.update(dt)
  
  for i,sprite in ipairs(lstSprites) do
    sprite.currentFrame = sprite.currentFrame + 0.1
    if sprite.currentFrame > #sprite.images + 1 then
      sprite.currentFrame = 1
    end
    -- Vélocité
    sprite.x = sprite.x + sprite.vx * dt
    sprite.y = sprite.y + sprite.vy * dt
    -- Zombie IA
    if sprite.type == "zombie" then
      UpdateZombie(sprite, lstSprites)
    end
  end
  
  -- Move the human!
  if love.keyboard.isDown("left") then
    theHuman.x = theHuman.x - 1*60*dt
  end
  if love.keyboard.isDown("right") then
    theHuman.x = theHuman.x + 1*60*dt
  end
  if love.keyboard.isDown("up") then
    theHuman.y = theHuman.y - 1*60*dt
  end
  if love.keyboard.isDown("down") then
    theHuman.y = theHuman.y + 1*60*dt
  end

end

function love.draw()
  love.graphics.push()
  love.graphics.scale(2,2)
  
  for i,blood in ipairs(lstBlood) do
    love.graphics.draw(imgBlood, blood.x - 1, blood.y - 1)
  end

  for i,sprite in ipairs(lstSprites) do
    if sprite.visible == true then
      local frame = sprite.images[math.floor(sprite.currentFrame)]
      love.graphics.draw(frame, sprite.x - sprite.width/2, sprite.y - sprite.height/2)
      -- Debug info sur les zombies
      if love.keyboard.isDown("d") and sprite.type == "zombie" then
        love.graphics.print(sprite.state, sprite.x - 10, sprite.y - sprite.height - 10)
      else
        -- Petite aide visuelle pour distinguer les zombies en attaque
        if sprite.type == "zombie" then
          if sprite.state == ZS.ATTACK then
            love.graphics.draw(imgAlert,
              sprite.x - imgAlert:getWidth()/2,
              sprite.y - sprite.height - 2)
          end
        end
      end
    end
  end
  
  if theHuman ~= nil then
    love.graphics.print("LIFE:"..tostring(math.floor(theHuman.life)))
  end
  
  love.graphics.pop()
end

function love.keypressed(key)
  --print(key)
  if key == "d" then
    if bDebug == false then
      bDebug = true
    else
      bDebug = false
    end
  end
  
  if key == "escape" then
    love.event.quit()
  end
end