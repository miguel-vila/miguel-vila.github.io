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
 
 You can see it live here (the column at the right side):
 
<div align="center">
<blockquote class="instagram-media" data-instgrm-version="7" style=" background:#FFF; border:0; border-radius:3px; box-shadow:0 0 1px 0 rgba(0,0,0,0.5),0 1px 10px 0 rgba(0,0,0,0.15); margin: 1px; max-width:658px; padding:0; width:99.375%; width:-webkit-calc(100% - 2px); width:calc(100% - 2px);"><div style="padding:8px;"> <div style=" background:#F8F8F8; line-height:0; margin-top:40px; padding:50.0% 0; text-align:center; width:100%;"> <div style=" background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAAAMUExURczMzPf399fX1+bm5mzY9AMAAADiSURBVDjLvZXbEsMgCES5/P8/t9FuRVCRmU73JWlzosgSIIZURCjo/ad+EQJJB4Hv8BFt+IDpQoCx1wjOSBFhh2XssxEIYn3ulI/6MNReE07UIWJEv8UEOWDS88LY97kqyTliJKKtuYBbruAyVh5wOHiXmpi5we58Ek028czwyuQdLKPG1Bkb4NnM+VeAnfHqn1k4+GPT6uGQcvu2h2OVuIf/gWUFyy8OWEpdyZSa3aVCqpVoVvzZZ2VTnn2wU8qzVjDDetO90GSy9mVLqtgYSy231MxrY6I2gGqjrTY0L8fxCxfCBbhWrsYYAAAAAElFTkSuQmCC); display:block; height:44px; margin:0 auto -44px; position:relative; top:-22px; width:44px;"></div></div><p style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:14px; line-height:17px; margin-bottom:0; margin-top:8px; overflow:hidden; padding:8px 0 7px; text-align:center; text-overflow:ellipsis; white-space:nowrap;"><a href="https://www.instagram.com/p/BNFcfHTA0K3/" style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:14px; font-style:normal; font-weight:normal; line-height:17px; text-decoration:none;" target="_blank">Un vídeo publicado por Miguel Vilá (@miguel_vila)</a> el <time style=" font-family:Arial,sans-serif; font-size:14px; line-height:17px;" datetime="2016-11-21T20:09:29+00:00">21 de Nov de 2016 a la(s) 12:09 PST</time></p></div></blockquote>
<script async defer src="//platform.instagram.com/en_US/embeds.js"></script>
</div>

That was an art installation called _With a Rhythmic Instinction to be Able to Travel Beyond Existing Forces of Life_ by [Phillippe Parreno](https://en.wikipedia.org/wiki/Philippe_Parreno). You can even see it slows down from time to time when too much "collisions" happen.

So I built the Game Of Life using [Elm](http://elm-lang.org/) (code is [here](https://github.com/miguel-vila/conway)). Elm is a functional language that targets front-end applications. It's similar to Haskell but it doesn't have type classes. It has a very dogmatic perspective on how to build applications (the so called [Elm architecture](https://guide.elm-lang.org/architecture/)) which relies in function composition to produce components composition. You can play around with my implementation here:

<script type="text/javascript" src="../code/elm-conway.js"></script>

<div id="elm-conway"></div>

<script type="text/javascript">
Elm.Conway.embed(document.getElementById("elm-conway"));
</script>

It gets old very quickly.

So, while building it I learned a bunch of things:

## The core logic

As it turns out the core logic (the step rules) are very easy to implement.

Starting with some type definitions:

```haskell
type alias Cell =
    { active : Bool
    , x : Int
    , y : Int
    }


type alias Grid =
    Array (Array Cell)
```

Then the core logic is here:

```haskell
updateCell : Grid -> Cell -> Cell
updateCell grid cell =
    let
        neighbours =
            getNeighbours cell grid

        liveNeighbours =
            List.length <| List.filter .active neighbours

        newState =
            if cell.active then
                liveNeighbours == 2 || liveNeighbours == 3
            else
                liveNeighbours == 3
    in
        { cell | active = newState }


step : Grid -> Grid
step grid =
    Array.map (Array.map (updateCell grid)) grid
```

You can see the other functions [here](https://github.com/miguel-vila/conway/blob/7225158399d5ae41d39e6cac2464c1062743d8eb/src/Model.elm#L31-L60). Those are also kind of simple.

With this it's very easy to create the `update` and `view` functions of the Elm architecture.

## Rendering

I decided to use plain HTML elements because tracking which cell was clicked in a canvas is harder. In Elm every graphical element is rendered according to a function you describe, there are no templates or anything like that. The good thing about this is that you can continue to leverage the language when describing the views.

Starting with your domain types like `Cell` you build an Html from it with a function, say `cellView: Cell -> Html Msg`. Then for a composed type like `Grid` you create a function `gridView : Grid -> Html Msg` by using the `cellView` function we built before. Thus, graphical component composition is achieved by composing functions which is something very simple! I think that idea is powerful, useful and simple.

## Random grid generation

One interesting challenge was how to generate a random configuration of the grid with some of the cells alive and others dead. Elm's [Random](http://package.elm-lang.org/packages/elm-lang/core/4.0.5/Random) library has a very nice approach, which is usual in functional languages. For a boolean value they could have provided a function that, when called, would return a random boolean. The problem is that this function wouldn't be purely functional because different invocations would result in different values being returned. A better way is to return something that can generate a random value. And then, when we want to generate a random value we use this generator to create a `Cmd Msg` value which we are going to give to Elm's runtime. It will execute the random generation (that's executing a side effect, possibly changing the state of a random seed) and will deliver us (through the `update` function) the result. 

Talking in code this is what we do:


```haskell
-- length of the square grid
n = 25

type Msg
    = ...
    | ...
    | GenerateRandomGrid
    | SetRandomGrid Grid

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ...
        
        GenerateRandomGrid ->
            model ! [ generateRandomGrid ]

        SetRandomGrid randGrid ->
            { model | grid = randGrid } ! []

generateRandomGrid : Cmd Msg
generateRandomGrid =
    Random.generate SetRandomGrid (randomGrid n)

randomGrid : Int -> Generator Grid
randomGrid n = ???
```

[`Random.generate`](http://package.elm-lang.org/packages/elm-lang/core/4.0.5/Random#generate) is the function that "performs" the side effect. It creates a `Cmd Msg` that Elm's runtime receives, produces a random value according to the generator and hands it back trough the `update` function.

The strategy of delaying some computation and returning a representation of it is very common in functional programming. This allows us to have very declarative combinator functions.

The question then is: how to build a `Generator Grid`? To do this we can start with something that generates a random boolean and from that we can build a `Generator Cell`:

```haskell
randomCell : Int -> Int -> Generator Cell
randomCell x y =
    Random.map (\active -> Cell active x y) Random.bool
```

`Random.map` is one of those useful combinator functions I was talking about. It receives two things: a function and a generator and returns a new generator that applies the input function to the generated values.

Now let's say we want to generate a row of `n` cells with some index `x`. We could try something like this:

```haskell
randomRow : Int -> Int -> Generator (Array Cell)
randomRow n x =
    randomCell x
        |> Array.repeat n
```

But we are returning a `Array (Int -> Generator Cell)`! We can apply the index for each element like this:

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

But we are still not returning a `Generator (Array Cell)`, we are returning a `Array (Generator Cell)`! Does this sound like a familiar problem? It turns out that this is a very common combinator in functional programming. In other languages this type flipping function (we want to exchange the types `Generator` and `Array`) is called `sequence`. Unfortunately the standard library doesn't have it, but [`Random.Extra`](http://package.elm-lang.org/packages/elm-community/random-extra/latest) does. It's called `together` there and it works on `List`, not `Array`. 

<div class="note">
<p class="aside-header"><strong>Aside</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">

In Haskell the function that turns a `[m a]` into a `m [a]` (similar to what we want to do here) is called [`sequence`](https://hackage.haskell.org/package/base-4.9.0.0/docs/Prelude.html#v:sequence). I think it's more common to use [`mapM`](https://hackage.haskell.org/package/base-4.9.0.0/docs/Prelude.html#v:mapM), though. In Haskell there are type classes so this function can be generalized for every type in the _Applicative_ type class (Haskell restricts to _Monad_ but this is a historical error). In Elm this function must be implemented explicitly for each type that has the same interface as an _Applicative_. 

</div>
</div>

Thus, we can get what we want like this:

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
randomGrid : Int -> Generator Grid
randomGrid n =
    (randomRow n)
        |> List.repeat n
        |> List.indexedMap (|>)
        |> Random.Extra.together
        |> Random.map Array.fromList
```

## Coloring patterns

During a run some interesting [patterns](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life#Examples_of_patterns) can arise. There is even a [wiki section](http://www.conwaylife.com/wiki/Category:Patterns) classifying a lot of them. So I decided to give some specific color when some of these patterns arises.

To do this I took a very simplistic approach:

1. Identify contiguous regions of live cells.
2. For each of these regions try to match it against a set of templates of patterns.
3. Those regions that matched some pattern will be shown with a different color.

To do the first step I had to find the [connected components](http://www.conwaylife.com/wiki/Category:Patterns) of live cells in the grid. I implemented Breadth First Search (BFS) from a specific cell like [this](https://github.com/miguel-vila/conway/blob/7225158399d5ae41d39e6cac2464c1062743d8eb/src/Region.elm#L16-L45) and to identify the contiguous regions of live cells I run it repeatedly like [this](https://github.com/miguel-vila/conway/blob/7225158399d5ae41d39e6cac2464c1062743d8eb/src/Region.elm#L82-L114). Maybe for BFS I'm lacking a proper queue but other than that it didn't turn out that difficult to implement that algorithm in a functional language.

Next I try to match these regions with respect to a set of pattern's templates. First I defined a template as a non empty list of templates and a template is just a non empty list of coordinates. These coordinates should be ordered by increasing `x` and then by increasing `y` (this makes it easier a later comparison). These are the types:

```haskell
type alias Template =
    Cons ( Int, Int )
    
type alias Pattern =
    Cons Template
```

`Cons` is just the type of a non empty list, taken from the [library](http://package.elm-lang.org/packages/hrldcpr/elm-cons/1.0.3/Cons) with the same name.

To match a region against a pattern, we normalize the region by translating it to the origin as close as we can and we look for a template that matches. If some of the pattern's templates is equal to the translated region then it's a match:

```haskell
matchesPattern : Pattern -> Region -> Bool
matchesPattern pattern region =
    let
        minx =
            region
                |> Cons.map .x
                |> Cons.minimum

        miny =
            region
                |> Cons.map .y
                |> Cons.minimum

        normalized =
            region
                |> Cons.map (\{ x, y } -> ( x - minx, y - miny ))
    in
        Cons.any (\p -> p == normalized) pattern
```

This may not be the most efficient way to do this but it's the first thing that came to my mind.

And finally to find out which color, if any, a region must have I wrote something like this:

```haskell
patterns : List Pattern
patterns = ...

colorPalette : List Color
colorPalette = ...

patternsAndColors : List ( Pattern, Color )
patternsAndColors =
    List.Extra.zip patterns colorPalette

getRegionColor : Region -> Maybe Color
getRegionColor region =
    find (\( pattern, _ ) -> matchesPattern pattern region) patternsAndColors
        |> Maybe.map (\( _, color ) -> color)


getRegionsColors : List Region -> List ( Region, Color )
getRegionsColors =
    List.filterMap
        (\region ->
            getRegionColor region
                |> Maybe.map (\color -> region => color)
        )
```

## Conclusion

This was a fun exercise! I enjoyed very much programming in Elm! This exercise didn't have too many side effects, though. Just the random grid generation so I don't know if that model scales to "real" applications. Also this project didn't involve that much component composition (not only composing the views but also the `update` functions and the `Model` types). Nevertheless, Elm is a very cool language and the Elm architecture is fun to follow. I'm not sure if it allows all the kind of patterns that can arise when building more complex applications. But unlike, say Angular, you can understand what's going at each part of your application. No magic binding or anything like that. I don't think I will use Elm at my job but I hope to learn more about it in the future.
