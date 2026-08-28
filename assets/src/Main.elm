port module Main exposing (main)

import Browser
import Html exposing (Html)
import Json.Decode as Decode
import Json.Encode as Encode
import Protocol exposing (ClaimStatus(..), Connection(..), Player, RankedPlayer, ServerEvent(..))
import String
import View.Arena as Arena
import View.Entry as Entry


port socketCommand : Encode.Value -> Cmd msg


port socketEvent : (Decode.Value -> msg) -> Sub msg


type Screen
    = Entry
    | Playing


type alias Model =
    { name : String
    , screen : Screen
    , connection : Connection
    , tileId : Int
    , activeTile : Maybe Int
    , playerCount : Int
    , leaderboard : List RankedPlayer
    , player : Maybe Player
    , result : String
    }


type Msg
    = NameChanged String
    | StartPlaying
    | ClaimTile Int
    | ServerMessage Decode.Value


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, Cmd.none )
        , update = update
        , subscriptions = \_ -> socketEvent ServerMessage
        , view = view
        }


initialModel : Model
initialModel =
    { name = ""
    , screen = Entry
    , connection = Offline
    , tileId = 0
    , activeTile = Nothing
    , playerCount = 0
    , leaderboard = []
    , player = Nothing
    , result = "WAITING FOR THE NEXT TILE"
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NameChanged name ->
            ( { model | name = name }, Cmd.none )

        StartPlaying ->
            let
                name =
                    String.trim model.name
            in
            if String.isEmpty name then
                ( model, Cmd.none )

            else
                ( { model | name = name, screen = Playing, connection = Connecting }
                , socketCommand (Protocol.joinCommand name)
                )

        ClaimTile tileIndex ->
            case model.activeTile of
                Just _ ->
                    if model.connection /= Connected then
                        ( model, Cmd.none )

                    else
                        ( model, socketCommand (Protocol.claimCommand model.tileId tileIndex) )

                Nothing ->
                    ( model, Cmd.none )

        ServerMessage value ->
            case Decode.decodeValue Protocol.serverEventDecoder value of
                Ok event ->
                    ( applyServerEvent event model, Cmd.none )

                Err _ ->
                    ( { model | connection = Offline, result = "GAME UPDATE FAILED - REFRESH TO REJOIN" }
                    , Cmd.none
                    )


applyServerEvent : ServerEvent -> Model -> Model
applyServerEvent event model =
    case event of
        ConnectionChanged connection ->
            { model | connection = connection }

        Joined snapshot ->
            { model
                | connection = Connected
                , tileId = snapshot.tileId
                , activeTile = snapshot.activeTile
                , playerCount = snapshot.playerCount
                , leaderboard = snapshot.leaderboard
                , player = Just snapshot.player
            }

        TileOpened tileId tileIndex ->
            { model
                | tileId = tileId
                , activeTile = Just tileIndex
                , result = "CLICK THE LIT TILE"
            }

        TileWon reactionMs winner ->
            { model
                | activeTile = Nothing
                , result = String.toUpper winner.name ++ " GOT IT - " ++ String.fromInt reactionMs ++ "ms"
                , player = replaceOwnPlayer model.player winner
            }

        TileExpired tileId ->
            if model.tileId == tileId then
                { model | activeTile = Nothing, result = "MISSED - NEW TILE INCOMING" }

            else
                model

        LeaderboardChanged playerCount players ->
            { model | playerCount = playerCount, leaderboard = players }

        ClaimResult status maybePlayer reactionMs ->
            { model
                | player = Maybe.withDefault model.player (Maybe.map Just maybePlayer)
                , result = claimResultText status reactionMs
            }

        ServerError _ ->
            { model | connection = Offline, result = "SOMETHING WENT WRONG - TRY AGAIN" }


replaceOwnPlayer : Maybe Player -> Player -> Maybe Player
replaceOwnPlayer own candidate =
    case own of
        Just player ->
            if player.id == candidate.id then
                Just candidate

            else
                own

        Nothing ->
            own


claimResultText : ClaimStatus -> Maybe Int -> String
claimResultText status reactionMs =
    case status of
        Wrong ->
            "WRONG TILE -40"

        Won ->
            "YOU GOT IT - " ++ String.fromInt (Maybe.withDefault 0 reactionMs) ++ "ms"

        Stale ->
            "TOO LATE"

        Unavailable ->
            "RECONNECTING - TRY THE NEXT TILE"


view : Model -> Html Msg
view model =
    case model.screen of
        Entry ->
            Entry.view model.name NameChanged StartPlaying

        Playing ->
            Arena.view
                { connection = model.connection
                , tileId = model.tileId
                , activeTile = model.activeTile
                , playerCount = model.playerCount
                , leaderboard = model.leaderboard
                , player = model.player
                , result = model.result
                , onClaim = ClaimTile
                }
