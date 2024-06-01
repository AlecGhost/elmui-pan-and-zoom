# Pan and zoom

An elm-ui component that supports dragging and scrolling with the mouse to pan and zoom.

This is a fork from [JohanWinther/elm-pan-and-zoom](https://github.com/JohanWinther/elm-pan-and-zoom).
All the credit goes to the original author.
This fork just adapts the view-function to integrate well with [elm-ui](https://github.com/mdgriffith/elm-ui).

# Component

The component constists of a [`Viewport`](PanZoom#Viewport) that contains a "content box":

```plaintext
╔═════════════════════════╗
║                         ║
║    ┌────────────────────║╌╌┐
║    │                    ║  ┊
║    │                    ║  ┊
║    │        content     ║  ┊
║    │                    ║  ┊
║    │                    ║  ┊
╚═════════════════════════╝  ┊
     └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘


╔═══╗
║   ║ = viewport
╚═══╝

┌───┐
│   │ = content box
└───┘
```

## Mouse interactions

### Panning

The content box can be moved by dragging anywhere in the viewport with the mouse.

```plaintext
x = mouse pointer

╔═════════════════════════╗
║                  x-->   ║
║    ┌─────────┐-->       ║
║    │         │-->       ║
║    │         │-->       ║
║    │         │-->       ║
║    └─────────┘-->       ║
║                         ║
╚═════════════════════════╝
╔═════════════════════════╗
║                      x  ║
║        ┌─────────┐      ║
║        │         │      ║
║        │         │      ║
║        │         │      ║
║        └─────────┘      ║
║                         ║
╚═════════════════════════╝
```

The content box can also be moved by dragging the box itself.

```plaintext
╔═════════════════════════╗
║                         ║
║    ┌─────────┐----------╫----->
║    │ x-------┼--------> ║
║    │         │----------╫----->
║    │         │----------╫----->
║    └─────────┘----------╫----->
║                         ║
╚═════════════════════════╝
╔═════════════════════════╗
║                         ║
║                      ┌──║╌╌╌╌╌╌┐
║                      │ x║      ┊
║                      │  ║      ┊
║                      │  ║      ┊
║                      └──║╌╌╌╌╌╌┘
║                         ║
╚═════════════════════════╝
```

### Zooming

The content box can be scaled by scrolling the mouse wheel anywhere in the viewport.

```plaintext
╔═════════════════════════╗
║                         ║
║    x─────────┐          ║
║    │         │          ║
║    │         │          ║
║    │         │          ║
║    └─────────┘          ║
║                         ║
╚═════════════════════════╝
╔═════════════════════════╗
║                         ║
║    x────────────────────║───┐
║    │                    ║   ┊
║    │                    ║   ┊
║    │                    ║   ┊
║    │                    ║   ┊
╚═════════════════════════╝   ┊
     ┊                        ┊
     ┊                        ┊
     ┊                        ┊
     └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

When zooming by scrolling content box will always scale relative to the mouse pointer.

```plaintext
╔═════════════════════════╗
║                         ║
║    ┌─────────┐          ║
║    │         │          ║
║    │         │       x  ║
║    │         │          ║
║    └─────────┘          ║
║                         ║
╚═════════════════════════╝
╔═════════════════════════╗
║                         ║
║                         ║
║          ┌────┐         ║
║          │    │      x  ║
║          └────┘         ║
║                         ║
║                         ║
╚═════════════════════════╝
```

## Programmatic interaction

It is possible to programatically apply transformations with

- [`moveBy`](PanZoom#moveBy)
- [`moveTo`](PanZoom#moveTo)
- [`scaleBy`](PanZoom#scaleBy)
- [`scaleTo`](PanZoom#scaleTo)

and access the internal state with

- [`getScale`](PanZoom#getScale)
- [`getPosition`](PanZoom#getPosition)
- [`getMousePosition`](PanZoom#getMousePosition)
