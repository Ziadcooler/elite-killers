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

currentLevel = 0
currentKills = 0
currentTime = 0
finalTime = 0
finalKills = 0
highKills = 0
previousKills = 0

powerUpJustActivated = {}

love.audio.setVolume(currentVolume)

function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

function saveHighScore()
    if not love.filesystem.getInfo("highKills.dat") then
        love.filesystem.write("highKills.dat", tostring(highKills))
    else
        love.filesystem.write("highKills.dat", tostring(highKills))
    end
end

function loadHighScore()
    if love.filesystem.getInfo("highKills.dat") then
        local contents = love.filesystem.read("highKills.dat")
        highKills = tonumber(contents) or 0
    else
        highKills = currentKills or 0
        love.filesystem.write("highKills.dat", tostring(highKills))
    end
end

function resetHighScore()
    if love.filesystem.getInfo("highKills.dat") then
        love.filesystem.remove("highKills.dat")
    end
    highKills = 0 
end


function love.load() 
    gameState = "startMenu"

    cam = Camera()

    math.randomseed(os.time())
    math.random(); math.random(); math.random()

    loadHighScore()

    sounds = {
        mainTheme = love.audio.newSource("sounds/maintheme.wav", "stream"),
        inGame = love.audio.newSource("sounds/background.mp3", "stream"),
        death = love.audio.newSource("sounds/deathsfx.wav", "static"),
        gunshot = love.audio.newSource("sounds/gunshot.wav", "static"),
        victory = love.audio.newSource("sounds/victory.mp3", "stream")
    }

    sounds.mainTheme:play()
    sounds.mainTheme:setLooping(true)
    sounds.inGame:setLooping(true)

    hitbox = {
        isOn = false 
    }

    bullets = {}
    bullets.size = 6
    bullets.dmg = 40
    bulletSpeed = 800
    bulletCooldown = 0.5
    bulletTimer = 0

    enemies = {}
    enemies.cdmg = 20
    enemies.hp = 40
    enemySpeed = 300
    enemySpawnRate = 1 -- seconds
    enemySpawnTimer = 0 

    enemies1Active = true 
    enemies2Active = false
    enemies3Active = false 

    powerUp = {
        speedBoost = {name = "Speed Buff", effect = "Buffs your walk speed by 20%", active = false, applied = false},
        bigBullets = {name = "Kicking Ass", effect = "Increases your bullet's size by 10% and damage by 40%", active = false, applied = false},
        bulletSpeedBoost = {name = "Shot of Light", effect = "Buffs your bullet speed by 50%", active = false, applied = false},
        bulletReloadBoost = {name = "Take Fire", effect = "Reduces reload time by 40%", active = false, applied = false},
        maxHPBoost = {name = "Tank", effect = "+50 Max Health", active = false, applied = false},
        shotRegensHP = {name = "Life Steal", effect = "Killing enemies regens 5 HP", active = false, applied = false},
        explosiveBullets = {name = "Explosive Bullets", effect = "Bullets Explode on Hit", active = false, applied = false},
        scytheSummon = {name = "Helping Hand", effect = "Summon a friend around you to deal contact damage to enemies", active = false, applied = false},
        explosiveBulletsUpgrade = {name = "Nuclear Bullets", effect = "Significantly upgrades explosive bullets", active = false, applied = false},
        scytheSummonUpgrade = {name = "Right Hand Man", effect = "Significantly upgrades Helping Hand", active = false, applied = false}
    }
    selectedPowerUps = {}
    powerSelectionIndex = 1

    scythe = {
        x = 0,
        y = 0,
        size = 30,   
        dmg = 20,    
        angle = 0,
        radius = 30,
        speed = 2 * math.pi
    }

    player = {}
    player.width = 60
    player.height = 90
    player.collider = world:newBSGRectangleCollider(400, 400, player.width, player.height, 5)
    player.collider:setFixedRotation(true)
    player.speed = 550
    player.HP = 100
    player.maxHP = 100 
    playerHurtCooldown = 1
    playerHurtTimer = 0

    scytheHurtCooldown = 1
    scytheHurtTimer = 0 

    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.2)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.2)

    player.anim = player.animations.left

    currentLevel = 0
    currentKills = 0
    currentTime = 0
    finalTime = 0
    finalKills = 0
    previousKills = 0

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
    bullets.size = 6
    bullets.dmg = 40
    bulletSpeed = 800
    bulletCooldown = 0.5
    bulletTimer = 0

    enemies = {}
    enemies.cdmg = 20
    enemies.hp = 40
    enemySpeed = 300
    enemySpawnRate = 1 -- seconds
    enemySpawnTimer = 0 

    enemies1Active = true 
    enemies2Active = false
    enemies3Active = false 

    powerUp = {
        speedBoost = {name = "Speed Buff", effect = "Buffs your walk speed by 20%", active = false, applied = false},
        bigBullets = {name = "Kicking Ass", effect = "Increases your bullet's size by 10% and damage by 40%", active = false, applied = false},
        bulletSpeedBoost = {name = "Shot of Light", effect = "Buffs your bullet speed by 50%", active = false, applied = false},
        bulletReloadBoost = {name = "Take Fire", effect = "Reduces reload time by 40%", active = false, applied = false},
        maxHPBoost = {name = "Tank", effect = "+50 Max Health", active = false, applied = false},
        shotRegensHP = {name = "Life Steal", effect = "Killing enemies regens 5 HP", active = false, applied = false},
        explosiveBullets = {name = "Explosive Bullets", effect = "Bullets Explode on Hit", active = false, applied = false},
        scytheSummon = {name = "Helping Hand", effect = "Summon a friend around you to deal contact damage to enemies", active = false, applied = false},
        explosiveBulletsUpgrade = {name = "Nuclear Bullets", effect = "Significantly upgrades explosive bullets", active = false, applied = false},
        scytheSummonUpgrade = {name = "Right Hand Man", effect = "Significantly upgrades Helping Hand", active = false, applied = false}
    }
    selectedPowerUps = {}
    powerSelectionIndex = 1

    powerUpJustActivated = {}

    scythe = {
        x = 0,
        y = 0,
        size = 30,   
        dmg = 20,    
        angle = 0,
        radius = 30,
        speed = 2 * math.pi
    }


    enemies1Active = true 
    enemies2Active = false

    player = {}
    player.width = 60
    player.height = 90
    player.collider = world:newBSGRectangleCollider(400, 400, player.width, player.height, 5)
    player.collider:setFixedRotation(true)
    player.speed = 550
    player.HP = 100
    player.maxHP = 100 
    playerHurtCooldown = 1
    playerHurtTimer = 0

    scytheHurtCooldown = 1
    scytheHurtTimer = 0 

    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.2)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.2)

    player.anim = player.animations.left

    currentLevel = 0
    currentKills = 0
    currentTime = 0
    finalTime = 0
    finalKills = 0
    highKills = 0
    previousKills = 0
end 

function chooseRandomPowerUps()
    selectedPowerUps = {}
    local pool = {}

    for name, p in pairs(powerUp) do
        local isUpgrade = name == "Right Hand Man" or name == "Nuclear Bullets"
        if not p.active and not isUpgrade then
            table.insert(pool, p)
        end
    end

    -- Only add upgrades if the base version was active in a *previous* round
    if powerUp.explosiveBullets.active and not powerUpJustActivated["explosiveBullets"] and not powerUp.explosiveBulletsUpgrade.active then
        table.insert(pool, powerUp.explosiveBulletsUpgrade)
    end
    if powerUp.scytheSummon.active and not powerUpJustActivated["scytheSummon"] and not powerUp.scytheSummonUpgrade.active then
        table.insert(pool, powerUp.scytheSummonUpgrade)
    end

    while #selectedPowerUps < 3 and #pool > 0 do
        local i = math.random(1, #pool)
        table.insert(selectedPowerUps, table.remove(pool, i))
    end

    -- Reset this table so we don’t block upgrades forever
    powerUpJustActivated = {}
end


function love.update(dt)
    if gameState ~= "game" then return end 

    currentTime = currentTime + dt
    formattedTime = formatTime(currentTime)

    if formattedTime == "1:00" then enemies2Active = true end 

    if formattedTime == "2:00" then enemies3Active = true end 

    if formattedTime == "3:00" then 
        sounds.inGame:stop()
        sounds.victory:play()
        gameState = "victoryMenu"
    end  

    -- High score logic
    if currentKills > highKills then
        highKills = currentKills
    end

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

        -- Switching between enemy states
        if enemies2Active then
            enemies1Active = false
            enemies.cdmg = 40
            enemies.hp = 70
            enemySpeed = 400
        end

        if enemies3Active then
            enemies2Active = false
            enemies.cdmg = 70
            enemies.hp = 100
            enemySpeed = 600
        end

        -- Spawning enemies
        enemySpawnTimer = enemySpawnTimer + dt
        if enemySpawnTimer >= enemySpawnRate then
            enemySpawnTimer = 0

            local spawnX = math.random(0, gameMap.width * 64)
            local spawnY = math.random(0, gameMap.height * 64)
    
            table.insert(enemies, {
                x = spawnX,
                y = spawnY,
                hp = enemies.hp,
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
        local collisionRadi = powerUp.bigBullets.active and (25^2 * 1.4) or 25^2

        if dx * dx + dy * dy < collisionRadi then
            -- Remove bullet immediately
            table.remove(bullets, i)

            -- Deal regular damage
            e.hp = e.hp - bullets.dmg

            -- 💥 Explosive bullet effect BEFORE removing enemy e
            if powerUp.explosiveBullets.active then
                local explosionRadius = 150
                for k = #enemies, 1, -1 do
                    local other = enemies[k]
                    -- Make sure 'other' isn't nil and not the same enemy (e)
                    if other ~= e and other ~= nil then
                        local dx2 = b.x - other.x
                        local dy2 = b.y - other.y
                        local distSq = dx2 * dx2 + dy2 * dy2
                        if distSq < explosionRadius * explosionRadius then
                            local explosionDmg = (bullets.dmg / 2)
                            if powerUp.explosiveBulletsUpgrade.active and not powerUp.explosiveBulletsUpgrade.applied then
                                explosionDmg = explosionDmg * 1.5
                                powerUp.explosiveBulletsUpgrade.applied = true 
                            end
                            other.hp = other.hp - explosionDmg
                            if other.hp <= 0 then
                                table.remove(enemies, k)
                                currentKills = currentKills + 1
                                if powerUp.shotRegensHP.active then
                                    player.HP = player.HP + 5
                                end
                            end
                        end
                    end
                end
            end

            -- Only now remove the original hit enemy
            if e.hp <= 0 then
                table.remove(enemies, j)
                currentKills = currentKills + 1
                if powerUp.shotRegensHP.active then
                    player.HP = player.HP + 5
                end
            end

            break -- exit inner loop after bullet hits
        end
    end
end


        -- Enemy/Scythe Collision
        scytheHurtTimer = scytheHurtTimer + dt 
        if powerUp.scytheSummon.active and scytheHurtTimer >= 0 then
            for i = #enemies, 1, -1 do
                local e = enemies[i]
                local dx = scythe.x - e.x
                local dy = scythe.y - e.y
                local distSq = dx * dx + dy * dy
                if distSq <(scythe.size + 25)^2 then
                    e.hp = e.hp - scythe.dmg
                    scytheHurtTimer = scytheHurtCooldown 
                    if e.hp <= 0 then
                        currentKills = currentKills + 1
                        table.remove(enemies, i)
                        if powerUp.shotRegensHP.actve then
                            player.HP = player.HP + 5
                        end
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

            if checkRectCircleCollision(enemy.x, enemy.y, 80, rectX, rectY, pw, ph) then
                playerHurtTimer = playerHurtTimer + dt
                if playerHurtTimer >= playerHurtCooldown then
                    player.HP = player.HP - enemies.cdmg
                    playerHurtTimer = 0 
                end
            end
        end 
        

        -- Player HP Depleted logic
        if player.HP <= 0 then
            saveHighScore()
            sounds.inGame:stop()
            sounds.death:play()
            finalTime = formattedTime
            finalKills = currentKills 
            gameState = "deathMenu"
        end
        if player.HP >= player.maxHP then player.HP = player.maxHP end 
            
        -- Player power ups logic

        -- Player kills 10 enemies then moves on to power up selection
        if currentKills == previousKills + 15 then
            previousKills = currentKills
            currentLevel = currentLevel + 1
            chooseRandomPowerUps()
            gameState =  "powerUpSelection"
        end

        -- Power up effects
        if powerUp.speedBoost.active and not powerUp.speedBoost.applied then
            player.speed = player.speed * 1.2
            powerUp.speedBoost.applied = true 
        end
        if powerUp.bigBullets.active and not powerUp.bigBullets.applied then
            bullets.dmg = bullets.dmg * 1.4
            bullets.size = bullets.size * 1.4
            powerUp.bigBullets.applied = true 
        end
        if powerUp.bulletSpeedBoost.active and not powerUp.bulletSpeedBoost.applied then
            bulletSpeed = bulletSpeed * 1.5
            powerUp.bulletSpeedBoost.applied = true
        end
        if powerUp.bulletReloadBoost.active and not powerUp.bulletReloadBoost.applied then
            bulletCooldown = bulletCooldown / 1.4
            powerUp.bulletReloadBoost.applied = true 
        end
        if powerUp.maxHPBoost.active and not powerUp.maxHPBoost.applied then
            player.HP = player.HP + 50 
            player.maxHP = player.maxHP + 50
            powerUp.maxHPBoost.applied = true 
        end
        if powerUp.scytheSummon.active then
            if powerUp.scytheSummonUpgrade.active then
                scythe.angle = (scythe.angle + scythe.speed * dt) % (2 * math.pi)
            else
                scythe.angle = (scythe.angle + scythe.speed * dt) % (2 * math.pi)
            end
            
            -- Revolve around the player center
            scythe.x = (player.x) + math.cos(scythe.angle) * scythe.radius
            scythe.y = player.y + math.sin(scythe.angle) * scythe.radius
        end
        if powerUp.scytheSummonUpgrade.active and not powerUp.scytheSummonUpgrade.applied then
            scythe.speed = scythe.speed * 1.6
            scythe.dmg = scythe.dmg * 1.6
            powerUp.scytheSummonUpgrade.applied = true 
        end


        -- Shot regens hp code is found in Enemy/Bullet collision
        -- Explosive bullet code found in Enemy/Bullet Collision


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
        love.graphics.print("Total Kills: ".. finalKills, screenWidth / 2 - 400, screenHeight / 2 - 150, nil, scale_mini)
        love.graphics.print("Final Time: " .. finalTime, screenWidth / 2 - 400, screenHeight / 2 - 100, nil, scale_mini)
        love.graphics.print("High score: " .. highKills, screenWidth / 2 - 400, screenHeight /2 - 50, nil, scale_mini)
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "victoryMenu" then
        love.graphics.setBackgroundColor(0,0,0)
        love.graphics.setColor(0,1,0)
        love.graphics.print("YOU WON!", screenWidth / 2 - 400, screenHeight / 2 - 300, nil, scale)
        love.graphics.print("[ESC] to go back to start or [SPACE] to restart", screenWidth / 2 - 400, screenHeight / 2 - 200, nil, scale_mini)
        love.graphics.print("Total Kills: ".. finalKills, screenWidth / 2 - 400, screenHeight / 2 - 150, nil, scale_mini)
        love.graphics.print("Final Time: " .. finalTime, screenWidth / 2 - 400, screenHeight / 2 - 100, nil, scale_mini)
        love.graphics.print("High score: " .. highKills, screenWidth / 2 - 400, screenHeight /2 - 50, nil, scale_mini)
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "powerUpSelection" then
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Select a Power Up", screenWidth / 2 - 350, screenHeight / 2 - 300, nil, scale)

    for i, pow in ipairs(selectedPowerUps) do
        local y = screenHeight / 2 + (i - 1) * 50
        if i == powerSelectionIndex then
            love.graphics.setColor(0, 1, 0)
            love.graphics.print("Effect: " .. pow.effect, screenWidth / 2 - 400, screenHeight / 2 - 350, nil, scale_mini)
            love.graphics.printf("> " .. pow.name, 0, y, screenWidth / 2, "center")
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(pow.name, 0, y, screenWidth / 2, "center")
        end
    end
    elseif gameState == "game" then
        love.graphics.setBackgroundColor(0.2, 0.8, 0.5)
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

            -- bulletS
            for _, b in ipairs(bullets) do
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("fill", b.x, b.y, b.r)
            end

            -- Enemies
            for _, e in ipairs(enemies) do
                if enemies1Active then
                    love.graphics.setColor(0, 1, 0)
                elseif enemies2Active then
                    love.graphics.setColor(1, 1, 0)
                elseif enemies3Active then
                    love.graphics.setColor(1, 0, 0)
                end
                love.graphics.circle("fill", e.x, e.y, 20)
            end
        if powerUp.scytheSummon.active then
            love.graphics.setColor(0, 0, 1)
            love.graphics.circle("fill", scythe.x, scythe.y, scythe.size)
        end
        cam:detach()
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("HP: " .. player.HP .. "/" .. player.maxHP, screenWidth / 2 - 700, screenHeight / 2 + 400, nil, scale_mini)
        love.graphics.print("Kills: " .. currentKills, screenWidth / 2 - 700, screenHeight / 2 - 475, nil, scale_mini)
        love.graphics.print("Highest Kills: " .. highKills, screenWidth / 2 - 700, screenHeight / 2 - 425, nil, scale_mini)
        love.graphics.print("Time: " .. formattedTime, screenWidth / 2 - 700, screenHeight / 2 - 375, nil, scale_mini)
        love.graphics.print("Level: " .. currentLevel, screenWidth / 2 - 700, screenHeight / 2 - 325, nil, scale_mini)
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
                r = bullets.size,
                angle = angle
            })
            bulletTimer = bulletCooldown
        end 
    end
end

function love.keypressed(key)
    if gameState == "startMenu" then
        if key == "space" or key == "return" then
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
                r = bullets.size,
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
    elseif gameState == "powerUpSelection" then
    if key == "up" or key == "w" then
        powerSelectionIndex = powerSelectionIndex - 1
        if powerSelectionIndex < 1 then
            powerSelectionIndex = #selectedPowerUps
        end
    elseif key == "down" or key == "s" then
        powerSelectionIndex = powerSelectionIndex + 1
        if powerSelectionIndex > #selectedPowerUps then
            powerSelectionIndex = 1
        end
    elseif key == "return" or key == "space" then
        -- Activate the selected power-up
        local selected = selectedPowerUps[powerSelectionIndex]

        -- Find and activate the matching powerUp from the main table
        for name, p in pairs(powerUp) do
            if p == selected then
                powerUp[name].active = true
                powerUpJustActivated[name] = true
                break
            end
        end

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
    elseif gameState == "victoryMenu" then
        if key == "return" or key == "space" then
            resetGame()
            sounds.victory:stop()
            gameState = "game"
        elseif key == "escape" or key == "b" then
            resetGame()
            sounds.victory:stop()
            sounds.mainTheme:play()
            gameState = "startMenu"
        end
    end
end