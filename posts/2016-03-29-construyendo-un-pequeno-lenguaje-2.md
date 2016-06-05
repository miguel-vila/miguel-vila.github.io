---
title: Construyendo un pequeño lenguaje de programación (Parte 2)
description: Tercera parte de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, Programming languages, State Monad, Construyendo un pequeño lenguaje
---

En el [anterior _post_](http://miguel-vila.github.io/posts/2016-03-20-construyendo-un-pequeno-lenguaje-1.html) vimos como evaluar las expresiones de nuestro pequeño lenguaje. En este _post_ vamos a aprovechar un patrón funcional para hacer lo mismo que antes pero con ciertas facilidades. Vamos a retomar el mismo acercamiento de _big-step semantics_ pero lo vamos a desarrollar de otra forma.

Este _post_ asume que el lector sabe qué es una monada, qué funciones define, por qué son útiles y cómo el mecanismo de _for-comprehensions_ de Scala permite escribir fácilmente código con ellas. Si el lector no está familiarizado con esos temas aquí hay algunos enlaces:

* [Este](https://www.youtube.com/watch?v=Mw_Jnn_Y5iA) video es una buena introducción. Empieza con monadas como `Option` y `Validation` y trata el tema de _for-comprehensions_.
* Si ya están familiarizados con monadas pero no saben que son _for-comprehensions_ en Scala en [este](https://youtu.be/Mw_Jnn_Y5iA?t=20m39s) punto del anterior video lo explican.
* [Este artículo](http://blog.jle.im/entry/inside-my-world-ode-to-functor-and-monad.html) me gusta mucho (advertencia: es en Haskell).
* En general el mejor consejo que puedo dar para entender monadas es leer y escribir mucho código que las usen. Creo que solo con la práctica uno llega a apreciar la utilidad de algo que inicialmente parece muy abstracto.

Ya suponiendo que saben esto podemos empezar.

## Una monada escondida en `evaluate`

El tipo de la función `evaluate` que definimos en el anterior _post_ es: `Environment => (Environment,V)`. Tal vez algunos hayan visto esto e identificado que esto es precisamente lo que hace la **monada de estado**. La monada de estado facilita manipular funciones que modifican un estado y devuelven valores, que es justo lo que estamos haciendo con el entorno. 

Cómo muchas otras, la monada de estado está implementada como un _"wrapper"_ sobre una función:

```scala
case class State[S,A](run: S => (S,A)) {
  ...
}
```

En este caso estamos abstrayendo funciones que representan modificaciones de estado y que devuelven un valor, es decir cosas del tipo `S => (S,A)` donde `S` es el tipo que representa el estado y `A` es un valor de retorno de una modificación. El beneficio de abstraer algo como esto es que vamos a ganar mucho código cuya única funcionalidad es pasar de un lado a otro un estado y esto nos va a permitir concentrarnos en la lógica específica de nuestro problema.

Como todas las monadas debemos implementar dos funciones: una especie de constructor (usualmente llamado `unit`, en nuestro caso lo llamarémos `state`) y una especie de "secuenciador" (usualmente llamado `bind` o en el caso de Scala llamado `flatMap`)

Empecemos por `flatMap`. El significado de esta función en el caso de la monada de estado es mas o menos el siguiente: 

> Dada una modificación de estado que devuelve un valor y dada una forma de construir otra modificación de estado según ese valor creé una nueva modificación de estado que sea la sucesión de ambas.

En código, mas concretamente, esto significa: dado un `State[S,A]` y una función `A => State[S,B]` retornar un `State[S,B]`. Si desenvolvemos la definición de `State` esto es equivalente a decir dadas: 

* Una función `S => (S,A)` (el atributo `run`)
* Una función `A => (S => (S,B))`

construir una función de tipo `S => (S,B)`.

Veamos como podemos implementar esto línea a línea:

```scala
case class State[S,A](run: S => (S,A)) {
    
    def flatMap[B](f: A => State[S,B]): State[S,B] = {
        val newRun: S => (S,B) = { s =>  // (1)
            val (s1,a) = run(s)          // (2)
            val bState = f(a)            // (3)
            bState.run(s1)               // (4)
        }
        State( newRun )                  // (5)
    }

}
```

En la línea `(1)` declaramos que vamos a construir una función de tipo `S => (S,B)`. En el cuerpo de la función en la línea `(2)` ejecutamos la primera modificación de estado (`run`) pasándole el estado inicial y con esto obtenemos un nuevo estado y un valor de tipo `A`. Ya teniendo este valor de tipo `A` podemos ejecutar la función `f` (en la línea `(3)`) que a su vez nos devuelve otra función de tipo `S => (S,B)`. Y a esta función le pasamos el estado modificado (en la línea `(4)`) y con esto obtenemos un `(S,B)` que era lo que queríamos que hiciera la función. Finalmente en la línea `(5)` envolvemos la función dentro de un `State`.

Esa fue la difícil.

La fácil es la otra función que deben implementar las monadas. Se trata de una función que dado un valor lo envuelva en un contexto mínimo que produzca ese valor dentro de la monada. Para esto describimos una función `state` que lee el estado y no lo modifica, solo lo devuelve junto al valor que le pasamos:

```scala
object State {
    
    def state[S,A](a: => A): State[S,A] = State( s => (s,a) )

}
```

También podemos implementar `map` que simplemente transforma el valor de retorno de la modificación:

```scala
case class State[S,A](run: S => (S,A)) {
    
    def map[B](f: A => B): State[S,B] = ???

}
```

Pueden implementar esta función como ejercicio. Hay dos formas de hacerlo: una es como todas las monadas pueden hacerlo y consiste en combinar `flatMap` y `state` de cierta forma. Otra forma es un poco más explícita y no reutliza ninguna de las funciones.

El caso es que una vez definidas las funciones `flatMap` y `map` podemos escribir _for-comprehensions_ que manipulen cosas de tipo `State`.

## Una formulación alterna

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

## ¿Que ganamos con esto?

Como con muchas monadas nos liberamos de un pedazo de "carpintería": en este caso es el de pasar el estado modificado de función en función. 

Por ejemplo al redefinir las comparaciones llegamos a esto:

```scala
sealed trait Comparison extends Exp[BooleanValue] {
  def left:  Exp[NumberValue]
  def right: Exp[NumberValue]

  def comparedWith(
    compare: (NumberValue, NumberValue) => BooleanValue
  ): Evaluator[BooleanValue] = {
    for {
      leftValue  <- left.evaluator
      rightValue <- right.evaluator
    } yield compare(leftValue, rightValue)
  }

}

case class LessThan(left: Exp[Number], right: Exp[Number]) extends Comparison {
  val evaluator = comparedWith(_ < _)
}

// ... las otras comparaciones son similares
```

Dentro del _for-comprehension_ se está realizando la pasada de los entornos modificados, pero en nuestro código solo se muestra la lógica de que el evaluador de una comparación es la composición y combinación de los evaluadores de cada lado.

De forma similar también simplificamos los condicionales:

```scala
case class If(
  condition:    Exp[BooleanValue],
  consequence:  Exp[Void],
  alternative:  Exp[Void]
) extends Exp[Void] {

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

Y la forma de evaluar un `Sequence` se puede reescribir usando el _typeclass_ [`Traverse`](https://wiki.haskell.org/Foldable_and_Traversable#Traversable) (`Traverse` y `State` se encuentran en librerías de patrones funcionales como [Scalaz](https://github.com/scalaz/scalaz/) o [Cats](https://github.com/typelevel/cats/)):

```scala
case class Sequence(exps: Exp[Void]*) extends Exp[Void] {

  val evaluator: Evaluator[Void] =
    for {
      _ <- Traverse[List].traverseS_( exps.toList ) ( _.evaluator )
    } yield Void

}
```

El _typeclass_ `Traverse` sirve para recorrer una estructura (en este caso `List`) realizando algún efecto (en este caso `State`). La función `traverseS_` es una especialización cuando el efecto es `State`. Pueden imaginarse que lo que hace esta función es algo como lo siguiente:

```scala
def traverseS_[S,A,B](list: List[A])(f: A => State[S,B]): State[S,Unit] = {
  
  f(list(0)).flatMap { _ =>
    f(list(1)).flatMap { _ =>
      f(list(2)).flatMap { _ =>
        ...
          f(list(n)).map { _ =>
            ()
          }
        ...
      }
    }
  }

}
```

En realidad esta función [se puede implementar sin `flatMap`](http://www.staff.city.ac.uk/~ross/papers/Applicative.pdf), pero la idea acá es ilustrar que lo que hace es secuenciar los efectos. En el caso de `State` esto significa ir pasando el entorno actualizado de función en función hasta formar una gran función que sea la secuencia de todas. 

Este es uno de los tantos ejemplos de la utilidad de patrones funcionales que a primera vista resultan abstractos: ganamos pedazos de código muy generales, que no son específicos a nuestro dominio, y con esto logramos atacar el problema que nos corresponde.

<!--div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
La función `traverseS_` es una especialización de `traverse_` para `State`. En Scalaz así como en Haskell existe la convención de usar un `_` para indicar que la función hace algo similar a la versión sin `_` pero sin acumular los resultados de los efectos. Por ejemplo en el siguiente código si `g` retorna un `G[Unit]` entonces el tipo de 

```scala
Traverse[List].traverse(list)(g)
``` 

es `G[List[Unit]]`. Construir una lista con valores `Unit` no parece útil y en ocasiones un efecto no tiene un valor de retorno significativo. Para eso está la alternativa con `_`. El tipo de: 

```scala
Traverse[List].traverse_(list)(g)
``` 

 es `G[Unit]`.
</div>
</div-->

Retomando podemos ver que en contraste implementar el evaluador de un literal es más simple:

```scala
trait Literal[ V <: Value ] extends Exp[V] {
  def value: V
  val evaluator: Evaluator[V] = State.state(value)
}
```

Para implementar otros evaluadores es útil definir algunas funciones utilitarias:

```scala
object State {
  
  /**
    * Construye un `State` a partir de una función que solamente modifica el estado
   */
  def modify[S](mod: S => S): State[S,Unit] = State( s => ( mod(s), () ) )

  /**
    * Construye un `State` que lee un atributo del estado
   */
  def gets[S,A](get: S => A): State[S,A] = State( s => ( s, get(s) ) )

}
```

Con esto podemos definir otros evaluadores, por ejemplo:

```scala
case class Assign(name: String, expression: Exp[ _ <: Value ]) extends Exp[Void] {
  val evaluator: Evaluator[Void] =
    for {
      value <- expression.evaluator
      _     <- State.modify { s: Environment => s + (name -> value) }
    } yield Void
}

trait Variable[ V <: Value ] extends Exp[V] {
  def name: String
  val evaluator: Evaluator[V] = 
    State.gets[Environment, V] { env => env(name).asInstanceOf[V] }
}
``` 

Pueden ver los evaluadores de las otras expresiones [acá](https://github.com/miguel-vila/understanding-computation/blob/master/src/main/scala/understanding_computation/chapter2/ast/Expression.scala), aunque tal vez el código no esté tan organizado.

## Concluyendo

Por supuesto es discutible si todo esto es mas legible que lo que teníamos antes. Creo que en ocasiones al discutir estas cosas confundimos legibilidad con familiaridad. Para una persona que no esté familiarizada con estos patrones este código puede resultar abstracto, pero eso no quiere decir que no sea legible. Muchos patrones funcionales no son tan complicados, son formalizaciones de cosas que veníamos haciendo en otros lenguajes. Y una vez nos familiarizamos con estos patrones los encontramos legibles y hasta naturales.

En la próxima entrada vamos a ver como leer una cadena de texto (el contenido de un archivo por ejemplo) para convertirlo en un arbol de sintáxis de nuestro lenguaje.