---
title: Algo de lo que hice esta semana (22/01/2016 - 29/01/2016)
description: Algo de lo que hice esta semana (22/01/2016 - 29/01/2016)
tags: Vida
---

Esta semana terminé de leer [_El hombre duplicado_](https://en.wikipedia.org/wiki/The_Double_(Saramago_novel)) de Saramago. No sé como describir la cosa, si decir si me gustó o no. Puedo decir que en su mayoría me gustó.  Ahora recuerdo que la película [_Enemy_](http://www.imdb.com/title/tt2316411), dirigida por Denis Villeneueve, es basada ligeramente en este libro, aunque creo con un distinto desenlace y enfoque. Ahora voy a empezar [_Sunset Park_](https://www.goodreads.com/book/show/7944987-sunset-park) de Paul Auster.

También terminé el [libro](http://underscore.io/books/shapeless-guide/) sobre [_shapeless_](https://github.com/milessabin/shapeless) que estaba leyendo. Puntos positivos: se enfoca en como usar la librería para hacer cosas útiles y la hace menos intimidante. El único punto negativo que le encuentro es que no tiene ejercicios que le permitan a uno validar si de verdad está entendiendo las cosas. 

Un detalle curioso: hablan del "patrón lema" que no es otra cosa que reusar operaciones ya existentes para implementar nuevas. El nombre del patrón se origina en las matemáticas: un lema se da cuando para demostrar ciertos teoremas se usan otros teoremas. Estos teoremas, que en el contexto de una demostración ayudan a demostrar otro teorema se denominan lemas. Reusar este término tiene una apariencia pedante para algo que como programadores hacemos en cada momento: invocar otras funciones para implementar otras funciones. Pero aquí el reuso tiene un significado distinto por que los "ops" corresponden a afirmaciones sobre los tipos. El ejemplo que ponen en el libro es el de implementar un "op" para extraer el penúltimo valor de un `HList`, reusando un "op" para sacar el segmento inicial de un `HList` y otro para sacar el último valor. En codigo:

```scala
import shapeless.ops.hlist

implicit def hlistPenultimate[L <: HList, M <: HList, O](
  implicit
  init: hlist.Init.Aux[L, M],
  last: hlist.Last.Aux[M, O]
): Penultimate.Aux[L, O] =
  new Penultimate[L] {
    type Out = O
    def apply(l: L): O =
      last.apply(init.apply(l))
                        
  }
```

En este contexto el "lema" es la existencia de un `Init` y un `Last` y el "teorema" es la existencia de un `Penultimate`.

Por otra parte usé [Elm](http://elm-lang.org/) para graficar el problema del [día 8 de _Advent Of Code_](http://adventofcode.com/2016/day/8):

<SCRIPT type="text/javascript" src="../code/elm-adv-8.js"></script>

<div id="elm-adv-8"></div>

<script type="text/javascript">
Elm.Main.embed(document.getElementById("elm-adv-8"));
</script>

Ví [_Denial_](http://www.imdb.com/title/tt4645330/) sobre el juicio por difamación de David Irving, un negacionista del holocausto. El título tiene multiples connotaciones. Por una parte está la obvia sobre los negacionistas del holocausto. Pero también hay otras instancias: la del racista que jura no serlo y la de la historiadora, Deborah Lipstadt, que decide negarse su derecho a expresarse para que los abogados puedan hacer su trabajo. Me quedo con la escena en la que conversan esto último.

Este Domingo no salí en bici con mis amigos. Uno de ellos no iba a poder ir entonces creo que esto nos sirvió de excusa a los demás para no salir. Con sinceridad fue más pereza que otra cosa.
