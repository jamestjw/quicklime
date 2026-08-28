module Protocol exposing
    ( ClaimStatus(..)
    , Connection(..)
    , Player
    , RankedPlayer
    , ServerEvent(..)
    , Snapshot
    , claimCommand
    , joinCommand
    , serverEventDecoder
    )

import Json.Decode as Decode
import Json.Encode as Encode


type Connection
    = Offline
    | Connecting
    | Connected


type ClaimStatus
    = Won
    | Wrong
    | Stale
    | Unavailable


type alias Player =
    { id : String
    , name : String
    , score : Int
    , wins : Int
    , bestMs : Maybe Int
    , connected : Bool
    }


type alias RankedPlayer =
    { player : Player
    , rank : Int
    }


type alias Snapshot =
    { tileId : Int
    , activeTile : Maybe Int
    , playerCount : Int
    , leaderboard : List RankedPlayer
    , player : Player
    }


type ServerEvent
    = ConnectionChanged Connection
    | Joined Snapshot
    | TileOpened Int Int
    | TileWon Int Player
    | TileExpired Int
    | LeaderboardChanged Int (List RankedPlayer)
    | ClaimResult ClaimStatus (Maybe Player) (Maybe Int)
    | ServerError String


joinCommand : String -> Encode.Value
joinCommand name =
    Encode.object
        [ ( "action", Encode.string "join" )
        , ( "name", Encode.string name )
        ]


claimCommand : Int -> Int -> Encode.Value
claimCommand tileId tileIndex =
    Encode.object
        [ ( "action", Encode.string "claim" )
        , ( "tileId", Encode.int tileId )
        , ( "tileIndex", Encode.int tileIndex )
        ]


serverEventDecoder : Decode.Decoder ServerEvent
serverEventDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen eventByType


eventByType : String -> Decode.Decoder ServerEvent
eventByType eventType =
    case eventType of
        "connection" ->
            Decode.map ConnectionChanged (Decode.field "status" connectionDecoder)

        "joined" ->
            Decode.map Joined snapshotDecoder

        "tile_opened" ->
            Decode.map2 TileOpened
                (Decode.field "tile_id" Decode.int)
                (Decode.field "tile_index" Decode.int)

        "tile_won" ->
            Decode.map2 TileWon
                (Decode.field "reaction_ms" Decode.int)
                (Decode.field "winner" playerDecoder)

        "tile_expired" ->
            Decode.map TileExpired (Decode.field "tile_id" Decode.int)

        "leaderboard" ->
            Decode.map2 LeaderboardChanged
                (Decode.field "player_count" Decode.int)
                (Decode.field "players" (Decode.list rankedPlayerDecoder))

        "claim_result" ->
            Decode.map3 ClaimResult
                (Decode.field "status" claimStatusDecoder)
                (Decode.maybe (Decode.field "player" playerDecoder))
                (Decode.maybe (Decode.field "reaction_ms" Decode.int))

        "join_error" ->
            Decode.map ServerError (Decode.field "reason" Decode.string)

        "claim_error" ->
            Decode.map ServerError (Decode.field "reason" Decode.string)

        _ ->
            Decode.fail ("Unknown server event: " ++ eventType)


connectionDecoder : Decode.Decoder Connection
connectionDecoder =
    Decode.string
        |> Decode.map
            (\status ->
                case status of
                    "connected" ->
                        Connected

                    "connecting" ->
                        Connecting

                    _ ->
                        Offline
            )


claimStatusDecoder : Decode.Decoder ClaimStatus
claimStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "won" ->
                        Decode.succeed Won

                    "wrong" ->
                        Decode.succeed Wrong

                    "stale" ->
                        Decode.succeed Stale

                    "unavailable" ->
                        Decode.succeed Unavailable

                    _ ->
                        Decode.fail ("Unknown claim status: " ++ status)
            )


snapshotDecoder : Decode.Decoder Snapshot
snapshotDecoder =
    Decode.map5 Snapshot
        (Decode.field "tile_id" Decode.int)
        (Decode.field "active_tile" (Decode.nullable Decode.int))
        (Decode.field "player_count" Decode.int)
        (Decode.field "leaderboard" (Decode.list rankedPlayerDecoder))
        (Decode.field "player" playerDecoder)


playerDecoder : Decode.Decoder Player
playerDecoder =
    Decode.map6 Player
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "score" Decode.int)
        (Decode.field "wins" Decode.int)
        (Decode.field "best_ms" (Decode.nullable Decode.int))
        (Decode.field "connected" Decode.bool)


rankedPlayerDecoder : Decode.Decoder RankedPlayer
rankedPlayerDecoder =
    Decode.map2 RankedPlayer
        playerDecoder
        (Decode.field "rank" Decode.int)
