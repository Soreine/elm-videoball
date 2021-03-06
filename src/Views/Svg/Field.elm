module Views.Svg.Field exposing
    ( background
    , leftGoal
    , rightGoal
    , view
    )

import Html exposing (Html)
import Html.Attributes
import Physical.Ball as Ball
import Physical.Field as Field
import Svg exposing (Svg)
import Svg.Attributes


view : List (Svg msg) -> Html msg
view =
    Svg.svg [ viewBox ]


viewBox : Html.Attribute msg
viewBox =
    Svg.Attributes.viewBox <|
        String.join " "
            [ "0 0", stringFieldWidth, stringFieldHeight ]


background : Svg msg
background =
    Svg.rect
        [ Svg.Attributes.x "0"
        , Svg.Attributes.y "0"
        , Svg.Attributes.width stringFieldWidth
        , Svg.Attributes.height stringFieldHeight
        , Svg.Attributes.fill "#f9ecfe"
        ]
        []


leftGoal : Svg msg
leftGoal =
    Svg.rect
        [ Svg.Attributes.x "0"
        , Svg.Attributes.y "0"
        , Svg.Attributes.width leftGoalLimit
        , Svg.Attributes.height stringFieldHeight
        , Svg.Attributes.fill "orange"
        , Svg.Attributes.opacity "0.5"
        ]
        []


rightGoal : Svg msg
rightGoal =
    Svg.rect
        [ Svg.Attributes.x rightGoalLimit
        , Svg.Attributes.y "0"
        , Svg.Attributes.width leftGoalLimit
        , Svg.Attributes.height stringFieldHeight
        , Svg.Attributes.fill "green"
        , Svg.Attributes.opacity "0.5"
        ]
        []


leftGoalLimit : String
leftGoalLimit =
    String.fromFloat (2 * Ball.size)


rightGoalLimit : String
rightGoalLimit =
    String.fromFloat (Field.width - 2 * Ball.size)


stringFieldWidth : String
stringFieldWidth =
    String.fromFloat Field.width


stringFieldHeight : String
stringFieldHeight =
    String.fromFloat Field.height
