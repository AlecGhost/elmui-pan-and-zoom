module PanZoom exposing
    ( Config, defaultConfig, ElementFilter(..), ClassList
    , Model, init, view, update, MouseEvent(..)
    , getScale, Scale, getPosition, Coordinate, getMousePosition
    , moveBy, moveTo
    , scaleBy, scaleTo, Anchor(..), getViewport, Viewport
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

@docs scaleBy, scaleTo, Anchor, getViewport, Viewport

-}

import Browser.Dom
import Html as H
import Html.Attributes as HA
import Html.Events exposing (onMouseLeave, onMouseUp)
import PanZoom.Mouse as Mouse exposing (onMouseDown, onMouseMove, onWheelScroll)
import Task



-- Config


{-| Configuration options for the component.

  - `id` - Adds an `id` HTML attribute to the viewport element. Needs to be set for [`getViewport`](PanZoom#getViewport) to return a `Just`.

  - `width` - Width of the content box in pixels.

    **WARNING:** this can be overriden by adding the `width` CSS property to the content box, but this will break the scaling logic.

  - `height` - Height of the content box in pixels.

    **WARNING:** this can be overriden by adding the `width` CSS property to the content box, but this will break the scaling logic.

  - `minScale` - Set a minimum possible scale. This will decide how far you can zoom out.

  - `maxScale` - Set a maximum possible scale. This will decide how far you can zoom in.

  - `scrollScaleFactor` - The factor to scale by when scrolling. For example setting this to `1.1` will scale the content box by 10 % on every scroll.

  - `draggableOnChildren` - If you want to disable the panning logic when dragging on child elements in the content box.

  - `toSelf` -- Map this component's [`MouseEvent`](PanZoom#MouseEvent)s to a `Msg` so that the parent can properly [`update`](PanZoom#update) the component.

**Note:** the viewport's default height is `100vh` but can be overriden by adding your own style attribute in [`view`](PanZoom#view).

-}
type alias Config msg =
    { id : Maybe String
    , width : Float
    , height : Float
    , minScale : Maybe Scale
    , maxScale : Maybe Scale
    , scrollScaleFactor : Float
    , draggableOnChildren : ElementFilter
    , toSelf : MouseEvent -> msg
    }


{-| Default configuration:

    { id = Nothing
    , width = 1920
    , height = 1080
    , minScale = Nothing
    , maxScale = Nothing
    , scrollScaleFactor = 1.1
    , draggableOnChildren = Exclude []
    , toSelf = toSelf
    }

-}
defaultConfig : (MouseEvent -> msg) -> Config msg
defaultConfig toSelf =
    { id = Nothing
    , width = 1920
    , height = 1080
    , minScale = Nothing
    , maxScale = Nothing
    , scrollScaleFactor = 1.1
    , draggableOnChildren = Exclude []
    , toSelf = toSelf
    }


{-| Filters elements by class name.

  - `Include` - dragging the content box will **only** be possible on child elements with any of these class names.
  - `Exclude` - dragging the content box will **not** be possible on child elements with any of these class names.

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


{-| Creates a `Model` with a [`Config`](PanZoom#config) and an initial state.
-}
init : Config msg -> { scale : Scale, position : Coordinate } -> Model msg
init config initialState =
    { config = config
    , state =
        State
            { position = initialState.position
            , scale = initialState.scale
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
            model
                |> scaleBy factor (Point <| Mouse.asCoordinate p)
                |> Maybe.withDefault model


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
For example it is recommended to add the `user-select` CSS property so that any text is not selected while dragging.

**WARNING:** Some attributes/styles should not be overriden for proper function.
For the viewport these are:

  - `id` HTML attribute (set in [`Config`](PanZoom#Config) instead)
  - `overflow` CSS property

For the content box these are:

  - `transform` CSS property
  - `position` CSS property
  - `width` CSS property (set in [`Config`](PanZoom#Config) instead)
  - `height` CSS property (set in [`Config`](PanZoom#Config) instead)

-}
view :
    Model msg
    ->
        { viewportAttributes : List (H.Attribute msg)
        , contentAttributes : List (H.Attribute msg)
        , content : List (H.Html msg)
        }
    -> H.Html msg
view model { viewportAttributes, contentAttributes, content } =
    let
        (State state) =
            model.state

        transform : Coordinate -> Scale -> H.Attribute msg
        transform { x, y } s =
            HA.style "transform" <|
                String.join " "
                    [ "translate(" ++ String.fromFloat x ++ "px ," ++ String.fromFloat y ++ "px)"
                    , "scale(" ++ String.fromFloat s ++ ")"
                    ]
    in
    H.div
        ([ HA.style "overflow" "hidden"
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
            ++ (case model.config.id of
                    Just id ->
                        [ HA.id id ]

                    Nothing ->
                        []
               )
        )
        [ H.div
            ([ transform state.position state.scale
             , HA.style "position" "relative"
             , HA.style "width" <| String.fromFloat model.config.width ++ "px"
             , HA.style "height" <| String.fromFloat model.config.height ++ "px"
             ]
                ++ contentAttributes
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


{-| Get the position of the content box.
-}
getPosition : Model msg -> Coordinate
getPosition model =
    let
        (State state) =
            model.state
    in
    state.position


{-| Get the mouse position if the content box is being dragged.
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


{-| Move the content box to a point.

Given a model where

    getPosition model == { x = 10, y = 20 }

the following holds

    getPosition (model |> moveTo { x = -15, y = 5 }) == { x = -15, y = 5 }

-}
moveTo : Coordinate -> Model msg -> Model msg
moveTo position model =
    { model | state = model.state |> setPosition position }


{-| Scale the content box by a relative value.

Given a model where

    getScale model == scale

the following holds

    getScale (model |> scaleBy factor ContentCenter) == scale * factor

-}
scaleBy : Float -> Anchor -> Model msg -> Maybe (Model msg)
scaleBy amount anchor model =
    let
        (State state) =
            model.state

        config =
            model.config

        scale =
            state.scale * amount

        newPositionDueToScaling point =
            let
                pointNorm =
                    { x = point.x - config.width / 2, y = point.y - config.height / 2 }
            in
            { x = pointNorm.x - amount * (pointNorm.x - state.position.x)
            , y = pointNorm.y - amount * (pointNorm.y - state.position.y)
            }

        insideMin =
            Maybe.withDefault True <| Maybe.map (\m -> m <= scale) model.config.minScale

        insideMax =
            Maybe.withDefault True <| Maybe.map (\m -> scale <= m) model.config.maxScale
    in
    if insideMin && insideMax then
        { model | state = model.state |> setScale scale }
            |> (case anchor of
                    Point point ->
                        moveTo <| newPositionDueToScaling point

                    ViewportCenter viewport ->
                        moveTo <| newPositionDueToScaling <| viewportCenter viewport

                    ContentCenter ->
                        identity
               )
            |> Just

    else
        Nothing


{-| Scale the content box to an absolute scaling.

Given a model where

    getScale model == scale

the following holds

    getScale (model |> scaleTo newScale ContentCenter) == newScale

-}
scaleTo : Scale -> Anchor -> Model msg -> Maybe (Model msg)
scaleTo scale anchor model =
    let
        (State state) =
            model.state
    in
    scaleBy (scale / state.scale) anchor model


{-| The anchor point to scale the content box with respect to.

To use the `ViewportCenter` you need to provide a [`Viewport`](PanZoom#Viewport) which can be created with [`getViewport`](PanZoom#getViewport).

-}
type Anchor
    = Point Coordinate
    | ViewportCenter Viewport
    | ContentCenter


{-| Viewport position and dimensions.

Can only be created with [`getViewport`](PanZoom#getViewport).

-}
type Viewport
    = Viewport { x : Float, y : Float, width : Float, height : Float }


{-| Maybe creates a [`Cmd`](https://package.elm-lang.org/packages/elm/core/latest/Platform-Cmd#Cmd) to get the dimensions of the viewport.

The function will return `Nothing` if `model.config.id == Nothing`.

-}
getViewport :
    Model msg
    ->
        Maybe
            (Cmd
                (Result Browser.Dom.Error Viewport)
            )
getViewport model =
    let
        toViewport : Browser.Dom.Element -> Viewport
        toViewport { element } =
            Viewport { x = element.x, y = element.y, width = element.width, height = element.height }
    in
    model.config.id
        |> Maybe.map
            (Browser.Dom.getElement
                >> Task.attempt (Result.map toViewport)
            )



-- Internal state


{-| Opaque internal state.

Values inside can be accessed with [getters](#getters) e.g. [`getScale`](PanZoom#getScale).

-}
type State
    = State
        { scale : Scale
        , position : Coordinate
        , draggingMousePosition : Maybe Mouse.Position
        }


setScale : Scale -> State -> State
setScale scale (State state) =
    State { state | scale = scale }


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


{-| Center point of a viewport.
-}
viewportCenter : Viewport -> Coordinate
viewportCenter (Viewport { x, y, width, height }) =
    { x = x + width / 2, y = y + height / 2 }



-- Utilities


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
