---
title: Sobre Algebraic Data Types y Subtipos
description: Un post corto sobre dos acercamientos distintos: Algebraic Data Types y Subtipos
tags: ADT, OOP, FP, Subtipos
---

Lo que sigue es en su mayoría una divagación y algunos pensamientos sueltos sobre ADTs y subtipos.

En programación funcional existen los tipos de datos algebraícos (o Algebraic Data Types). [Esta](https://tech.esper.com/2014/07/30/algebraic-data-types/) explicación sobre ADTs es buena y pueden encontrar más googleando. El punto es que, en su formulación inicial en lenguajes funcionales, los ADTs consisten en un solo tipo con múltiples constructores. Por poner un ejemplo en Elm podríamos definir un tipo `Filter` así:

```haskell
type Filter = All
            | AssignedTo User
            | CreatedBetween Date Date
```

Esto va a definir que el tipo `Filter` va a tener 3 constructores distintos, cada uno con una firma distinta pero todos devolviendo algo de tipo `Filter`:

```haskell
All            : Filter 
AssignedTo     : User -> Filter
CreatedBetween : Date -> Date -> Filter
```

Y además de ganar 3 constructores distintos también ganamos 3 "desestructuradores" distintos, uno por cada constructor. Esto nos puede resultar útil para implementar lógica que debe actuar sobre algo de tipo `Filter` y que debe hacer algo distinto por cada caso. Por ejemplo:


```haskell
applyFilter : Filter -> List Task -> List Task
applyFilter filter tasks =
    case filter of
        All -> 
            tasks
        AssignedTo user -> 
            List.filter (assignedToIsEqualTo user) tasks
        CreatedBetween start end -> 
            List.filter (wasCreatedBetween start end) tasks
                                                                
assignedToIsEqualTo : User -> Task -> Bool
assignedToIsEqualTo user task = ...
                                                                
wasCreatedBetween : Date -> Date -> Task -> Bool
wasCreatedBetween start end task = ...
```

Ahora, si comparamos esto con el acercamiento de programación orientada a objetos podríamos imaginarnos otra solución al mismo problema. Este acercamiento posiblemente implicará usar subtipos. Por ejemplo, usando el lado OOP de Scala podríamos llegar a esto:

```scala
sealed trait Filter {
    def apply(tasks: List[Task]): List[Task]
}

object All extends Filter {
    def apply(tasks: List[Task]) = tasks
}

case class AssignedTo(user: User) extends Filter {
    def apply(tasks: List[Task]) = ...
}

case class CreatedBetween(start: Date, end: Date) extends Filter {
    def apply(tasks: List[Task]) = ...
}
```

(Conocedores de Scala se darán cuenta de que podríamos haber hecho lo mismo que en Elm con _pattern matching_ pero ese no es el punto acá.)

En este caso creamos una jerarquía de tipos y logramos hacer más o ménos lo mismo. Esto es para mostrar un poco la idea de que en programación orientada a objetos la forma tradicional de describir variaciones es mediante subtipos mientras que en programación funcional mediante constructores y "desestructuradores".

## Ménos peor y más mejor

Ahora, ¿cuál es mejor o peor? En el anterior ejemplo es muy difícil de decir. Creo que en OOP se prefiere la invocación de métodos a la aplicación de funciones. La razón de esto es que al invocar un método abstracto uno no tiene que preocuparse por implementar ese pedacito que determina cuál implementación es la real. Para eso está la jerarquía de tipos que describimos. En cambio en el acercamiento funcional es responsabilidad del programador usar _pattern matching_ para determinar cuál es la implementación adecuada para cada variante. Este mecanismo de _pattern matching_ se puede hacer más seguro en algunos lenguajes funcionales activando chequeos de exhaustividad. Pero más allá de esa incomodidad me resulta difícil decir cuál acercamiento es mejor o peor.

Sobre subtipos y herencias se me ocurre una desventaja: en jerarquías altas de clases resulta difícil seguir la traza de un método y se terminan creando torres de complejidad. Pero por otra parte se me hace que hablar de la relación "es subtipo de" resulta útil para describir ciertos dominios. En esos casos se me hace adecuado y son precisamente estos los casos en los que se me hace difícil encontrar alguna ventaja o desventaja con respecto al acercamiento de tener ADTs.

Uno de los beneficios adicionales que tiene crear jerarquías de tipos es que permiten heredar métodos y por lo tanto propagar implementaciones para distintos tipos. Por lo general esto es útil cuando la implementación base solamente accede al mínimo común denominador de la jerarquías: a ese subconjunto de funcionalidades que todo subtipo hereda. Por lo tanto uno quisiera escribir el método que los use una sola vez y permitir que los subtipos lo hereden. Hacer esto con ADTs es más complicado: se me ocurren funciones que extraen lo común de las distintas variantes y funciones que operan sobre ese mínimo común denominador (O si a un lector se le ocurre una mejor forma es bienvenida). Este es uno de los pocos casos que se me ocurren donde la herencia hace algo mejor que los ADTs. Pero al mismo tiempo habrá gente que dirá que la herencia es una fuente de complejidad y la contra-respuesta habitual es "solo si la herencia se usa mal".

## Restringiendo funciones

Por otra parte en ocasiones está la necesidad de que una de las variantes tenga una funcionalidad que las demás no tienen. En estos casos el acercamiento podría dar la aparencia de fallar, dado que un ADTs describe únicamente un tipo. Para hacer la cosa más concreta imaginémos un juego en el que la partida puede estar en uno de tres estados: un juego activo, un juego empatado o un juego ganado por alguno de los jugadores. En Elm podríamos tener algo como esto:

```haskell
type Game = StartedGame Board Player
          | DrawnGame Board
          | WonGame Board Player
```

Ahora digamos que queremos implementar una función que ejecuta el movimiento de un jugador. Esta función solamente debería funcionar sobre juegos que estén activos. La firma de una primera aproximación podría ser algo como:

```haskell
play : Game -> PlayerMove -> Game
```

Pero resulta que esta función solamente tiene sentido cuando el juego es uno que se encuentra en curso. Debido a que tenemos un solo tipo no podemos restringir la función para que sirva solamente sobre esa variante. La solución es tener tipos distintos por cada variante:

```haskell
type alias Active = { userPlayer : Player
                    , currentPlayer: Player
                    , board : Board
                    }
                                                               
type alias Won = { userPlayer : Player
                 , winner : Player
                 , board : Board
                 }
                                                                                                                  
type alias Drawn = { board : Board }

type Game = ActiveGame Active
          | WonGame Won
          | DrawnGame Drawn
```

Y así podemos tener una función que solamente funciona sobre la variante que nos interesa:

```haskell
play : Active -> PlayerMove -> Game
```

Sin mucha sorpresa esto es fácil de hacer con subclases. Solo hay que hacer que la subclase implemente el método deseado.

Todo esto es para decir que este otro caso de uso es soportado tanto por ADTs como por subtipos.

## ¿Conclusión?

Llegamos al final de este _post_ al punto en el debería concluir algo pero la verdad es que no se me ocurre nada. Ambos acercamientos se me hacen similares en capacidades. Es verdad que ambos determinan estílos completamente distintos de invocación. Pero esa me termina pareciendo una preferencia estética excepto en los casos dónde hay mutabilidad. En esos casos si preferiría tener un método junto a la información que es modificada, es decir el acercamiento de OOP. Pero más allá de eso ambos se me hacen muy similares.

Creo que es una cuestión de preguntarse si los usos más avanzados de la herencia valen la pena. Me gusta el acercamiento de ADTs por su simplicidad: solamente son funciones constructoras y "deconstructoras" sobre un solo tipo. Y a partir de esos principios uno construye su sistema. Esa simplicidad se puede obtener muy similarmente con subtipos.

¿Alguna opinión o respuesta?
