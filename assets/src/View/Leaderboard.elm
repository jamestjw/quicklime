module View.Leaderboard exposing (view)

import Html exposing (Html, aside, div, h2, p, span, strong, text)
import Html.Attributes exposing (class)
import Protocol exposing (Player, RankedPlayer)
import String


view : Maybe Player -> Int -> List RankedPlayer -> Html msg
view own playerCount players =
    aside [ class "leaderboard" ]
        [ div [ class "leaderboard-heading" ]
            [ h2 [] [ text "LEADERBOARD" ]
            , span [] [ text (String.fromInt playerCount ++ " ACTIVE") ]
            ]
        , p [] [ text "Top 20 / disconnected players drop after 20s" ]
        , div [ class "leaderboard-labels" ]
            [ span [] [ text "#" ], span [] [ text "PLAYER" ], span [] [ text "WINS" ], span [] [ text "PTS" ] ]
        , div [ class "leaderboard-rows" ] (List.map (row own) players)
        ]


row : Maybe Player -> RankedPlayer -> Html msg
row own ranked =
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
