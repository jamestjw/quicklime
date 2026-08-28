port module Main exposing (main)

import Browser
import Html exposing (Html, aside, button, div, form, h1, h2, input, main_, p, span, strong, text)
import Html.Attributes exposing (attribute, class, disabled, id, maxlength, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Json.Encode as Encode
import String


port socketCommand : Encode.Value -> Cmd msg


port socketEvent : (Decode.Value -> msg) -> Sub msg


type Screen
    = Entry
    | Playing


type Connection
    = Offline
    | Connecting
    | Connected


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


type ServerEvent
    = ConnectionChanged Connection
    | Joined Snapshot
    | TileOpened Int Int
    | TileWon Int Player
    | TileExpired Int
    | LeaderboardChanged Int (List RankedPlayer)
    | ClaimResult String (Maybe Player) (Maybe Int)
    | ServerError String


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
                , socketCommand
                    (Encode.object
                        [ ( "action", Encode.string "join" )
                        , ( "name", Encode.string name )
                        ]
                    )
                )

        ClaimTile tileIndex ->
            case model.activeTile of
                Just _ ->
                    if model.connection /= Connected then
                        ( model, Cmd.none )

                    else
                        ( model
                        , socketCommand
                            (Encode.object
                                [ ( "action", Encode.string "claim" )
                                , ( "tileId", Encode.int model.tileId )
                                , ( "tileIndex", Encode.int tileIndex )
                                ]
                            )
                        )

                Nothing ->
                    ( model, Cmd.none )

        ServerMessage value ->
            case Decode.decodeValue serverEventDecoder value of
                Ok event ->
                    ( applyServerEvent event model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


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

        ServerError reason ->
            { model | connection = Offline, result = reason }


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


claimResultText : String -> Maybe Int -> String
claimResultText status reactionMs =
    case status of
        "wrong" ->
            "WRONG TILE -40"

        "won" ->
            "YOU GOT IT - " ++ String.fromInt (Maybe.withDefault 0 reactionMs) ++ "ms"

        _ ->
            "TOO LATE"


view : Model -> Html Msg
view model =
    case model.screen of
        Entry ->
            entryView model

        Playing ->
            gameView model


entryView : Model -> Html Msg
entryView model =
    main_ [ class "entry-page" ]
        [ div [ class "grid-backdrop", attribute "aria-hidden" "true" ] []
        , div [ class "corner-grid", attribute "aria-hidden" "true" ]
            (List.range 0 8 |> List.map cornerTile)
        , div [ class "entry-shell" ]
            [ div [ class "brand-block" ]
                [ div [ class "eyebrow" ] [ span [ class "status-dot" ] [], text "REGIONAL REACTION ARENA" ]
                , h1 [ id "quicklime-title" ] [ text "QUICK", span [] [ text "LIME" ] ]
                , p [ class "tagline" ] [ text "See the spark. Beat the room." ]
                ]
            , form [ class "entry-form", id "join-form", onSubmit StartPlaying ]
                [ div [ class "field-label" ] [ text "PICK A NAME" ]
                , input
                    [ id "player-name"
                    , type_ "text"
                    , placeholder "your name"
                    , maxlength 20
                    , attribute "autocomplete" "nickname"
                    , attribute "aria-label" "Player name"
                    , value model.name
                    , onInput NameChanged
                    ]
                    []
                , button
                    [ id "start-playing"
                    , type_ "submit"
                    , disabled (String.isEmpty (String.trim model.name))
                    ]
                    [ text "START PLAYING", span [ attribute "aria-hidden" "true" ] [ text "->" ] ]
                ]
            , div [ class "connection-status" ]
                [ span [ class "status-dot" ] []
                , text "SERVER AUTHORITATIVE / EVERY WRONG CLICK COSTS 40"
                ]
            ]
        , div [ class "build-mark" ] [ text "ELM CLIENT / PHOENIX SERVER" ]
        ]


gameView : Model -> Html Msg
gameView model =
    main_ [ class "game-page" ]
        [ div [ class "game-header" ]
            [ div [ class "game-brand" ] [ text "QUICK", span [] [ text "LIME" ] ]
            , div [ class "game-meta" ]
                [ metric "TILE" ("#" ++ String.fromInt model.tileId)
                , metric "PLAYING" (String.fromInt model.playerCount)
                , connectionBadge model.connection
                ]
            ]
        , div [ class "game-layout" ]
            [ div [ class "arena" ]
                [ div [ class (instructionClass model) ]
                    [ span [ class "status-dot" ] []
                    , text model.result
                    , span [ class "rule-copy" ] [ text "WRONG TILE -40" ]
                    ]
                , div [ class "tile-grid", id "tile-grid" ]
                    (List.range 0 19 |> List.map (tileButton model))
                , playerStats model.player
                ]
            , leaderboardView model
            ]
        ]


metric : String -> String -> Html msg
metric label value_ =
    div [ class "metric" ]
        [ span [] [ text label ]
        , strong [] [ text value_ ]
        ]


connectionBadge : Connection -> Html msg
connectionBadge connection =
    let
        ( label, modifier ) =
            case connection of
                Connected ->
                    ( "LIVE", " connection-badge--live" )

                Connecting ->
                    ( "CONNECTING", "" )

                Offline ->
                    ( "OFFLINE", "" )
    in
    div [ class ("connection-badge" ++ modifier) ]
        [ span [ class "status-dot" ] [], text label ]


instructionClass : Model -> String
instructionClass model =
    if model.activeTile == Nothing then
        "instruction instruction--waiting"

    else
        "instruction"


tileButton : Model -> Int -> Html Msg
tileButton model tileIndex =
    let
        active =
            model.activeTile == Just tileIndex

        classes =
            if active then
                "game-tile game-tile--active"

            else
                "game-tile"
    in
    button
        [ class classes
        , type_ "button"
        , attribute "aria-label" ("Tile " ++ String.fromInt (tileIndex + 1))
        , disabled (model.activeTile == Nothing || model.connection /= Connected)
        , onClick (ClaimTile tileIndex)
        ]
        []


playerStats : Maybe Player -> Html msg
playerStats maybePlayer =
    case maybePlayer of
        Nothing ->
            div [ class "player-stats" ] [ text "CONNECTING TO MATCH..." ]

        Just player ->
            div [ class "player-stats" ]
                [ stat "YOU" (String.fromInt player.score)
                , stat "WINS" (String.fromInt player.wins)
                , stat "YOUR BEST" (formatBest player.bestMs)
                ]


stat : String -> String -> Html msg
stat label value_ =
    div [ class "stat" ] [ span [] [ text label ], strong [] [ text value_ ] ]


formatBest : Maybe Int -> String
formatBest bestMs =
    case bestMs of
        Just milliseconds ->
            String.fromInt milliseconds ++ "ms"

        Nothing ->
            "--"


leaderboardView : Model -> Html msg
leaderboardView model =
    aside [ class "leaderboard" ]
        [ div [ class "leaderboard-heading" ]
            [ h2 [] [ text "LEADERBOARD" ]
            , span [] [ text (String.fromInt model.playerCount ++ " ACTIVE") ]
            ]
        , p [] [ text "Top 20 / disconnected players drop after 20s" ]
        , div [ class "leaderboard-labels" ]
            [ span [] [ text "#" ], span [] [ text "PLAYER" ], span [] [ text "WINS" ], span [] [ text "PTS" ] ]
        , div [ class "leaderboard-rows" ] (List.map (leaderboardRow model.player) model.leaderboard)
        ]


leaderboardRow : Maybe Player -> RankedPlayer -> Html msg
leaderboardRow own ranked =
    let
        isOwn =
            case own of
                Just player ->
                    player.id == ranked.player.id

                Nothing ->
                    False

        classes =
            String.join " "
                [ "leaderboard-row"
                , if isOwn then
                    "leaderboard-row--you"

                  else
                    ""
                , if ranked.player.connected then
                    ""

                  else
                    "leaderboard-row--stalled"
                ]
    in
    div [ class classes ]
        [ span [] [ text (String.fromInt ranked.rank) ]
        , span [] [ text ranked.player.name ]
        , span [] [ text (String.fromInt ranked.player.wins) ]
        , strong [] [ text (String.fromInt ranked.player.score) ]
        ]


cornerTile : Int -> Html msg
cornerTile index =
    div
        [ class
            (if index == 4 then
                "corner-tile corner-tile--active"

             else
                "corner-tile"
            )
        ]
        []


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
                (Decode.field "status" Decode.string)
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
