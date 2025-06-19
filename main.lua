wf = require('libraries.windfield')
world = wf.newWorld(0, 0)

anim8 = require('libraries.anim8')

Camera = require('libraries.camera')

sti = require('libraries.sti')
gameMap = sti('maps/level1.lua')

love.graphics.setFont(love.graphics.newFont(24))

currentOS = love.system.getOS()
if currentOS == "iOS" or currentOS == "Android" then
    scale = 2
    scale_mini = 1
else
    scale = 3
    scale_mini = 2
end
screenWidth = love.graphics.getWidth()
screenHeight = love.graphics.getHeight()

currentVolume = 0.5

currentKills = 0 

startTime = 0
currentTime = 0 

love.audio.setVolume(currentVolume)

function love.load() 
    gameState = "startMenu"

    cam = Camera()

    math.randomseed(os.time())
    math.random(); math.random(); math.random()

    sounds = {
        mainTheme = love.audio.newSource("sounds/maintheme.wav", "stream"),
        inGame = love.audio.newSource("sounds/background.wav", "stream"),
        death = love.audio.newSource("sounds/deathsfx.wav", "static"),
        gunshot = love.audio.newSource("sounds/gunshot.wav", "static")
    }

    sounds.mainTheme:play()
    sounds.mainTheme:setLooping(true)
    sounds.inGame:setLooping(true)

    hitbox = {
        isOn = false 
    }

    bullets = {}
    bullets.dmg = 40
    bulletSpeed = 800
    bulletCooldown = 0.5
    bulletTimer = 0

    enemies = {}
    enemies.cdmg = 20
    enemySpeed = 300
    enemySpawnRate = 1 -- seconds
    enemySpawnTimer = 0 

    player = {}
    player.width = 60
    player.height = 90
    player.collider = world:newBSGRectangleCollider(400, 400, player.width, player.height, 5)
    player.collider:setFixedRotation(true)
    player.speed = 550
    player.hp = 100
    playerHurtCooldown = 1 -- seconds
    playerHurtTimer = 0 

    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.2)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.2)

    player.anim = player.animations.left

    walls = {}
    if gameMap.layers["walls"] then 
        for i, obj in pairs(gameMap.layers["walls"].objects) do 
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            wall:setType('static')
        end
    end
end

function checkRectCircleCollision(cx, cy, cr, rx, ry, rw, rh)
    -- Find the closest point on the rectangle to the circle's center
    local closestX = math.max(rx, math.min(cx, rx + rw))
    local closestY = math.max(ry, math.min(cy, ry + rh))

    -- Calculate the distance between the circle's center and this closest point
    local dx = cx - closestX
    local dy = cy - closestY

    -- If the distance is less than the circle's radius, there's a collision
    return (dx * dx + dy * dy) <= (cr * cr)
end

function resetGame()
    bullets = {}
    bullets.dmg = 40
    bulletSpeed = 800
    bulletCooldown = 0.5
    bulletTimer = 0

    enemies = {}
    enemies.cdmg = 20
    enemySpeed = 300
    enemySpawnRate = 1 -- seconds
    enemySpawnTimer = 0 

    player.speed = 550
    player.hp = 100
    playerHurtCooldown = 2 -- seconds
    playerHurtTimer = 0 

    player.anim = player.animations.left
end 

function love.update(dt)
    if gameState ~= "game" then return end 

    currentTime = os.time() - startTime 

    love.graphics.setColor(1,1,1,1)

    sounds.mainTheme:stop()
    sounds.inGame:play()
    -- Player movement
        local isMoving = false 

        local vx = 0
        local vy = 0

        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then 
            vx = player.speed
            player.anim = player.animations.right 
            isMoving = true
        end
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            vx = player.speed * -1
            player.anim = player.animations.left
            isMoving = true
        end
        if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            vy = player.speed * -1
            player.anim = player.animations.up
            isMoving = true 
        end
        if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            vy = player.speed
            player.anim = player.animations.down 
            isMoving = true 
        end
        
        player.collider:setLinearVelocity(vx, vy)

        if isMoving == false then
            player.anim:gotoFrame(2)
        end

        -- Bullet / gun logic
        bulletTimer = bulletTimer - dt
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            b.x = b.x + b.dx * bulletSpeed * dt
            b.y = b.y + b.dy * bulletSpeed * dt
            -- Remove bullets off-screen
            if b.x < 0 or b.x > gameMap.width * 64 or b.y < 0 or b.y > gameMap.height * 64 then
                table.remove(bullets, i)
            end
        end
        
        -- Enemy logic

        -- Spawning enemies
        enemySpawnTimer = enemySpawnTimer + dt
        if enemySpawnTimer >= enemySpawnRate then
            enemySpawnTimer = 0

            local spawnX = math.random(0, gameMap.width * 64)
            local spawnY = math.random(0, gameMap.height * 64)
    
            table.insert(enemies, {
                x = spawnX,
                y = spawnY,
                hp = 40
            })
        end

        -- Enemy movement
        for i, enemy in ipairs(enemies) do
            local dx = player.x - enemy.x
            local dy = player.y - enemy.y
            local dist = math.sqrt(dx^2 + dy^2)
            ex = (dx / dist) * enemySpeed * dt
            ey = (dy / dist) * enemySpeed * dt
            enemy.x = enemy.x + ex
            enemy.y = enemy.y + ey
        end

        -- Enemy and bullet collision
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            for j = #enemies, 1, -1 do
                local e = enemies[j]
                local dx = b.x - e.x
                local dy = b.y - e.y
                if dx * dx + dy * dy < 25^2 then -- collision radius
                    table.remove(bullets, i)  
                    e.hp = e.hp - bullets.dmg
                    if e.hp <= 0 then
                        currentKills = currentKills + 1
                        table.remove(enemies, j)
                    end
                end
            end
        end

        -- Enemy and Player collision
        for _, enemy in ipairs(enemies) do
            local px = player.collider:getX()
            local py = player.collider:getY()
            local pw = player.width
            local ph = player.height

            -- Rectangle X/Y should be TOP LEFT
            local rectX = px - pw / 2
            local rectY = py - ph / 2

            if checkRectCircleCollision(enemy.x, enemy.y, 100, rectX, rectY, pw, ph) then
                playerHurtTimer = playerHurtTimer + dt
                if playerHurtTimer >= playerHurtCooldown then
                    player.hp = player.hp - enemies.cdmg
                    playerHurtTimer = 0 
                end
            end
        end 
        

        -- Player HP logic
        if player.hp <= 0 then
            sounds.inGame:stop()
            sounds.death:play()
            gameState = "deathMenu"
        end

        -- Updating player pos and world
        
        world:update(dt)
        
        player.x = player.collider:getX()
        player.y = player.collider:getY()

        player.anim:update(dt)
        
        -- Cam pos
        local mapWidth = gameMap.width * 64
        local mapHeight = gameMap.height * 64

        local camX = math.max(screenWidth / 2, math.min(player.x, mapWidth - screenWidth / 2))
        local camY = math.max(screenWidth / 2 - 200, math.min(player.y, mapHeight - screenHeight / 2))

        cam:lookAt(camX, camY)
end

function love.draw()
    if gameState == "startMenu" then
        love.graphics.setBackgroundColor(0.2, 0.8, 0.5)
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Elite Killers", screenWidth / 2 - 150, screenHeight / 2 - 400, nil, scale)
        love.graphics.print("Press [SPACE] to start", screenWidth / 2 - 150, screenHeight / 2 - 200, nil, scale_mini)
        love.graphics.print("[S] for settings", screenWidth / 2 - 150, screenHeight / 2 - 75, nil, scale_mini)
    elseif gameState == "settingsMenu" then
        love.graphics.setBackgroundColor(0.2, 0.8, 0.5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Settings", screenWidth / 2 - 350, screenHeight / 2 - 400, nil, scale)
        love.graphics.print("Volume: " .. (currentVolume * 100) .. "% Up/Down Arrow keys to adjust", screenWidth / 2 - 350, screenHeight / 2 - 200, nil, scale_mini)
        if hitbox.isOn then
            love.graphics.setColor(0, 1, 0)
            love.graphics.print("Hitbox: ON", screenWidth / 2 - 350, screenHeight / 2 - 100, nil, scale_mini)
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.print("Hitbox: OFF", screenWidth / 2 - 350, screenHeight / 2 - 100, nil, scale_mini)
        end
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "pauseMenu" then
        love.graphics.setColor(0, 1, 0.5)
        love.graphics.print("PAUSED", screenWidth / 2 - 300, screenHeight / 2 - 200, nil, scale)
        love.graphics.print("[ESC] to unpause or [S] to adjust settings", screenWidth / 2 - 300, screenHeight / 2 - 100, nil, scale_mini)
    elseif gameState == "deathMenu" then
        love.graphics.setBackgroundColor(0,0,0)
        love.graphics.setColor(1,0,0)
        love.graphics.print("YOU DIED!", screenWidth / 2 - 400, screenHeight / 2 - 300, nil, scale)
        love.graphics.print("[ESC] to go back to start or [SPACE] to restart", screenWidth / 2 - 400, screenHeight / 2 - 200, nil, scale_mini)
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "game" then
        cam:attach()
            if gameMap.layers["ground"] then gameMap:drawLayer(gameMap.layers["ground"]) end
            if gameMap.layers["ground2"] then gameMap:drawLayer(gameMap.layers["ground2"]) end
            if gameMap.layers["trees"] then gameMap:drawLayer(gameMap.layers["trees"]) end
            if gameMap.layers["trees3"] then gameMap:drawLayer(gameMap.layers["trees3"]) end
            if gameMap.layers["trees2"] then gameMap:drawLayer(gameMap.layers["trees2"]) end
            player.anim:draw(player.spriteSheet, player.x, player.y, nil, 6, nil, 6, 9)
            if hitbox.isOn then
                world:draw()
            end
            for _, b in ipairs(bullets) do
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("fill", b.x, b.y, b.r)
            end

            for _, e in ipairs(enemies) do
                love.graphics.setColor(1, 0, 0)
                love.graphics.circle("fill", e.x, e.y, 20)
            end
        cam:detach()
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("HP: " .. player.hp, screenWidth / 2 - 400, screenHeight / 2 + 400, nil, scale_mini)
        love.graphics.print("Kills: " .. currentKills, screenWidth / 2 - 400, screenHeight / 2 - 400, nil, scale_mini)
        love.graphics.print("Time: " .. currentTime, screenWidth / 2 - 400, screenWidth / 2 - 300, nil, scale_mini)
        love.graphics.setColor(1,1,1)
    end
end 

function love.mousepressed(x, y, btn)
    if gameState == "game" then
        if btn == 1 and bulletTimer <= 0 then
            sounds.gunshot:play()

            local px = player.collider:getX()
            local py = player.collider:getY()
            local mx, my = love.mouse.getPosition()
            mx, my = cam:worldCoords(mx, my)

            local angle = math.atan2(my - py, mx - px)
            table.insert(bullets, {
                x = px,
                y = py,
                dx = math.cos(angle),
                dy = math.sin(angle),
                r = 6,
                angle = angle
            })
            bulletTimer = bulletCooldown
        end 
    end
end

function love.keypressed(key)
    if gameState == "startMenu" then
        if key == "space" or key == "return" then
            startTime = os.time()
            gameState = "game"
        elseif key == "s" then
            previousGameState = gameState
            gameState = "settingsMenu"
        end
    elseif gameState == "settingsMenu" then
        if key == "up" then
            if currentVolume < 0 then
                currentVolume = currentVolume + 1
            else
            currentVolume = currentVolume + 0.02
            end 
        elseif key == "down" then
            currentVolume = currentVolume - 0.02
        elseif key == "h" then
            hitbox.isOn = not hitbox.isOn
        elseif key == "escape" or key == "b" or key == "s" then
            gameState = previousGameState
        end
        if currentVolume > 1 then
            currentVolume = 1
        elseif currentVolume < 0 then
            currentVolume = 0
        end
        love.audio.setVolume(currentVolume)
    elseif gameState == "game" then
        if key == "p" or key == "escape" then
            if currentVolume > 0.25 then
                love.audio.setVolume(0.25)
            else
                love.audio.setVolume(currentVolume)
            end
            gameState = "pauseMenu"
        elseif key == "x" and bulletTimer <= 0 then
            sounds.gunshot:play()

            local px = player.collider:getX()
            local py = player.collider:getY()
            local mx, my = love.mouse.getPosition()
            mx, my = cam:worldCoords(mx, my)

            local angle = math.atan2(my - py, mx - px)
            table.insert(bullets, {
                x = px,
                y = py,
                dx = math.cos(angle),
                dy = math.sin(angle),
                r = 6,
                angle = angle
            })
            bulletTimer = bulletCooldown
        end
    elseif gameState == "pauseMenu" then
        if key == "s" then
            previousGameState = gameState
            gameState = "settingsMenu"
        elseif key == "escape" or key == "p" or key == "b" then
            gameState = "game"
        end
    elseif gameState == "deathMenu" then
        if key == "return" or key == "space" then
            resetGame()
            gameState = "game"
        elseif key == "escape" or key == "b" then
            resetGame()
            sounds.mainTheme:play()
            gameState = "startMenu"
        end
    end
end
