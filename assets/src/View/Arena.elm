module View.Arena exposing (Config, view)

import Html exposing (Html, button, div, main_, span, strong, text)
import Html.Attributes exposing (attribute, class, disabled, id, type_)
import Html.Events exposing (onClick)
import Protocol exposing (Connection(..), Player, RankedPlayer)
import String
import View.Leaderboard as Leaderboard


type alias Config msg =
    { connection : Connection
    , tileId : Int
    , activeTile : Maybe Int
    , playerCount : Int
    , leaderboard : List RankedPlayer
    , player : Maybe Player
    , result : String
    , onClaim : Int -> msg
    }


view : Config msg -> Html msg
view config =
    main_ [ class "game-page" ]
        [ div [ class "game-header" ]
            [ div [ class "game-brand" ] [ text "QUICK", span [] [ text "LIME" ] ]
            , div [ class "game-meta" ]
                [ metric "TILE" ("#" ++ String.fromInt config.tileId)
                , metric "PLAYING" (String.fromInt config.playerCount)
                , connectionBadge config.connection
                ]
            ]
        , div [ class "game-layout" ]
            [ div [ class "arena" ]
                [ div [ class (instructionClass config.activeTile) ]
                    [ span [ class "status-dot" ] []
                    , text config.result
                    , span [ class "rule-copy" ] [ text "WRONG TILE -40" ]
                    ]
                , div [ class "tile-grid", id "tile-grid" ]
                    (List.range 0 19 |> List.map (tileButton config))
                , playerStats config.player
                ]
            , Leaderboard.view config.player config.playerCount config.leaderboard
            ]
        ]


metric : String -> String -> Html msg
metric label value =
    div [ class "metric" ]
        [ span [] [ text label ]
        , strong [] [ text value ]
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


instructionClass : Maybe Int -> String
instructionClass activeTile =
    if activeTile == Nothing then
        "instruction instruction--waiting"

    else
        "instruction"


tileButton : Config msg -> Int -> Html msg
tileButton config tileIndex =
    let
        classes =
            if config.activeTile == Just tileIndex then
                "game-tile game-tile--active"

            else
                "game-tile"
    in
    button
        [ class classes
        , type_ "button"
        , attribute "aria-label" ("Tile " ++ String.fromInt (tileIndex + 1))
        , disabled (config.activeTile == Nothing || config.connection /= Connected)
        , onClick (config.onClaim tileIndex)
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
stat label value =
    div [ class "stat" ] [ span [] [ text label ], strong [] [ text value ] ]


formatBest : Maybe Int -> String
formatBest bestMs =
    case bestMs of
        Just milliseconds ->
            String.fromInt milliseconds ++ "ms"

        Nothing ->
            "--"
