module View.Entry exposing (view)

import Html exposing (Html, button, div, form, h1, input, main_, p, span, text)
import Html.Attributes exposing (attribute, class, disabled, id, maxlength, pattern, placeholder, required, type_, value)
import Html.Events exposing (onInput, onSubmit)
import String


view : String -> (String -> msg) -> msg -> Html msg
view name onNameChanged onStart =
    main_ [ class "entry-page" ]
        [ div [ class "grid-backdrop", attribute "aria-hidden" "true" ] []
        , div [ class "corner-grid", attribute "aria-hidden" "true" ]
            (List.range 0 8 |> List.map cornerTile)
        , div [ class "entry-shell" ]
            [ div [ class "brand-block" ]
                [ div [ class "eyebrow" ] [ span [ class "status-dot" ] [], text "LIVE MULTIPLAYER REACTION GAME" ]
                , h1 [ id "quicklime-title" ] [ text "QUICK", span [] [ text "LIME" ] ]
                , p [ class "tagline" ] [ text "See the spark. Beat the room." ]
                ]
            , form [ class "entry-form", id "join-form", onSubmit onStart ]
                [ div [ class "field-label" ] [ text "PICK A NAME" ]
                , input
                    [ id "player-name"
                    , type_ "text"
                    , placeholder "your name"
                    , maxlength 20
                    , required True
                    , pattern ".*\\S.*"
                    , attribute "autocomplete" "nickname"
                    , attribute "aria-label" "Player name"
                    , value name
                    , onInput onNameChanged
                    ]
                    []
                , button
                    [ id "start-playing"
                    , type_ "submit"
                    , disabled (String.isEmpty (String.trim name))
                    ]
                    [ text "START PLAYING", span [ attribute "aria-hidden" "true" ] [ text "->" ] ]
                ]
            , div [ class "connection-status" ]
                [ span [ class "status-dot" ] []
                , text "FIRST TO THE LIGHT WINS / WRONG CLICK -40"
                ]
            ]
        ]


cornerTile : Int -> Html msg
cornerTile index =
    div
        [ class
            (if index == centerTileIndex then
                "corner-tile corner-tile--active"

             else
                "corner-tile"
            )
        ]
        []


centerTileIndex : Int
centerTileIndex =
    -- The center tile gets the flashing highlight in the decorative grid.
    4
