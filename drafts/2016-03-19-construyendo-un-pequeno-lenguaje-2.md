---
title: Construyendo un pequeño lenguaje de programación (Parte 2)
description: Tercera parte de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, Programming languages, State Monad, Construyendo un pequeño lenguaje
---

## Una formulación alterna

Esta parte del artículo supone que el lector sabe que es una monada, que funciones las conforman y cómo el mecanismo de _for-comprehensions_ de Scala permite escribir fácilmente código que use monadas. Y tal vez un poco de familiaridad con la monada de estado.

El tipo de la función `evaluate` es: `Environment => (Environment,V)`. Tal vez algunos hayan visto esto e identificado que esto es precisamente lo que hace la monada de estado. La monada de estado facilita manipular funciones que modifican estado y devuelven valores, precisamente lo que estamos haciendo con el entorno. Una implementación rápida de la monada de estado se muestra a continuación :

```scala
case class State[S,A](get: S => (S,A)) {
    
    def flatMap[B](f: A => State[S,B]): State[S,B] = {
        val newGet: S => (S,B) = { s =>  // (1)
            val (s1,a) = get(s1)         // (2)
            val bState = f(a)            // (3)
            bState.get(s1)               // (4)
        }
        State( newGet )                  // (5)
    }

    // ... otras funciones derivadas de `flatMap` y `state` 
    // como por ejemplo `map`

}

object State {
    
    def state[S,A](a: => A): State[S,A] = State( s => (s,a) )

}
```

En el caso de la monada de estado la función `flatMap` funciona de la siguiente forma:

El objetivo al implementar `flatMap` es dado un `State[S,A]` y una función `A => State[S,B]` retornar un `State[S,B]`. Si desenvolvemos la definición de `State` esto es equivalente a decir: dada una función `S => (S,A)` (el atributo `get`) y una función `A => (S => (S,B))` construir una función de tipo `S => (S,B)`.

Primero en la línea `(1)` declaramos que vamos a construir una función de tipo `S => (S,B)`. En el cuerpo de la función en la línea `(2)` ejecutamos la primera función pasándole el estado incial y con esto obtenemos un nuevo estado y un valor de tipo `A`. Ya teniendo este valor de tipo `A` podemos ejecutar la segunda función (en la línea `(2)`) que a su vez nos devuelve otra función de tipo `S => (S,B)`. Y a esta función le pasamos el estado modificado y con esto obtenemos un `(S,B)` que era lo que queríamos que hiciera la función. Finalmente en la línea `(5)` envolvemos la función.

Esa fue la difícil.

La fácil es la otra función que deben implementar las monadas y es una función que dado un valor lo envuelva en un contexto mínimo. Para esto describimos una función que lee el estado y no lo modifica, solo lo devuelve junto al valor que le pasamos.

Ahora podemos reformular qué significa evaluar una expresión. Como vimos `evaluate` era de tipo `Environment => (Environment, V)`. Vamos a introducir un alias que describa esto en función de `State`:

```scala
type Evaluator[ V <: Value ] = State[ Environment, V ]
```

Y ahora en vez de que las expresiones deban definir una función `evaluate` deberían tener una propiedad de tipo `Evaluator`:

```scala
sealed trait Expression[ V <: Value ] {
  def evaluator: Evaluator[ V ]
}
```

¿Que ganamos con esto?

Como con muchas monadas nos liberamos de un pedazo de carpintería: en este caso es el de pasar el estado modificado. 

Por ejemplo al redefinir las comparaciones llegamos a esto:

```scala
sealed trait Comparison extends BooleanExpression {
  def left: NumberExpression
  def right: NumberExpression

  def combinedWith(
    combine: (NumberValue, NumberValue) => BooleanValue
  ): Evaluator[BooleanValue] = {
    for {
      leftValue  <- left.evaluator
      rightValue <- right.evaluator
    } yield combine(leftValue, rightValue)
  }

}
```

Dentro del _for-comprehension_ se está realizando la pasada de los entornos modificados, pero en nuestro código solo se muestra la lógica de que el evaluador de una comparación es la composición y combinación de los evaluadores de cada lado.

De forma similar también simplificamos los condicionales:

```scala
case class If(
  condition:    BooleanExpression,
  consequence:  VoidExpression,
  alternative:  VoidExpression
) extends VoidExpression {

  val evaluator: Evaluator[Void] =
    for {
      evaluatedCondition <- condition.evaluator
      _                  <- if(evaluatedCondition.value) 
                                consequence.evaluator 
                            else 
                                alternative.evaluator
    } yield Void

}
```

Y `Sequence` se puede reescribir usando el _typeclass_ `Traverse` (`Traverse` y `State` se encuentran en la librería Scalaz):

```scala
case class Sequence(exps: VoidExpression*) extends VoidExpression {

  val evaluator: Evaluator[Void] =
    for {
      _ <- Traverse[List].traverseS_( exps.toList ) (_.evaluator)
    } yield Void

}
```
<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">
La función `traverseU_` hace lo mismo que la más reconocible `traverse_` cuya firma es:

```scala
def traverse_[G[_]:Applicative,A,B](fa: F[A])(f: A => G[B]): G[Unit]
```

`traverse_` hace algo similar a `traverse` solo que no acumula los efectos y por eso retorna un `G[Unit]`. Para contrastar esta es la firma de `traverse`:

```scala
def traverse[G[_]:Applicative,A,B](fa: F[A])(f: A => G[B]): G[F[B]]
```

En Scalaz así como en Haskell existe la convención de usar un `_` para significar que la función no acumula efectos

`traverseU_` tiene la ventaja de que es más fácil de usar sin tener que poner anotaciones de tipos (especificamente _type lambdas_). Se trata de uno de esos tantos [trucos](http://typelevel.org/blog/2013/09/11/using-scalaz-Unapply.html) de Scala que aún no he entendido. 

</div>
</div>

Por supuesto es discutible si esto es mas legible que  