---
title: Conway's Game Of Life in Elm
description: Conway's Game Of Life in Elm
tags: Elm, Functional Programming, Conway's Game Of Life
---

[Conway's Game Of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) is a cellular automaton: just a very simple model of computation that pretends to emulate "life". It consists of a grid of cells each one of which can be alive or dead. Taken from Wikipedia these are the rules: 

> At each step in time, the following transitions occur:

> * Any live cell with fewer than two live neighbours dies, as if caused by underpopulation.
> * Any live cell with two or three live neighbours lives on to the next generation.
> * Any live cell with more than three live neighbours dies, as if by overpopulation.
> * Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
 
 You can see it live here (at the right side):
 
<div align="center">
<blockquote class="instagram-media" data-instgrm-version="7" style=" background:#FFF; border:0; border-radius:3px; box-shadow:0 0 1px 0 rgba(0,0,0,0.5),0 1px 10px 0 rgba(0,0,0,0.15); margin: 1px; max-width:658px; padding:0; width:99.375%; width:-webkit-calc(100% - 2px); width:calc(100% - 2px);"><div style="padding:8px;"> <div style=" background:#F8F8F8; line-height:0; margin-top:40px; padding:50.0% 0; text-align:center; width:100%;"> <div style=" background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAAAMUExURczMzPf399fX1+bm5mzY9AMAAADiSURBVDjLvZXbEsMgCES5/P8/t9FuRVCRmU73JWlzosgSIIZURCjo/ad+EQJJB4Hv8BFt+IDpQoCx1wjOSBFhh2XssxEIYn3ulI/6MNReE07UIWJEv8UEOWDS88LY97kqyTliJKKtuYBbruAyVh5wOHiXmpi5we58Ek028czwyuQdLKPG1Bkb4NnM+VeAnfHqn1k4+GPT6uGQcvu2h2OVuIf/gWUFyy8OWEpdyZSa3aVCqpVoVvzZZ2VTnn2wU8qzVjDDetO90GSy9mVLqtgYSy231MxrY6I2gGqjrTY0L8fxCxfCBbhWrsYYAAAAAElFTkSuQmCC); display:block; height:44px; margin:0 auto -44px; position:relative; top:-22px; width:44px;"></div></div><p style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:14px; line-height:17px; margin-bottom:0; margin-top:8px; overflow:hidden; padding:8px 0 7px; text-align:center; text-overflow:ellipsis; white-space:nowrap;"><a href="https://www.instagram.com/p/BNFcfHTA0K3/" style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:14px; font-style:normal; font-weight:normal; line-height:17px; text-decoration:none;" target="_blank">Un vídeo publicado por Miguel Vilá (@miguel_vila)</a> el <time style=" font-family:Arial,sans-serif; font-size:14px; line-height:17px;" datetime="2016-11-21T20:09:29+00:00">21 de Nov de 2016 a la(s) 12:09 PST</time></p></div></blockquote>
<script async defer src="//platform.instagram.com/en_US/embeds.js"></script>
</div>

That was an installation called _With a Rhythmic Instinction to be Able to Travel Beyond Existing Forces of Life_ by [Phillippe Parreno](https://en.wikipedia.org/wiki/Philippe_Parreno). You can even see it slows down from time to time.

So I built the Game Of Life using [Elm](http://elm-lang.org/) (code is [here](https://github.com/miguel-vila/conway)). Elm is a functional language that targets front-end applications. It's similar to Haskell but it doesn't have type classes. It has a very dogmatic perspective on how to build applications (the so called [Elm architecture](https://guide.elm-lang.org/architecture/)) which relies in function composition to produce components composition. You can play around with my implementation here:

<script type="text/javascript" src="../code/elm-conway.js"></script>

<div id="elm-conway"></div>

<script type="text/javascript">
Elm.Conway.embed(document.getElementById("elm-conway"));
</script>

It gets old very quickly.

So, while building it I learned a bunch of things:

## The core logic

Starting with some type definitions:

```haskell
type alias Cell =
    { active : Bool
    , x : Int
    , y : Int
    }


type alias Cells =
    Array (Array Cell)
```

Then the core logic is very easy to implement:

```haskell
getCellAt : Cells -> ( Int, Int ) -> Maybe Cell
getCellAt cells ( x, y ) =
    let
        row =
            (Array.get x cells)
    in
        Maybe.andThen row (Array.get y)


neighbours : Cell -> List ( Int, Int )
neighbours { x, y } =
    let
        isValid ( i, j ) =
            0 <= i && i < n && 0 <= j && j < n

        range =
            [ -1, 0, 1 ]

        positions =
            List.concatMap (\i -> List.map (\j -> ( x + i, y + j )) range) range
    in
        positions
            |> List.filter isValid
            |> List.filter (\( i, j ) -> x /= i || y /= j)


getNeighbours : Cell -> Cells -> List Cell
getNeighbours cell cells =
    neighbours cell
        |> List.filterMap (getCellAt cells)

updateCell : Cells -> Cell -> Cell
updateCell cells cell =
    let
        neighbours =
            getNeighbours cell cells

        liveNeighbours =
            List.length <| List.filter .active neighbours

        newState =
            if cell.active then
                liveNeighbours == 2 || liveNeighbours == 3
            else
                liveNeighbours == 3
    in
        { cell | active = newState }


step : Cells -> Cells
step cells =
    Array.map (Array.map (updateCell cells)) cells
```

Having done that it's very easy to turn a `Cells` value into an `Html Cmd`.

## Random grid generation

One interesting challenge was how to generate a random configuration of the grid with some of the cells alive and others dead. Elm's Random library has a very cool approach to this, which is usual in functional languages. For a boolean value they could have provided a function that when called would return a random boolean. The problem is that this function wouldn't be purely functional because different invocations would result in different values being returned. A better way is to return something that can generate a random value. And then, when we want to generate a random value we use this generator to create a `Cmd Msg` value which we are going to give to Elm's runtime. It will execute the random generation (that's executing a side effect, possibly changing the state of a random seed) and will deliver us (through the `update` function) the result. Talking in code this is what we do:


```haskell
type Msg
    = ...
    | ...
    | GenerateRandomCells
    | SetRandomCells Cells

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ...
        
        GenerateRandomCells ->
            model ! [ generateRandomCells ]

        SetRandomCells randCells ->
            { model | cells = randCells } ! []

generateRandomCells : Cmd Msg
generateRandomCells =
    Random.generate SetRandomCells (randomCells n)

randomCells : Int -> Generator Cells
randomCells n = ???
```

The strategy of delaying some computation and returning a representation of it is very common in functional programming. This allows us to have very declarative combinator functions.

The question then is: how to build a `Generator Cells`? To do this we can start with something that generates a random boolean and from that we can build a `Generator Cell`:

```haskell
randomCell : Int -> Int -> Generator Cell
randomCell x y =
    Random.map (\active -> Cell active x y) Random.bool
```

Now let's say we want to generate a row of `n` cells with some index `x`:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x = ???
```

We could try something like this:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x =
    randomCell x
        |> Array.repeat n
```

But we would be returning a `Array (Int -> Generator Cell)`. We can apply the index for each element like this:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x =
    randomCell x
        |> Array.repeat n
        |> Array.indexedMap (\y getCellGen -> getCellGen y)
```

A smart-ass way to do the same:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x =
    randomCell x
        |> Array.repeat n
        |> Array.indexedMap (|>)
```

But we are still not returning a `Generator (Array Cell)`, we are returning a `Array (Generator Cell)`! Does this sound like a familiar problem? It turns out that this is a very common combinator in functional programming. In Haskell the function that turns a `[m a]` into a `m [a]` (similar to what we want to do here) is called [`sequence`](https://hackage.haskell.org/package/base-4.9.0.0/docs/Prelude.html#v:sequence) (I think it's more common to use [`mapM`](https://hackage.haskell.org/package/base-4.9.0.0/docs/Prelude.html#v:mapM), though). In Haskell there are type classes so this function can be generalized for every type in the _Applicative_ type class (Haskell restricts to _Monad_ but this is a historical error). In Elm this function must be implemented explicitly. Unfortunately the standard library doesn't have it, but [`Random.Extra`](http://package.elm-lang.org/packages/elm-community/random-extra/latest) does. It's called `together` and it works on `List`, not `Array` (this is another side of the function that can be generalized with another type class). Thus we can get what we want like this:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x =
    randomCell x
        |> List.repeat n
        |> List.indexedMap (|>)
        |> Random.Extra.together
        |> Random.map Array.fromList
```

Now we want to use this function to generate a random grid of cells, given a number `n` (the number of rows and columns). Curiously the code is very similar:

```haskell
randomCells : Int -> Generator Cells
randomCells n =
    (randomRow n)
        |> List.repeat n
        |> List.indexedMap (|>)
        |> Random.Extra.together
        |> Random.map Array.fromList
```

## Coloring patterns

During a run some interesting [patterns](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life#Examples_of_patterns) can arise. There is even a [wiki section](http://www.conwaylife.com/wiki/Category:Patterns) classifying a lot of patterns. So I wanted to give some specific color when one of these patterns arises.

To do this I took a very simplistic approach:

* First identify contiguous regions of live cells.
* For each of these regions try to match it against a set of templates of patterns.
* Those regions that matched some pattern will be shown with a different color.

To do the first step I had to find the [connected components](http://www.conwaylife.com/wiki/Category:Patterns) present in the grid. I implemented Breadth First Search (BFS) for this

* How to give different colors to different patterns
* Breadth First Search for finding the connected components 
* A Region is a NonEmptyList of Cells
* Cell Patterns
