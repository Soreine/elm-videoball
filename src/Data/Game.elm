module Data.Game exposing
    ( Balls
    , Game
    , allBalls
    , allBullets
    , allPlayers
    , init
    , update
    )

import Data.Helper exposing (Four, OneOfFour(..))
import Dict exposing (Dict)
import Physical.Ball as Ball exposing (Ball)
import Physical.Bullet as Bullet exposing (Bullet)
import Physical.Field as Field
import Physical.Player as Player exposing (Player)
import Processing.Collision as Collision
import Time


type alias Game =
    { startTime : Time.Posix
    , frameTime : Time.Posix
    , frameId : Int
    , score : ( Int, Int )
    , player1 : Player
    , player2 : Player
    , player3 : Player
    , player4 : Player
    , bullets1 : Dict Int Bullet
    , bullets2 : Dict Int Bullet
    , bullets3 : Dict Int Bullet
    , bullets4 : Dict Int Bullet
    , balls : Balls
    }


type alias Balls =
    { inGame : Dict Int Ball
    , incoming : List Int
    , timer : BallTimer
    }


type BallTimer
    = WaitingForFreeSpace
    | FreeSince Time.Posix


init : Time.Posix -> Game
init startTime =
    { startTime = startTime
    , frameTime = startTime
    , frameId = 0
    , score = ( 0, 0 )
    , player1 = Player.init startTime 0 Field.placePlayer1
    , player2 = Player.init startTime 0 Field.placePlayer2
    , player3 = Player.init startTime pi Field.placePlayer3
    , player4 = Player.init startTime pi Field.placePlayer4
    , bullets1 = Dict.empty
    , bullets2 = Dict.empty
    , bullets3 = Dict.empty
    , bullets4 = Dict.empty
    , balls = Balls Dict.empty [ 0, 1, 2 ] (FreeSince startTime)
    }


allPlayers : Game -> List Player
allPlayers { player1, player2, player3, player4 } =
    [ player1, player2, player3, player4 ]


allBullets : Game -> List (Dict Int Bullet)
allBullets { bullets1, bullets2, bullets3, bullets4 } =
    [ bullets1, bullets2, bullets3, bullets4 ]


allBalls : Game -> List Ball
allBalls { balls } =
    Dict.values balls.inGame


update : Time.Posix -> Int -> Four Player.Control -> Game -> Game
update newFrameTime duration playerControls game =
    let
        newDirections =
            { one = Maybe.withDefault game.player1.direction playerControls.one.thrusting
            , two = Maybe.withDefault game.player2.direction playerControls.two.thrusting
            , three = Maybe.withDefault game.player3.direction playerControls.three.thrusting
            , four = Maybe.withDefault game.player4.direction playerControls.four.thrusting
            }

        newThrustings =
            { one = not (isNothing playerControls.one.thrusting)
            , two = not (isNothing playerControls.two.thrusting)
            , three = not (isNothing playerControls.three.thrusting)
            , four = not (isNothing playerControls.four.thrusting)
            }

        newShotKeys =
            { one = playerControls.one.holdingShot
            , two = playerControls.two.holdingShot
            , three = playerControls.three.holdingShot
            , four = playerControls.four.holdingShot
            }
    in
    game
        |> changeGameBalls newFrameTime duration
        |> preparePlayers duration newDirections newThrustings
        |> processCollisionsUntil newFrameTime
        |> moveAllUntil newFrameTime
        |> spawnAllBullets newShotKeys


isNothing : Maybe a -> Bool
isNothing maybe =
    case maybe of
        Nothing ->
            True

        _ ->
            False



-- PREPARATION #######################################################


preparePlayers : Int -> Four Float -> Four Bool -> Game -> Game
preparePlayers duration directions thrustings game =
    let
        newPlayer1 =
            Player.prepareMovement duration thrustings.one directions.one game.player1

        newPlayer2 =
            Player.prepareMovement duration thrustings.two directions.two game.player2

        newPlayer3 =
            Player.prepareMovement duration thrustings.three directions.three game.player3

        newPlayer4 =
            Player.prepareMovement duration thrustings.four directions.four game.player4
    in
    { game
        | player1 = newPlayer1
        , player2 = newPlayer2
        , player3 = newPlayer3
        , player4 = newPlayer4
    }



-- COLLISIONS ########################################################


processCollisionsUntil : Time.Posix -> Game -> Game
processCollisionsUntil endTime game =
    allCollisions endTime game
        |> List.sortBy .time
        -- |> Debug.log "allCollisions"
        |> List.foldl processCollision game


processCollision : { time : Float, kind : Collision.Kind } -> Game -> Game
processCollision { time, kind } game =
    case kind of
        -- bullet - wall
        Collision.BulletWall ( Un, id ) _ ->
            { game | bullets1 = Dict.remove id game.bullets1 }

        Collision.BulletWall ( Deux, id ) _ ->
            { game | bullets2 = Dict.remove id game.bullets2 }

        Collision.BulletWall ( Trois, id ) _ ->
            { game | bullets3 = Dict.remove id game.bullets3 }

        Collision.BulletWall ( Quatre, id ) _ ->
            { game | bullets4 = Dict.remove id game.bullets4 }

        -- bullet - ball
        Collision.BulletBall bulletId ballId ->
            -- TODO later: if medium size bullet, do not destroy?
            impactIdentifiedBulletOnBall time bulletId ballId game

        _ ->
            game


impactIdentifiedBulletOnBall : Float -> ( OneOfFour, Int ) -> Int -> Game -> Game
impactIdentifiedBulletOnBall time ( oneOfFour, id ) ballId game =
    case oneOfFour of
        Un ->
            case Dict.get id game.bullets1 of
                Nothing ->
                    game

                Just bullet ->
                    { game
                        | bullets1 = Dict.remove id game.bullets1
                        , balls = updateBallWithId (impactBulletOnBall time bullet) ballId game.balls
                    }

        Deux ->
            case Dict.get id game.bullets2 of
                Nothing ->
                    game

                Just bullet ->
                    { game
                        | bullets2 = Dict.remove id game.bullets2
                        , balls = updateBallWithId (impactBulletOnBall time bullet) ballId game.balls
                    }

        Trois ->
            case Dict.get id game.bullets3 of
                Nothing ->
                    game

                Just bullet ->
                    { game
                        | bullets3 = Dict.remove id game.bullets3
                        , balls = updateBallWithId (impactBulletOnBall time bullet) ballId game.balls
                    }

        Quatre ->
            case Dict.get id game.bullets4 of
                Nothing ->
                    game

                Just bullet ->
                    { game
                        | bullets4 = Dict.remove id game.bullets4
                        , balls = updateBallWithId (impactBulletOnBall time bullet) ballId game.balls
                    }


updateBallWithId : (Ball -> Ball) -> Int -> Balls -> Balls
updateBallWithId f ballId balls =
    { balls | inGame = Dict.update ballId (Maybe.map f) balls.inGame }


impactBulletOnBall : Float -> Bullet -> Ball -> Ball
impactBulletOnBall time bullet ball =
    -- Let's only take bullet direction into account for simplicity for the time being
    let
        movedBall =
            Ball.moveDuring time ball

        ( speedX, speedY ) =
            movedBall.speed

        newSpeed =
            ( speedX + 0.5 * cos bullet.direction
            , speedY + 0.5 * sin bullet.direction
            )
    in
    { movedBall | speed = newSpeed }


allCollisions : Time.Posix -> Game -> List { time : Float, kind : Collision.Kind }
allCollisions endTime ({ player1, player2, player3, player4 } as game) =
    let
        duration =
            Time.posixToMillis endTime - Time.posixToMillis game.frameTime

        allBulletsList =
            Dict.values (Dict.map (triple Un) game.bullets1)
                |> reversePrepend (Dict.values (Dict.map (triple Deux) game.bullets2))
                |> reversePrepend (Dict.values (Dict.map (triple Trois) game.bullets3))
                |> reversePrepend (Dict.values (Dict.map (triple Quatre) game.bullets4))

        allBallsWithId =
            Dict.toList game.balls.inGame
    in
    Collision.playerPlayerAll duration player1 player2 player3 player4
        -- |> reversePrepend (Collision.playerWallAll duration player1 player2 player3 player4)
        -- |> reversePrepend (Collision.playerBulletAll duration player1 player2 player3 player4 allBulletsList)
        -- |> reversePrepend (Collision.playerBallAll duration player1 player2 player3 player4 allBallsWithId)
        -- |> reversePrepend (Collision.bulletBulletAll duration allBulletsList)
        |> reversePrepend (Collision.bulletBallAll duration allBulletsList allBallsWithId)
        -- |> reversePrepend (Collision.ballBallAll duration allBallsWithId)
        -- |> reversePrepend (Collision.ballWallAll duration allBallsWithId)
        |> reversePrepend (Collision.bulletWallAll duration allBulletsList)


triple : a -> b -> c -> ( a, b, c )
triple a b c =
    ( a, b, c )


reversePrepend : List a -> List a -> List a
reversePrepend list1 list2 =
    case list1 of
        [] ->
            list2

        l :: ls ->
            reversePrepend ls (l :: list2)



-- MOVE ##############################################################


{-| Move all units until new frame time and update frame time.
-}
moveAllUntil : Time.Posix -> Game -> Game
moveAllUntil newFrameTime game =
    let
        newPlayer1 =
            Player.moveUntil newFrameTime game.player1
                |> Player.checkWallObstacle 0 Field.width 0 Field.height

        newPlayer2 =
            Player.moveUntil newFrameTime game.player2
                |> Player.checkWallObstacle 0 Field.width 0 Field.height

        newPlayer3 =
            Player.moveUntil newFrameTime game.player3
                |> Player.checkWallObstacle 0 Field.width 0 Field.height

        newPlayer4 =
            Player.moveUntil newFrameTime game.player4
                |> Player.checkWallObstacle 0 Field.width 0 Field.height

        duration =
            Time.posixToMillis newFrameTime - Time.posixToMillis game.frameTime

        moveBullet _ =
            Bullet.move duration

        newBullets1 =
            Dict.map moveBullet game.bullets1

        newBullets2 =
            Dict.map moveBullet game.bullets2

        newBullets3 =
            Dict.map moveBullet game.bullets3

        newBullets4 =
            Dict.map moveBullet game.bullets4

        newBalls =
            moveBallsUntil newFrameTime game.balls
    in
    { game
        | frameTime = newFrameTime
        , player1 = newPlayer1
        , player2 = newPlayer2
        , player3 = newPlayer3
        , player4 = newPlayer4
        , bullets1 = newBullets1
        , bullets2 = newBullets2
        , bullets3 = newBullets3
        , bullets4 = newBullets4
        , balls = newBalls
    }



-- SPAWN BULLETS #####################################################


{-| Spawn bullets and increment frameId.
-}
spawnAllBullets : Four Bool -> Game -> Game
spawnAllBullets shotKeys game =
    let
        ( newPlayer1, hasShot1 ) =
            Player.updateShot shotKeys.one game.player1

        ( newPlayer2, hasShot2 ) =
            Player.updateShot shotKeys.two game.player2

        ( newPlayer3, hasShot3 ) =
            Player.updateShot shotKeys.three game.player3

        ( newPlayer4, hasShot4 ) =
            Player.updateShot shotKeys.four game.player4

        newBullets1 =
            updateBullets game.frameId hasShot1 game.player1 game.bullets1

        newBullets2 =
            updateBullets game.frameId hasShot2 game.player2 game.bullets2

        newBullets3 =
            updateBullets game.frameId hasShot3 game.player3 game.bullets3

        newBullets4 =
            updateBullets game.frameId hasShot4 game.player4 game.bullets4
    in
    { game
        | player1 = newPlayer1
        , player2 = newPlayer2
        , player3 = newPlayer3
        , player4 = newPlayer4
        , bullets1 = newBullets1
        , bullets2 = newBullets2
        , bullets3 = newBullets3
        , bullets4 = newBullets4
        , frameId = game.frameId + 1
    }


updateBullets : Int -> Player.HasShot -> Player -> Dict Int Bullet -> Dict Int Bullet
updateBullets frameId hasShot player bullets =
    case hasShot of
        Player.NoShot ->
            bullets

        Player.ShotAfter chargeTime ->
            Dict.insert frameId (spawnPlayerBullet chargeTime player) bullets


spawnPlayerBullet : Int -> Player -> Bullet
spawnPlayerBullet _ player =
    Bullet.new Bullet.Small player.direction player.pos



-- MANAGING BALLS ####################################################


{-| Let's say for now that we only have OutOfGoal balls.
-}
moveBallsUntil : Time.Posix -> Balls -> Balls
moveBallsUntil newFrameTime balls =
    { balls | inGame = Dict.map (\_ ball -> Ball.moveUntil newFrameTime ball) balls.inGame }


changeGameBalls : Time.Posix -> Int -> Game -> Game
changeGameBalls newFrameTime duration game =
    let
        newBalls =
            game.balls
                -- |> Debug.log "game.balls"
                |> prepareBallsMovements (toFloat duration)
                |> checkStartBallCounter newFrameTime
                |> checkSpawnBall newFrameTime
    in
    { game | balls = newBalls }


{-| There should only be OutOfGoal balls at this time
since that happens before collisions and movements.
-}
prepareBallsMovements : Float -> Balls -> Balls
prepareBallsMovements duration balls =
    { balls | inGame = Dict.map (\_ ball -> Ball.prepareMovement duration ball) balls.inGame }


checkSpawnBall : Time.Posix -> Balls -> Balls
checkSpawnBall frameTime ({ inGame, incoming, timer } as balls) =
    case ( incoming, timer ) of
        ( ballId :: otherBallIds, FreeSince timerStartTime ) ->
            if timeDiff timerStartTime frameTime > ballTimer then
                Balls (Dict.insert ballId (Ball.init frameTime) inGame) otherBallIds WaitingForFreeSpace

            else
                balls

        _ ->
            balls


checkStartBallCounter : Time.Posix -> Balls -> Balls
checkStartBallCounter frameTime ({ inGame, incoming, timer } as balls) =
    if timer == WaitingForFreeSpace && not (List.isEmpty incoming) && centerIsFree inGame then
        { balls | timer = FreeSince frameTime }

    else
        balls


centerIsFree : Dict Int Ball -> Bool
centerIsFree ballsInGame =
    Dict.values ballsInGame
        |> List.all (\ball -> Ball.squareDistanceFrom Field.center ball > 4 * Ball.size * Ball.size)


ballTimer : Int
ballTimer =
    2000


timeDiff : Time.Posix -> Time.Posix -> Int
timeDiff t1 t2 =
    Time.posixToMillis t2 - Time.posixToMillis t1
