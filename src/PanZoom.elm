module PanZoom exposing
    ( Config, defaultConfig, ElementFilter(..), ClassList
    , Model, init, view, update, MouseEvent(..)
    , getScale, Scale, getPosition, Coordinate, getMousePosition
    , moveBy, moveTo
    , scaleBy, scaleTo, Anchor(..)
    )

{-| This module implements a pannable and zoomable component.


# Config

@docs Config, defaultConfig, ElementFilter, ClassList


# State

@docs Model, init, view, update, MouseEvent


## Getters

@docs getScale, Scale, getPosition, Coordinate, getMousePosition


# Transformations


## Panning

@docs moveBy, moveTo


## Zooming

@docs scaleBy, scaleTo, Anchor

-}

import Html as H
import Html.Attributes as HA
import Html.Events exposing (onMouseLeave, onMouseUp)
import PanZoom.Mouse as Mouse exposing (onMouseDown, onMouseMove, onWheelScroll)



-- Config


{-| Configuration options for the component.

  - `viewportOffset` - Tell the component the offset of the viewport's the top left corner
    (needed to properly convert between the internal and browser coordinate systems).

    **NOTE:** this will **not set** the offset, only **inform** the component of the offset.
    This will allow you to set the viewport offset with CSS yourself.

    If your CSS positional logic is too complicated to specify the offset beforehand you can perform these steps:

    1.  In your initial `Config` set `viewportOffset` to the default value of

            viewportOffset =
                { x = 0, y = 0 }

    2.  Call [`Browser.Dom.getElement`](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Dom#getElement)
        and [attempt](https://package.elm-lang.org/packages/elm/core/latest/Task#attempt) the task.

    3.  In the logic receiving the `Msg` containing the
        [`Browser.Dom.Element`](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Dom#Element),
        extract the fields `element.x` and `element.y` and override the config of your `PanZoom.Model`

            let
                oldConfig = panZoomModel.config
                newConfig = { oldConfig | viewportOffset = {x = element.x, y = element.y }
            in
            { panZoomModel | config = newConfig }

  - `minScale` - Set a minimum possible scale. This will decide how far you can zoom out.

  - `maxScale` - Set a maximum possible scale. This will decide how far you can zoom in.

  - `scrollScaleFactor` - The factor to scale by when scrolling. For example setting this to `1.1` will scale the content box by 10 % on every scroll.

  - `draggableOnChildren` - If you want to disable the panning logic when dragging on child elements in the content box.

  - `toSelf` -- Map this component's [`MouseEvent`](PanZoom#MouseEvent)s to a `Msg` so that the parent can properly [`update`](PanZoom#update) the component.

**Note:** the viewport's default dimensions are `100vw` and `100vh` respectively but can be overriden by adding your own style attribute in [`view`](PanZoom#view).

-}
type alias Config msg =
    { viewportOffset : Coordinate
    , minScale : Maybe Scale
    , maxScale : Maybe Scale
    , scrollScaleFactor : Float
    , draggableOnChildren : ElementFilter
    , toSelf : MouseEvent -> msg
    }


{-| Default configuration:

    { viewportOffset = { x = 0, y = 0 }
    , minScale = Nothing
    , maxScale = Nothing
    , scrollScaleFactor = 1.1
    , draggableOnChildren = Exclude []
    , toSelf = toSelf
    }

-}
defaultConfig : (MouseEvent -> msg) -> Config msg
defaultConfig toSelf =
    { viewportOffset = { x = 0, y = 0 }
    , minScale = Nothing
    , maxScale = Nothing
    , scrollScaleFactor = 1.1
    , draggableOnChildren = Exclude []
    , toSelf = toSelf
    }


{-| Filters elements by class name.

  - `Include` - dragging the content box will **only** be possible on child elements with any of these class names.
    The viewport itself needs to have a class in this list to be draggable.
  - `Exclude` - dragging the content box will **not** be possible on child elements with any of these class names.
    The viewport itself can have a class in this list to be non-draggable.

-}
type ElementFilter
    = Include ClassList
    | Exclude ClassList


{-| List of classes.
-}
type alias ClassList =
    List String



-- State


{-| Contains config and internal state.
-}
type alias Model msg =
    { state : State
    , config : Config msg
    }


{-| Creates a `Model` from a [`Config`](PanZoom#config) and an initial scale and position for the content box.

`scale` will be clamped by `minScale` and `maxScale` if they are set.

`position` sets the position of the center point of the content box.
So in order to position the content box at point `p` with respect to its top left corner you will need to set

    position =
        { x = p.x + width / 2, y = p.y + height / 2 }

where the `width` and `height` are the dimensions of the content box specified in pixels.

-}
init : Config msg -> { scale : Scale, position : Coordinate } -> Model msg
init config { scale, position } =
    { config = config
    , state =
        State
            { position = position |> toViewportCoordinates config
            , scale =
                (case ( config.minScale, config.maxScale ) of
                    ( Just minScale, Just maxScale ) ->
                        clamp minScale maxScale

                    ( Just minScale, Nothing ) ->
                        max minScale

                    ( Nothing, Just maxScale ) ->
                        min maxScale

                    ( Nothing, Nothing ) ->
                        identity
                )
                    scale
            , draggingMousePosition = Nothing
            }
    }


{-| Process an event and return a new model.
-}
update : MouseEvent -> Model msg -> Model msg
update mouseEvent model =
    let
        (State state) =
            model.state

        config =
            model.config
    in
    case mouseEvent of
        MouseMoved m2 ->
            case state.draggingMousePosition of
                Just m1 ->
                    { model
                        | state =
                            model.state
                                |> setMousePosition (Just m2)
                                |> movePosition (Mouse.delta m1 m2)
                    }

                _ ->
                    model

        MousePressed m targetElClasses ->
            let
                anyMemberIn l1 l2 =
                    l1 |> List.any (\l -> List.member l l2)

                newMousePosition =
                    case config.draggableOnChildren of
                        Include inc ->
                            if anyMemberIn targetElClasses inc then
                                Just m

                            else
                                Nothing

                        Exclude exc ->
                            if anyMemberIn targetElClasses exc then
                                Nothing

                            else
                                Just m
            in
            { model
                | state =
                    model.state
                        |> setMousePosition newMousePosition
            }

        MouseReleased ->
            { model
                | state = model.state |> setMousePosition Nothing
            }

        WheelScrolled p dir ->
            let
                factor =
                    case dir of
                        Mouse.ScrollUp ->
                            model.config.scrollScaleFactor

                        Mouse.ScrollDown ->
                            1 / model.config.scrollScaleFactor

                        Mouse.ScrollHorizontal ->
                            1
            in
            model |> scaleBy factor (Point <| Mouse.asCoordinate p)


{-| Mouse events.
-}
type MouseEvent
    = MouseMoved Mouse.Position
    | MousePressed Mouse.Position ClassList
    | MouseReleased
    | WheelScrolled Mouse.Position Mouse.ScrollDirection


{-| Show the component with some content.

The elements provided in `content` will become direct descendants of the content box.

It is possible to provide additional HTML attributes to the viewport and content box.
For example it is recommended to add the `user-select` CSS property to the viewport to prevent text from being selected while dragging.

**WARNING:** Some attributes/styles should not be overriden for proper function.
For the viewport these are:

  - `id` HTML attribute (set in [`Config`](PanZoom#Config) instead)
  - `overflow` CSS property

For the content box these are:

  - `transform` CSS property

-}
view :
    Model msg
    ->
        { viewportAttributes : List (H.Attribute msg)
        , contentAttributes : List (H.Attribute msg)
        }
    -> List (H.Html msg)
    -> H.Html msg
view model { viewportAttributes, contentAttributes } content =
    let
        (State state) =
            model.state

        transform : Coordinate -> Scale -> H.Attribute msg
        transform { x, y } s =
            HA.style "transform" <|
                String.join " "
                    [ "translate(-50%, -50%)" -- Center the content box
                    , "translate(" ++ String.fromFloat x ++ "px ," ++ String.fromFloat y ++ "px)"
                    , "scale(" ++ String.fromFloat s ++ ")"
                    ]
    in
    H.div
        ([ HA.style "overflow" "hidden"
         , HA.style "width" "100vw"
         , HA.style "height" "100vh"
         , HA.map model.config.toSelf <| onMouseDown MousePressed
         , HA.map model.config.toSelf <| onMouseUp MouseReleased
         , HA.map model.config.toSelf <| onWheelScroll WheelScrolled
         ]
            ++ (if not <| state.draggingMousePosition == Nothing then
                    List.map (HA.map model.config.toSelf)
                        [ onMouseMove MouseMoved
                        , onMouseLeave MouseReleased
                        ]

                else
                    []
               )
            ++ viewportAttributes
        )
        [ H.div
            (transform state.position state.scale
                :: contentAttributes
            )
            content
        ]



-- Getters


{-| Get the scaling of the content box.
-}
getScale : Model msg -> Scale
getScale model =
    let
        (State state) =
            model.state
    in
    state.scale


{-| Get the position of the center point of the content box.
-}
getPosition : Model msg -> Coordinate
getPosition model =
    let
        (State state) =
            model.state
    in
    fromViewportCoordinates model.config state.position


{-| Get the mouse position (if the content box is being dragged).
-}
getMousePosition : Model msg -> Maybe Coordinate
getMousePosition model =
    let
        (State state) =
            model.state
    in
    Maybe.map Mouse.asCoordinate state.draggingMousePosition



-- Transformations


{-| Move the content box by a relative distance.

Given a model where

    getPosition model == { x = 10, y = 20 }

the following holds

    getPosition (model |> moveBy { x = -15, y = 5 }) == { x = -5, y = 25 }

-}
moveBy : Coordinate -> Model msg -> Model msg
moveBy delta model =
    { model | state = model.state |> movePosition delta }


{-| Move the content box center point to a new position.

Given a model where

    getPosition model == { x = 10, y = 20 }

the following holds

    getPosition (model |> moveTo { x = -15, y = 5 }) == { x = -15, y = 5 }

In order to position the content box at point `p` with respect to its top left corner you will need to call

    moveTo { x = p.x + width / 2, y = p.y + height / 2 }

where the `width` and `height` are the dimensions of the content box specified in pixels.

-}
moveTo : Coordinate -> Model msg -> Model msg
moveTo position model =
    { model
        | state =
            model.state
                |> setPosition (position |> toViewportCoordinates model.config)
    }


{-| Scale the content box by a relative value (if within the `minScale`/`maxScale` bounds).

Given a model where

    getScale model == scale

the following holds

    getScale (model |> scaleBy factor ContentCenter) == scale * factor

-}
scaleBy : Float -> Anchor -> Model msg -> Model msg
scaleBy amount anchor model =
    let
        (State state) =
            model.state

        scale =
            state.scale * amount

        clampedScale =
            clamp
                (Maybe.withDefault scale model.config.minScale)
                (Maybe.withDefault scale model.config.maxScale)
                scale

        clampedAmount =
            clampedScale / state.scale

        newPositionDueToScaling point =
            { x = point.x - clampedAmount * (point.x - state.position.x)
            , y = point.y - clampedAmount * (point.y - state.position.y)
            }
    in
    { model
        | state =
            model.state
                |> setScale clampedScale
                |> (case anchor of
                        Point point ->
                            setPosition
                                (point
                                    |> toViewportCoordinates model.config
                                    |> newPositionDueToScaling
                                )

                        ContentCenter ->
                            identity
                   )
    }


{-| Scale the content box to an absolute scaling (if within the `minScale`/`maxScale` bounds).

Given a model where

    getScale model == scale

the following holds

    getScale (model |> scaleTo newScale ContentCenter) == newScale

-}
scaleTo : Scale -> Anchor -> Model msg -> Model msg
scaleTo scale anchor model =
    let
        (State state) =
            model.state
    in
    scaleBy (scale / state.scale) anchor model


{-| The anchor point to scale the content box with respect to.
-}
type Anchor
    = Point Coordinate
    | ContentCenter



-- Internal state


{-| Opaque internal state.

Values inside can be accessed with [getters](#getters) e.g. [`getScale`](PanZoom#getScale).

-}
type State
    = State
        { scale : Scale
        , position : Coordinate -- Position in viewport coordinate system
        , draggingMousePosition : Maybe Mouse.Position
        }


setScale : Scale -> State -> State
setScale scale (State state) =
    State { state | scale = scale }


{-| Set content box position in viewport coordinate system.
-}
setPosition : Coordinate -> State -> State
setPosition position (State state) =
    State { state | position = position }


movePosition : Coordinate -> State -> State
movePosition delta (State state) =
    State
        { state
            | position =
                { x = state.position.x + delta.x
                , y = state.position.y + delta.y
                }
        }


setMousePosition : Maybe Mouse.Position -> State -> State
setMousePosition mMousePosition (State state) =
    State { state | draggingMousePosition = mMousePosition }



-- Utilities


toViewportCoordinates : Config msg -> Coordinate -> Coordinate
toViewportCoordinates { viewportOffset } position =
    { x = position.x - viewportOffset.x
    , y = position.y - viewportOffset.y
    }


fromViewportCoordinates : Config msg -> Coordinate -> Coordinate
fromViewportCoordinates { viewportOffset } position =
    { x = position.x + viewportOffset.x
    , y = position.y + viewportOffset.y
    }


{-| Two dimensional vector that can represent a point or direction.
-}
type alias Coordinate =
    { x : Float
    , y : Float
    }


{-| Scale of the content box.
-}
type alias Scale =
    Float
