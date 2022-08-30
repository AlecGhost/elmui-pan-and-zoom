module PanZoom.Mouse exposing
    ( onMouseMove, onMouseDown, onWheelScroll
    , Position, asCoordinate, Coordinate, delta
    )

{-| This module includes abstractions for handling mouse events.


# Custom event listeners

@docs onMouseMove, onMouseDown, onWheelScroll


# Mouse position

@docs Position, asCoordinate, Coordinate, delta

-}

import Html as H
import Html.Events as HE
import Json.Decode as JD



-- Event listeners


{-| Custom event listener for `mousemove` that returns the mouse `Position`.
-}
onMouseMove : (Position -> msg) -> H.Attribute msg
onMouseMove message =
    HE.on "mousemove"
        (JD.map message positionDecoder)


{-| Custom event listener for `mousedown` that returns the mouse `Position` and the classes of the target element that was clicked.
-}
onMouseDown : (Position -> List String -> msg) -> H.Attribute msg
onMouseDown message =
    HE.on "mousedown"
        (JD.map2 message
            positionDecoder
            (JD.at [ "target", "className" ] classListDecoder)
        )


{-| Custom event listener for `wheel` that returns the mouse `Position` and the scroll amount of the wheel (in pixels).
-}
onWheelScroll : (Position -> Float -> msg) -> H.Attribute msg
onWheelScroll message =
    HE.on "wheel"
        (JD.map2 message
            positionDecoder
            scrollDecoder
        )



-- Types


{-| Mouse position.
-}
type Position
    = Position Coordinate


positionDecoder : JD.Decoder Position
positionDecoder =
    JD.map Position <|
        JD.map2 Coordinate
            (JD.at [ "pageX" ] JD.float)
            (JD.at [ "pageY" ] JD.float)


{-| Mouse position as coordinate record.
-}
asCoordinate : Position -> Coordinate
asCoordinate (Position c) =
    c


{-| Delta/difference vector between two mouse `Position`s.

    delta (Position { x = 50, y = 10 }) (Position { x = 20, y = -10 }) == { x = -30, y = -20 }

    delta (Position { x = 50, y = 10 }) (Position { x = 20, y = -10 }) == { x = -30, y = -20 }

-}
delta : Position -> Position -> Coordinate
delta (Position p1) (Position p2) =
    { x = p2.x - p1.x
    , y = p2.y - p1.y
    }


scrollDecoder : JD.Decoder Float
scrollDecoder =
    JD.at [ "deltaY" ] JD.float



-- Utilities


{-| JSON decoder for a `ClassList`. Assumes that the class list is a string separated by spaces.

Ignores validation of class names which means any non-empty string will be added to the `ClassList`.

-}
classListDecoder : JD.Decoder (List String)
classListDecoder =
    JD.map (List.filter (not << String.isEmpty) << String.split " ") JD.string


{-| Two dimensional vector that can represent a point or direction.
-}
type alias Coordinate =
    { x : Float, y : Float }
