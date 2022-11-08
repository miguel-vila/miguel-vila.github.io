---
title: Desarmando las Promesas y los Futuros de la librería estándar de Scala
description: ¿Cómo están implementadas las promesas y los futuros en la librería estándar de Scala?
tags: Scala, Functional Programming, Monads, Concurrency, Futures, Promises, Async
---

> "What I cannot create I do not understand" - Richard Feynman

## La misma idea, una y otra vez

Hay una idea que he visto varias veces en [sistemas de eventos que se pueden componer](https://twitter.com/conal/status/468875014461468677). Es bastante simple y consiste en separar un flujo de eventos en dos partes:

* Un lado de escritura bastante [imperativo](https://en.wikipedia.org/wiki/Imperative_programming) y dado a producir [efectos secundarios](https://en.wikipedia.org/wiki/Side_effect_(computer_science))
* Un lado de lecturas bastante [funcional](http://blog.jenkster.com/2015/12/what-is-functional-programming.html) desde el que se pueden combinar flujos de eventos

[//]: <> (He visto tres instancias de esta idea:)

[//]: <> (### (1) `Observer` y `Observable`s en Reactive Extensions)

[//]: <> ([Reactive extensions](http://reactivex.io/) es una librería "para programar asíncronamente con flujos de observables". Es más o ménos una elaboración del patrón _Observer_ y sirve para componer flujos de eventos. En Reactive extensions [los observables pueden ser vistos como funciones que toman la referencia a un observador](https://medium.com/@benlesh/learning-observable-by-building-observable-d5da57405d87#.uhk9wj89c) y eventualmente le reportan eventos o errores o la finalización. El observable asbtrae el flujo de eventos que se le reportan al observador. El observador debe ser algo que soporte 3 funciones: `onNext`, `onError` y `onCompleted`. Estas funciones reciben datos (excepto la última, que no recibe nada) y no devuelven nada, es decir seguramente realizan efectos secundarios. En cambio los operadores que tiene un Observable (que son [muchos](http://reactivex.io/documentation/operators.html)) son "funcionales": reciben parámetros y retornan otros Observables.)

[//]: <> (### (2) `Address` y `Signal` en elm)

[//]: <> ([elm](http://elm-lang.org/) es un lenguaje de programación funcional para hacer interfaces de usuario y que tiene elementos de "Functional Reactive Programming".)

[//]: <> (Un [`Mailbox`](http://package.elm-lang.org/packages/elm-lang/core/3.0.0/Signal#Mailbox), que es como un punto de comunicación, está compuesto de dos elementos:)

[//]: <> (```elm)
[//]: <> (type alias Mailbox a =)
[//]: <> (    { address : Address a)
[//]: <> (    , signal : Signal a)
[//]: <> (    })
[//]: <> (```)

[//]: <> (`address` es el lado de "escritura" y hacia él se pueden enviar mensajes. Para esto está la función [`send`](http://package.elm-lang.org/packages/elm-lang/core/3.0.0/Signal#send) que devuelve un `Task`, la representación de efectos secundarios en elm.)

[//]: <> (En cambio `signal` es un valor "reactivo", similar a los observables de Reactive extensions, que sirve para "escuchar" los eventos que se han enviado al _mailbox_. `Signal` tiene todos los combinadores funcionales usuales: `map`, `map2`, `filter`, `foldp` y otros propios de `Signal`s como `merge` o `dropRepeats`.)

He visto varias instancias de esta "idea": por ejemplo `Observer` y `Observable` en [Reactive extensions](http://reactivex.io/) o `Address` y `Signal` en [elm](http://elm-lang.org/) (esto hasta la [versión 0.16](http://elm-lang.org/blog/farewell-to-frp)). Uno de los ejemplos más simples son las promesas y los futuros en la librería estándar de Scala. Un Futuro es el resultado eventual de una computación y una Promesa es una variable que se puede completar con un valor exitoso o con un error. Las Promesas juegan el papel del lado de "escritura" y los Futuros el lado de "lectura".

Los Futuros sirven para componer valores eventuales. Permiten hacer computaciones concurrente o paralelamente. Creo que [esta](http://danielwestheide.com/blog/2013/01/09/the-neophytes-guide-to-scala-part-8-welcome-to-the-future.html) es una explicación muy buena de los futuros y de como se usan. [Este](https://blog.jcoglan.com/2013/03/30/callbacks-are-imperative-promises-are-functional-nodes-biggest-missed-opportunity/) otro artículo habla de por que usar futuros es una mejor alternativa a usar _callbacks_ sueltos. Este último artículo es en el contexto de node.js pero las mismas ideas aplican en otras tecnologías.

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Para evitar confusiones hay que aclarar que en el mundo de JavaScript llaman promesas lo que en Scala llamamos futuros.
</div>
</div>

Por otra parte el objetivo del presente artículo es desarmar la implementación de futuros de la librería estándar y comprender como se mueven las distintas partes. Éste artículo supone que el lector los ha usado aún sin entender como funcionan por debajo.

## Desarmando los Futuros y las Promesas

La implementación de Futuros y Promesas de la librería estándar tiene ciertas partes complicadas, sobre todo con respecto a la organización de las definiciones. Sin embargo creo que se puede entender la mayoría si uno tiene en cuenta la idea del lado de escritura y lectura. Con propósitos didácticos hice [una re-escritura](https://github.com/miguel-vila/grupo-concurrencia-paralelismo/tree/b0cd2b63a3daa41bcdc31c1a5b4850ba5c8007df/futuro-y-promesa) de los Futuros y Promesas removiendo hasta dejar lo más básico y simplificando algunas partes y a esa es a la que me referiré en este artículo.

Entonces veamos como se podría construir nuestra propia implementación de promesas y futuros:

## Las interfaces de los dos lados

Empecemos por el Futuro, que es el lado de lectura. Inicialmente va a tener un método que permite agregar un _callback_ cuando el Futuro emita algún valor, sea exitoso o fallido, para lo cuál aprovechamos el tipo `Try`:

```scala
trait Futuro[T] {

  def onComplete(f: Try[T] => Unit)(implicit executionContext: ExecutionContext): Unit

}
```

Recibe una función que lee el resultado y hace algo con ella e implícitamente recibe un [`ExecutionContext`](http://www.scala-lang.org/api/2.10.3/#scala.concurrent.ExecutionContext), que es una especie de _pool_ de _threads_, dónde se va a ejecutar la función eventualmente.

Este es el lado de lectura aunque por ahora se ve muy imperativo. Esto cambiará muy pronto gracias a la interacción con el lado de escritura.

La Promesa por su parte es el lugar donde se almacena el resultado de una computación eventual. Tiene una interfaz muy simple:

```scala
trait Promesa[T] {

  def futuro: Futuro[T]

  def complete(value: Try[T]): Boolean

}
```

Tiene una propiedad de tipo `Futuro`, es decir del lado de lectura de la variable, y tiene una función `complete` que permite escribir la variable, sea con un valor exitoso o fallido. Esta última función devuelve un booleano indicando si se pudo hacer la escritura dado que nadie haya escrito la variable antes. Si se llama `complete` por segunda vez ese intento de escritura falla y retorna `false`. Se suele decir que una promesa ha sido "resuelta" cuando alguien ha escrito un valor exitoso. De forma similar se dice que ha sido "rechazada" si el valor con el que se ha escrito es erróneo.

## _Wishful thinking_

En este punto, con algo de _wishful thinking_, ya podemos empezar a implementar los combinadores funcionales. Imaginémos que tenemos alguna implementación de `Promesa` y `Futuro` con las interfaces de arriba y que podemos construir una promesa sin completar. Con esto ya podríamos describir `map`, uno de los combinadores funcionales más comúnes:

```scala
trait Futuro[T] {

  def onComplete(f: Try[T] => Unit)(implicit executionContext: ExecutionContext): Unit

  def map[S](f: T => S)(implicit executionContext: ExecutionContext): Futuro[S] = {
    // Define una promesa del tipo esperado S
    val promesa = Promesa[S]()
    onComplete {
      case Success(t) =>
        // "Lee" el valor del futuro actual y con ese valor
        // ejecuta la función f para obtener un valor con
        // el que escribir la promesa:
        val value = try { Success( f(t) ) } catch { case NonFatal(error) => Failure(error) }
        promesa.complete( value )
      case Failure(error) =>
        // Si el futuro actual es fallido escribimos la
        // misma falla en el nuevo futuro
        promesa.complete( Failure(error) )
    }
    // Al final devolvemos el lado de lectura de la promesa
    promesa.futuro
  }

}
```

Otro combinador funcional como `flatMap` se puede describir con un patrón similar pero con ciertas diferencias. Dejémoslo por aparte por ahora y veamos como se implementarían los tipos `Futuro` y `Promesa`.

## El estado de una promesa

Resulta que esto no es tan complicado. Una computación eventual puede estar en dos estados: o pendiente o completada, sea con un valor o con un error. Más aún puede que alguien haya programado la ejecución de una función que use el valor de la promesa cuando esta sea completada. Debido a esto en el estado pendiente tenemos que persistir estos pedidos. Materializando esto en tipos tenemos lo siguiente:

```scala
sealed trait EstadoPromesa[T]
case class Completada[T](value    : Try[T]           ) extends EstadoPromesa[T]
case class Pendiente [T](callbacks: List[Callback[T]]) extends EstadoPromesa[T]
```

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
En la implementación de verdad hay un [tercer posible estado](https://github.com/scala/scala/blob/804a4cc1ff9fa159c576be7c685dbb81220c11da/src/library/scala/concurrent/impl/Promise.scala#L126). Se trata de una optimización para disminuir el consumo de memoria. Éste es un detalle que no entiendo completamente pero lo demás se puede entender sin esto.
</div>
</div>

Aquí `Callback` es algo que lee el valor resuelto y se va a ejecutar en algún `ExecutionContext`:

```scala
class Callback[T](callback: Try[T] => Unit, executionContext: ExecutionContext) {

  def executeWith(value: Try[T]): Unit = executionContext.execute(new Runnable {
    override def run(): Unit = {
      try {
        callback(value)
      } catch {
        case NonFatal(t) => executionContext.reportFailure(t)
      }
    }
  })

}
```

En este punto les debería sonar el tipo `Try[T] => Unit`. El método `executeWith` es el que se llamará eventualmente cuando la promesa se resuelva y simplemente programa, en el `ExecutionContext`, la ejecución de la función pasándole el valor.

## Una simple descomposición

Armados con esto lo demás sigue más o menos fácilmente. Cuándo se instancie una promesa iniciará en el estado `Pendiente`.  Si, estando en este estado alguien programa la ejecución de un pedido con `onComplete` entonces debemos incluir este pedido en el estado (el atributo `callbacks`). Pero si alguien llama `complete` cuando estamos en el estado `Pendiente` pasamos a `Completada`, almacenamos ese valor y podemos ejecutar los _callbacks_ que teníamos en el estado `Pendiente`. Y si alguien llama `onComplete` en el estado `Completada` podemos ejecutar ese _callback_ directamente. Esencialmente tenemos esta maquina de estados:

<img src="/images/diagrama-estado.png" style="margin-left: auto; margin-right: auto; display: block;">

## Estado y concurrencia

Como tal vez sospechen la cosa no es tan simple como tener una referencia mutable de tipo `EstadoPromesa`. Esto se podría prestar para multiples [condiciones de carrera](https://en.wikipedia.org/wiki/Race_condition). Por ejemplo ¿Qué podría pasar si se llama `onComplete` mas de una vez y al mismo tiempo sobre una promesa que no ha sido resuelta? Si la actualización del estado no se hace atómicamente podríamos correr el riesgo de que uno de los _callbacks_ se pierda.

Debido a esto necesitamos proteger el estado contra estas condiciones de carrera. Una forma de hacerlo es con candados, pero este acercamiento tiene la gran desventaja de ser bloqueante y además es demasiado pesimista. Las situaciones en las que se le agreguen multiples _callbacks_ a un mismo futuro son posibles pero no tan recurrentes, y ménos aún que se hagan al mismo tiempo. Por lo general cuando usamos un futuro le agregamos un número fijo de _callbacks_ y seguimos encadenando llamadas con nuevos futuros. Pero no es común usar multiple y concurrentemente un mismo futuro. Sin embargo esta situación es posible y deberíamos protegernos contra ella. Es solo que los candados son un método demasiado "paranoico" en este caso.

Hay un acercamiento más optimista: suponemos que al hacer la actualización no va a haber la interferencia de otro hilo y procedemos a la modificación. Si detectamos alguna interferencia no hacemos "commit" de la actualización y reintentamos. Este es el acercamiento que tienen [las variables atómicas](http://www.ibm.com/developerworks/library/j-jtp11234/) en Java, que aprovechan la primitiva [_Compare-and-swap_](https://en.wikipedia.org/wiki/Compare-and-swap). Las referencias atómicas tienen un mejor _throughput_ que los candados durante situaciones de moderada [contención](http://stackoverflow.com/a/7064008). Y en situaciones de alta contención tienen un _throughput_ similar. Si quieren ahondar en este tema sugiero el capítulo 15 del libro ["Java Concurrency in Practice"](http://jcip.net/).

Dado esto, en vez de utilizar una referencia mutable de tipo `EstadoPromesa` vamos a tener algo de tipo `AtomicReference[ EstadoPromesa ]` y vamos a usar los métodos [`get`](https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicReference.html#get()) y [`compareAndSet`](https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/atomic/AtomicReference.html#compareAndSet(V,%20V)) para consultar y modificar el estado respectivamente. El método `compareAndSet` amerita una breve explicación. Recibe dos valores: el valor que se espera que va a ser el actual y el que queremos que sea el nuevo. Si el estado de la referencia atómica coincide con el que esperabamos la modificación procede y retorna `true`. En caso contrario la modificación no se hace y retorna `false`. Esto nos da la oportunidad para reintentar, y por lo que describí anteriormente el número de reintentos no debería ser muy alto, dados los patrones comunes de uso de los futuros.

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Cuando se usa _Compare-and-swap_, dependiendo de la estructura del problema a resolver, se puede dar una condición llamada el [problema ABA](https://en.wikipedia.org/wiki/ABA_problem). En los cambios de estado de las promesas no se puede dar este error, dado que los cambios se dan en una sola dirección. Es decir nunca se puede dar la situación de cambiar de vuelta a un estado anterior.
</div>
</div>

## La estructura de la implementación

Resulta que la diferenciación entre `Futuro` y `Promesa` resulta útil para los usuarios externos de la librería. Sin embargo tanto `onComplete` como `complete` necesitan acceder al estado de la computación. Debido a esto nuestro tipo implementación puede tener la siguiente definición:

```scala
class PromesaImpl[T]
  extends AtomicReference[EstadoPromesa[T]](Pendiente(List.empty))
  with Promesa[T]
  with Futuro[T] {

  override def futuro: Futuro[T] = this

  // implementación de `complete` y `onComplete`

}
```

Como podrán notar heredamos de `AtomicReference` e iniciamos en el estado `Pendiente` con una lista vacía de _callbacks_.

## Programando tareas futuras

Primero veamos como podemos construir `onComplete`. Podemos implementar una función con esta firma:

```scala
def onComplete(callback: Callback[T]): Unit
```

y con ella podemos construir la función con la firma familiar:

```scala
def onComplete(f: Try[T] => Unit)(implicit executionContext: ExecutionContext): Unit = {
  val callback = new Callback(f,executionContext)
  onComplete(callback)
}
```

Esto se reduce a inspeccionar el estado de la promesa: si ya está resuelta pedimos inmediatamente la ejecución del _callback_. Si está `Pendiente` agregamos, atomicamente, el _callback_ a la lista:

```scala
@tailrec
private def onComplete(callback: Callback[T]): Unit = {
  get() match {
    case Completada(value)                          =>
      callback.executeWith(value)
    case currentState @ Pendiente(currentCallbacks) =>
      if(compareAndSet(currentState, Pendiente( callback :: currentCallbacks )))
        ()
      else
        onComplete(callback)
  }
}
```

Es  importante notar que:

* `get` y `compareAndSet` son métodos heredados de `AtomicReference`.
* Si en medio de inspeccionar el estado y modificarlo detectamos la interferencia de otro hilo, debido a que `compareAndSet` retorne `false`, reintentamos.

## Escribiendo la promesa

Para escribir la promesa, suponiendo que no ha sido resuelta anteriormente, hay que tener en cuenta que además de cambiar de `Pendiente` a `Completada` debemos recordar el listado de _callbacks_, para ejecutarlos con el valor resuelto. Para esto creamos el método `getCallbacksAndSetValue` que funciona recibiendo un valor con el que escribirá la promesa y devolverá una lista de _callbacks_. Pero también hay que tener en cuenta el caso en el que este método se llame sobre una promesa resuelta. Debido a esto nuestro tipo de retorno será `Option[List[Callback]]`:

```scala
@tailrec
private def getCallbacksAndSetValue(value: Try[T]): Option[List[Callback[T]]] = {
  get() match {
    case Completada(_)                              =>
      None
    case currentState @ Pendiente(currentCallbacks) =>
      if (compareAndSet(currentState, Completada(value))) {
        Some(currentCallbacks)
      } else {
        getCallbacksAndSetValue(value)
      }
  }
}
```

En esta función retornar `None` nos sirve para indicar que la promesa ya había sido escrita anteriormente y `Some` de una lista para indicar que la promesa fué resuelta y al mismo tiempo devolver la lista de _callbacks_. Es importante notar que, al igual que `onComplete`, esta función modifica el estado atómicamente.

Ahora podemos implementar `complete` de una forma muy sencilla:

```scala
def complete(value: Try[T]): Boolean = {
   getCallbacksAndSetValue(value) match {
     case None            =>
      false
     case Some(callbacks) =>
      callbacks.foreach(_.executeWith(value))
      true
   }
 }
```

Y ese es el corazón de como funcionan las promesas y los futuros en la librería estándar. Lo demás es solo un uso inteligente de estas bases. Por último podemos crear un constructor para las promesas:

```scala
object Promesa {

  def apply[T](): Promesa[T] = new PromesaImpl[T]()

}
```

## Los constructores más simples

`Futuro.successful` y `Futuro.failed` son constructores que sirven para envolver valores, existosos o fallidos, dentro de un Futuro. Para implementarlos debemos empezar con una versión de una promesa ya resuelta. Y para esto se deben implementar los métodos de una forma "constante" y por esto no es necesario usar un `ExecutionContext`. Para ahorrar espacio digamos que ese es un ejercicio para el lector o pueden verlo [acá](https://github.com/miguel-vila/grupo-concurrencia-paralelismo/blob/b0cd2b63a3daa41bcdc31c1a5b4850ba5c8007df/futuro-y-promesa/src/main/scala/futuro/Promesa.scala#L21-L37).

## Los otros combinadores funcionales

Ya vimos como se puede construir `map`. Sigamos con `flatMap`. La firma de `flatMap` es la siguiente:

```scala
trait Futuro[T] {

  //...

  def flatMap[S](f: T => Futuro[S])(implicit executionContext: ExecutionContext): Futuro[S]

 //...

}
```

Se puede interpretar así: `flatMap` sirve para tomar un resultado eventual y encadenarlo con una computación que usa ese resultado para crear otro resultado eventual.

Esto es algo más complicado que `map`, pero sigue el mismo esquema de solución:

```scala
def flatMap[S](f: T => Futuro[S])(implicit executionContext: ExecutionContext): Futuro[S] = {
  // Define una promesa del tipo esperado S
  val promesa = Promesa[S]()
  onComplete {
    case Success(t) =>
      // "Lee" el valor del futuro actual y con ese valor
      // ejecuta la función f para obtener otro futuro de
      // tipo S
      try {
        // "Lee" el valor de este nuevo futuro y
        // completa la promesa con ese valor
        f(t).onComplete { result2 => promesa.complete( result2 ) }
      } catch {
        // Maneja el error en caso de que la función f falle
        case NonFatal(error) =>
          promesa.complete( Failure(error) )
      }
    case Failure(error) =>
      // Si el futuro actual es fallido resolvemos la
      // promesa con ese error
      promesa.complete( Failure(error) )
  }
  // Al final devolvemos el lado de lectura de la promesa
  promesa.futuro
}

```

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
En la implementación de la librería estándar hacen varias optimizaciones, entre ellas la de enlazar promesas. Otra optimización que hacen es evitar la creación de nuevos objetos cuando el futuro es fallido, reusando el objeto de la falla y casteándolo a un futuro con el tipo esperado.
</div>
</div>

Pueden notar que hay una llamada a `onComplete` dentro del primer `onComplete`, lo mismo que un _callback_ dentro de otro _callback_, o también una función programada a ejecutarse que eventualmente programa la ejecución de otra función.

También hay combinadores funcionales para manejar las fallas. Por ejemplo `recover` o `recoverWith` que mapean la falla (si es que el futuro es fallido) a algún tipo que tenga algo en común con el contenido del futuro. Pueden mirar el [codigo fuente](https://github.com/miguel-vila/grupo-concurrencia-paralelismo/tree/b14bb0a9b90a901593825f887f5e46d793a874a8/futuro-y-promesa), pero resulta que su implementación es muy similar a la de `map` y `flatMap` respectivamente.

Esta similitud es la que nos podría llevar a un refactor, que es el que precisamente hacen en [la implementación de la librería estándar](https://github.com/scala/scala/blob/804a4cc1ff9fa159c576be7c685dbb81220c11da/src/library/scala/concurrent/impl/Promise.scala#L27-L44). Creo que después de ver la repetición de código es más fácil entender como se puede generalizar.

## `Futuro.sequence` y `Futuro.traverse`

Otro combinador funcional común es `sequence`, que sirve para reunir múltiples resultados eventuales en uno solo. Una forma de imaginarnos como está implementado es la siguiente:

```scala
def sequence[T](futuros: List[Futuro[T]])(implicit e: ExecutionContext): Futuro[List[T]] = {
  for {
    t0  <- futuros(0)
    t1  <- futuros(1)
    .
    .
    .
    tn  <- futuros(n)
  } yield t0 :: t1 :: ... :: tn :: List.empty[T]
}
```

Es decir la implementación solo depende de `flatMap` y de `map`.  Más concretamente se podria materializar así: 

```scala
def sequence[T](futures: List[Futuro[T]])(implicit e: ExecutionContext): Futuro[List[T]] = {
  futures.foldRight(Futuro.successful(List.empty[T])) { (fh,ftl) =>
    for {
      h  <- fh
      tl <- ftl
    } yield h :: tl
  }
}
```

En la librería estándar ésta función sirve no solo para listas sino también para otras estructuras de datos. Esto se logra mediante el _typeclass_ `CanBuildFrom`. Si quieren saber más en la parte 3 de [este artículo](https://adriaanm.github.io/files/higher.pdf) explican un _typeclass_ similar bajo el nombre de `Buildable`.

La función `traverse` es muy parecida:

```scala
def traverse[A,B](list: List[A])
                 (f: A => Futuro[B])
                 (implicit e: ExecutionContext): Futuro[List[B]] = {
  list.foldRight(Futuro.successful(List.empty[B])) { (a,ftl) =>
    val fh = f(a)
    for {
      h  <- fh
      tl <- ftl
    } yield h :: tl
  }
}
```

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Hay algo que tal vez noten y es que las implementaciones de `sequence` y `traverse` son bastante generales. Viendo el código no hay nada específico sobre asincronía o hilos, nada que nos diga que este código debería funcionar solamente para futuros. El patrón que estámos viendo acá es el de [funtores aplicativos](http://strictlypositive.org/Idiom.pdf) y funciona a distintos tipos de efectos.
</div>
</div>

## `Futuro.apply`

La función `apply` del companion object `Futuro` es una de las formas más fáciles de crear futuros. Por ejemplo:

```scala
implicit val exec: ExecutionContext = ...
val myFuture = Futuro { miCodigo() }
```

En este caso `myFuture` servirá como un futuro del resultado eventual de `miCodigo()`. Hacer esto sirve para hacer concurrentemente otras cosas mientras se ejecuta `miCodigo()`.

Una forma de implementar este método es simplemente programar la ejecución del código dentro del `ExecutionContext` y guardar el resultado en una promesa:

```scala
def apply[T](block :=> T)(implicit executor: ExecutionContext): Futuro[T] = {
  val promesa = Promesa[T]()
  executor.execute(new Runnable {
    override def run(): Unit = {
      val result = Try { block }
      promesa.complete( result )
    }
  })
  promesa.futuro
}
```

Un detalle importante de esta implementación es que el bloque de código es un argumento _call-by-name_ y no _call-by-value_ para que quién invoque este código no sea el que lo ejecute sino el `ExecutionContext`.

Pero hay otra forma de implementar esta función y es aprovechado un truco funcional:

```scala
def apply[T](block :=> T)(implicit executor: ExecutionContext): Futuro[T] = {
  Futuro.successful( () ).map( _ => block )
}
```

Partimos de un Futuro con un valor arbitrario y lo reemplazamos mediante map por el resultado de ejecutar el bloque. Conociendo como funcionan `successful` y `map` nos podemos dar cuenta de que ambas implementaciones hacen lo mismo.

Ahora ¿de qué sirve este método? ¿Sirve para convertir código bloqueante en no bloqueante? Ya sabemos como funciona por debajo para saber que la respuesta es no. Si un pedazo de código es bloqueante envolverlo con `Futuro { codigoBloqueante }` servirá para que, en un buen caso, el bloqueo suceda en otro hilo. ¿Por qué en un buen caso? Por que depende del `ExecutionContext`. Uno podría pasarle un `ExecutionContext` que ejecute lo `Runnable`s sobre el mismo _thread_ que llame `execute` y con esto el _thread_ que crea los futuros también se bloquearía.

## Reemplazando _callbacks_

Hay otra forma de crear Futuros y es la que se se usa cuando se está trabajando con un API asincrónica. Incluso ya hemos visto este método de construcción. Como ejemplo supongamos que vamos a envolver un cliente HTTP asincrónico en Futuros, para así poder manipular más fácilmente los resultados.

Por ejemplo [este](https://github.com/AsyncHttpClient/async-http-client) cliente en Java que se puede usar con _callbacks_:

```java
AsyncHttpClient asyncHttpClient = new DefaultAsyncHttpClient();
asyncHttpClient.prepareGet("http://www.example.com/")
.execute(new AsyncCompletionHandler<Response>(){

    @Override
    public Response onCompleted(Response response) throws Exception{
        // Do something with the Response
        // ...
        return response;
    }

    @Override
    public void onThrowable(Throwable t){
        // Something wrong happened.
    }
});
```

El API permite manipular los resultados como `java.util.concurrent.Future`, pero estos tienen la desventaja de ser bloqueantes cuando se quiere manipular el resultado. Debido a esto sería deseable envolver la llamada para que retorne un `Futuro`. En Scala esto sería:

```scala
def example(): Futuro[Response] = {
  val asyncHttpClient = new DefaultAsyncHttpClient();
  val promesa = Promesa[Response]()
  asyncHttpClient.prepareGet("http://www.example.com/")
  .execute(new AsyncCompletionHandler[Response](){

    override def onCompleted(Response response) = {
      promesa.complete( Success(response) )
    }
  
    override def onThrowable(Throwable t) = {
      promesa.complete( Failure(t) )
    }

  })
  promesa.futuro
}
```

## Uso del `ExecutionContext`

Conociendo la implementación podemos ahondar en un detalle. Por ejemplo, ¿hay alguna diferencia entre estos dos pedazos de código?:

```scala
futuro.map(f).map(g)
```

```scala
futuro.map(f andThen g)
```

Resulta que no hay diferencia con respecto al valor que eventualmente computan. Incluso si `f` o `g` fallan el valor con el que se complete el Futuro será el mismo en ambos casos. La diferencia radica en el uso de recursos. La primera versión llama `onComplete` dos veces, y por lo tanto programa la ejecución de dos tareas en el `ExecutionContext`, una tras de otra. En cambio la segunda versión solo lo hace una vez. Esto quiere decir que la primera versión programa la ejecución de dos tareas muy relacionadas en hilos posiblemente distintos. En resumen cada vez que llamamos `map` o `flatMap` producimos el efecto secundario de programar una tarea en el `ExecutionContext`.

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Por otra parte los [`Task`](http://timperrett.com/2014/07/20/scalaz-task-the-missing-documentation/)s de [scalaz](http://github.com/scalaz/scalaz) hacen algo diferente. Reutilizan el mismo hilo por defecto a ménos que se invoque el método `fork`. Además usan un truco de [trampolines](http://blog.higher-order.com/assets/trampolines.pdf) para reemplazar espacio en la pila de ejecución por espacio en el _heap_.
</div>
</div>

## Concluyendo

Hay muchas más cosas por decir sobre los futuros, sobre las decisiones de diseño y sobre qué tipo de lógica permiten separar. Pero para concluir tal vez valga la pena decir que el objetivo de desarmar los futuros es saber cómo usarlos de una mejor forma y eliminar un poco de la "magia" que uno puede atribuirles cuando se usan.

Cualquier comentario, sugerencia o corrección son bienvenidos.