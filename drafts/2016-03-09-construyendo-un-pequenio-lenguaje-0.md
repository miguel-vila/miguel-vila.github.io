---
title: Construyendo un pequeño lenguaje de programación (Parte 0)
description: Parte 0 de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, ADT, GADT, Construyendo un pequeño lenguaje
---

Un ejercicio común en [programación funcional](https://en.wikipedia.org/wiki/Functional_programming) es el de construir un pequeño lenguaje. Más precisamente el ejercicio consiste en construir el intérprete de un lenguaje: algo que recorra un árbol de sintáxis y lo reduzca a un valor. Este ejercicio es bastante común en artículos, libros o cursos de programación funcional.

Por ejemplo [Philip Wadler](http://homepages.inf.ed.ac.uk/wadler/) tiene un [artículo](http://homepages.inf.ed.ac.uk/wadler/papers/marktoberdorf/baastad.pdf) que usa un intérprete para motivar un patrón común en programación funcional. 

En el mundo de lenguajes tipo [lisp](https://en.wikipedia.org/wiki/Lisp_(programming_language)) también es muy común. Por ejemplo en el [curso de lenguajes de programación en coursera](https://www.coursera.org/course/proglang) hacen el ejercicio de construir un pequeño intérprete usando [racket](https://racket-lang.org/). O tal vez mas conocido es el libro ["Structure and Interpretation of Computer Programs"](https://mitpress.mit.edu/sicp/) (posiblemente inspiración del anterior curso) en el que en una buena parte del libro se dedican a hacer lo mismo.

Y mas recientemente la idea de los intérpretes ha sido usada con [propósitos más complejos](https://www.youtube.com/watch?v=hmX2s3pe_qk).

El caso es que la idea de construir algo que ejecute un lenguaje de programación suena difícil y compleja. Pero todos estos ejemplos, traídos del lado de programación funcional, demuestran que, a pequeña escala, la tarea no es tan difícil.

## Un lenguaje simple

La idea de esta serie de artículos es demostrar eso usando Scala. Y debido a que vamos a usar Scala algunas cosas serán más complicadas. En particular debido a que Scala tiene tipado estático tenemos la tarea de convencer al _typechecker_ de que lo que estamos haciendo tiene sentido.

Vamos a crear un lenguaje muy simple. No tendrá funciones, no tendrá declaraciones de tipos y solo habrá dos tipos de datos: números y expresiones booleanas. Tendrá `if`s y `while`s y tendrá una sintáxis similar a la de lenguajes tipo C. Por ejemplo para computar los primeros 10 números de fibonacci escribiríamos algo como:

```c
a = 0;
b = 1;
i = 1;
while ( i < 11 ) {
    c = a;
    a = b;
    b = b + c;
    i = i + 1;
}
```

Entonces empecemos:

## Los tipos de datos del lenguaje

Vamos a tener solo dos tipos de datos: números y booleanos. Pero ciertos tipos de expresiones, por ejemplo las asignaciones, no tienen un tipo de retorno. Entonces otro tipo dentro de nuestra jerarquía será `Void`. 

Empezamos con un tipo abstracto que represente la base que comparten todos los tipos de nuestro lenguaje:

```scala
sealed trait Value
```

Los booleanos serán "wrappers" de los booleanos de Scala:

```scala
case class BooleanValue(value: scala.Boolean) extends Value
```

Y de forma similar los números:

```scala
case class NumberValue(value: Float) extends Value
```

[//]: <> (Y de forma similar con los números, a los que les agregarémos algunas funciones que nos resultarán útiles en el momento de evaluar expresiones:)

[//]: <> (```scala)
[//]: <> (case class NumberValue(value: Float) extends Value {)
[//]: <> (  def +(other: NumberValue):  NumberValue  = NumberValue(value + other.value))
[//]: <> (  def *(other: NumberValue):  NumberValue  = NumberValue(value * other.value))
[//]: <> (  def <(other: NumberValue):  BooleanValue = BooleanValue(value < other.value))
[//]: <> (  def >(other: NumberValue):  BooleanValue = BooleanValue(value > other.value))
[//]: <> (  def eq(other: NumberValue): BooleanValue = BooleanValue(value == other.value))
[//]: <> (})
[//]: <> (```)

Por último "`Void`" será un tipo (un `trait`) y un valor (un `object`). Podríamos hacerlo solo un valor pero de esta forma nos evita anotar algunas cosas como "`Void.type`" lo que es un poco raro:

```scala
trait Void extends Value
object Void extends Void
```

Este patrón, común en programación funcional, se denomina **Algebraic Data Type** (ADT). La idea es que un mismo tipo, `Value`, se puede instanciar de formas distintas: como `BooleanValue`, como `NumberValue` o como `Void`. En Scala ésta conjunción de posibilidades se codifica usando un tipo base que es abstracto y un subtipo por cada variante. En otros lenguajes como Haskell esto se hace declarando un solo tipo con multiples constructores. Pueden leer más sobre ADTs en [este](http://tech.esper.com/2014/07/30/algebraic-data-types/) enlace y sobre como se construyen en Scala [acá](https://gleichmann.wordpress.com/2011/01/30/functional-scala-algebraic-datatypes-enumerated-types/).

En este caso el ADT es muy simple pero hay usos más complejos: 

* El tipo [`Option`](http://danielwestheide.com/blog/2012/12/19/the-neophytes-guide-to-scala-part-5-the-option-type.html).
* [Listas encadenadas](http://www.scala-lang.org/api/2.7.7/scala/List.html)
* Para representar valores [`JSON`](https://github.com/playframework/playframework/blob/58a150d712bdf3bf4d14709569afcfd9ea97fb7f/framework/src/play-json/src/main/scala/play/api/libs/json/JsValue.scala#L15).

## Las expresiones del lenguaje

Todo lo anterior solo describe el resultado final de las computaciones. Necesitamos describir las expresiones de nuestro lenguaje que al evaluarse producen alguno de esos valores.

Enumerémos qué expresiones tiene nuestro pequeño lenguaje:

* Hay **literales** que son valores que no se pueden evaluar más como "`123`" o "`True`".
* Hay **variables** que es cuando usamos el nombre de una variable para referirnos a su valor. Por ejemplo con nombres válidos que sean secuencias de caracteres alfabéticos como "`x`" o "`miVariable`".
* Hay **expresiones booleanas** como **comparaciones** (por ejemplo "`1 < 2`" o "`miVariable < 4`" o "`x == y`") o también referencias a variables booleanas.
* Hay **expresiones numéricas** como **operaciones binarias** (por ejemplo "`1 + 3`" o "`3*y + 2*(3+z)`") o también referencias a variables numéricas.
* Hay **asignaciones** que son expresiones de tipo "`x = <alguna expresión>`" donde atamos el valor de una expresión al nombre de una variable.
* Hay **estructuras de control** como "`if() {} else {}`" o "`while () {}`".
* Hay **secuencias de instrucciones** como secuencias de asignaciones, o de `if`s o `while`s.

Una expresión será representada por un tipo abstracto llamado `Exp` que estará parametrizado según el tipo de la expresión:

```scala
sealed trait Exp[ V <: Value ]
```

Aquí estamos usando un [límite de tipo](http://www.scala-lang.org/old/node/136) (el extraño `<:`) para decir que el parámetro de tipo `V` debe ser un subtipo de `Value`, es decir o `NumberValue` o `BooleanValue` o `Void`. El parámetro sirve para decir cuál es el tipo de la expresión: las expresiones numéricas seran de tipo `Exp[NumberValue]`, las booleanas de tipo `Exp[BooleanValue]` y las que no tienen tipo `Exp[Void]`.

Veamos como podríamos implementar cada una de las anteriores expresiones:

Los **literales** son expresiones de las que podemos obtener su valor inmediatamente, entonces tiene sentido definir un miembro abstracto que devuelva el valor:

```scala
trait Literal[ V <: Value ] extends Exp[V] {
  def value: V
}
```

Los **literales booleanos** serán una extensión del anterior `trait` con el campo `value` de tipo `BooleanValue`:

```scala
case class Boolean(value: BooleanValue) extends Literal[BooleanValue]
```

[//]: <> (Y vamos a incluir un _companion object_ con algunos métodos que nos pueden resultar utiles:)

[//]: <> (```scala)
[//]: <> (object Boolean {)
[//]: <> (  /**)
[//]: <> (    * Constructor)
[//]: <> (    */)
[//]: <> (  def apply(sboolean: scala.Boolean /*un boolean de la lib estándar de Scala*/): Boolean = {)
[//]: <> (    Boolean(BooleanValue(sboolean)))
[//]: <> (  })
[//]: <> (  def True : Boolean = apply(true))
[//]: <> (  def False: Boolean = apply(false))
[//]: <> (})
[//]: <> (```)

Cuando hablamos de una **comparación** estamos relacionando dos expresiones numéricas (algo del tipo `Exp[NumberValue]`), una a la izquierda y otra a la derecha de la comparación. Primero describirémos un tipo base que nos resultará útil para evitarnos cierta repetición en el futuro:

```scala
sealed trait Comparison extends Exp[BooleanValue] {
  def left : Exp[NumberValue]
  def right: Exp[NumberValue]
}
```

Y los distintos tipos de comparaciones van a ser una extensión de la anterior:

```scala
case class LessThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison 

case class Equal(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison

case class GreaterThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison
```

De forma similar a los booleanos tenemos los **literales numéricos**:

```scala
case class Number(value: NumberValue) extends Literal[NumberValue]

object Number {

  /**
    * Constructor
    */
  def apply(float: Float): Number = new Number(NumberValue(float))

}
```

También tendrémos un tipo base para las **operaciones binarias**:

```scala
sealed trait BinaryOp extends Exp[NumberValue] {
  def left : Exp[NumberValue]
  def right: Exp[NumberValue]
}
```

Y una extensión para cada tipo de operación binaria:

```scala
case class Add(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp

case class Multiply(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp
```

También las **variables** son expresiones. La forma de referirnos a una variable es por medio de su nombre, entonces tiene sentido definir un campo nombre de tipo `String`. Empezamos con un tipo base:

```scala
trait Var[ V <: Value ] extends Exp[ V ] {
  def name: String
}
```

Y las distintas extensiones que podemos tener:

```scala
case class NumberVar(name: String) extends Var[NumberValue]
case class BooleanVar(name: String) extends Var[BooleanValue]
```

Ahora vamos a ver las expresiones que no tienen valor y que denominarémos instrucciones. 

Una **asignación** consiste de un nombre y de una expresión:

```scala
case class Assign(name: String, expression: Exp[ _ <: Value ]) extends Exp[Void]
```

El tipo existencial de la expresión (el _underscore_ detrás del `_ <: Value`) nos sirve para decir que no nos interesa el tipo específico de la expresión. Lo que nos interesa decir es que una asignación consiste de un nombre y de una expresión de _algún_ tipo, pero no nos importa cuál.

En nuestro lenguaje los **condicionales** también serán expresiones sin valor de retorno (a diferencia de lenguajes donde los `if`s son expresiones con valor como el mismo Scala) y consistirán de una expresión booleana (el condicional) y dos instrucciones (la instrucción cuando el condicional sea verdadero y la instrucción cuando no lo sea):

```scala
case class If(
  condition:   Exp[BooleanValue],
  consequence: Exp[Void],
  alternative: Exp[Void]
) extends Exp[Void]
```

Los `while`s serán similares:

```scala
case class While(
  condition: Exp[BooleanValue],
  body:      Exp[Void]
) extends Exp[Void]
```

Por último la **concatenación de instrucciones** también es una instrucción:

```scala
case class Sequence(exps: Exp[Void]*) extends Exp[Void] 
```

En este caso utilizamos un [argumento variable](http://alvinalexander.com/scala/how-to-define-methods-variable-arguments-varargs-fields) solamente para poder escribir expresiones sin tener que construir listas.

Esta jerarquía que hemos usado para describir expresiones en nuestro leguaje sigue un patrón similar a los ADTs pero con un parámetro de tipo. Este patrón se denomina **[Generalised Algebraic Data Type](https://vimeo.com/12208838)** (GADT).

Ya armados con una jerarquía de tipos el siguiente código...

```c
a = 0;
b = 1;
i = 1;
while ( i < 11 ) {
    c = a;
    a = b;
    b = b + c;
    i = i + 1;
}
```

...se traduce en:

```scala
Sequence(
  Assign("a", Number(0)),
  Assign("b", Number(1)),
  Assign("i", Number(1)),
  While(LessThan( NumberVar("i"), Number(11) ),
        Sequence(
            Assign( "c", NumberVar("a") ),
            Assign( "a", NumberVar("b") ),
            Assign( "b", Sum( NumberVar("b"), NumberVar("c") ) ),
            Assign( "i", Sum( NumberVar("i"), Number(1) ) )
        )
  )
)
```

## Concluyendo

Hasta ahora solo hemos definido un montón de tipos que nos permiten construir expresiones que representan programas en nuestro lenguaje. Como se podrán imaginar el siguiente paso es construir el evaluador, que será el tema del próximo _post_. Tal vez incluso se podrán imaginar como es que se hace esta transformación.