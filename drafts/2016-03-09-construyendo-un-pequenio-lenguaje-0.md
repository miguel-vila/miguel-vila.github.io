---
title: Construyendo un pequeño lenguaje de programación (Parte 0)
description: Parte 0 de una serie de posts en las que se construye un pequeño lenguaje de programación
tags: Scala, Interpreter, Functional Programming, Understanding Computation
---

Uno de los aparentes ritos de paso en programación funcional es el de construir un pequeño lenguaje de programación. O para ser más preciso construir el intérprete de un lenguaje de programación: algo que recorra un árbol de sintáxis y lo reduzca a un valor. Este ejercicio es bastante común en artículos, libros o cursos.

Por ejemplo el [artículo](http://homepages.inf.ed.ac.uk/wadler/papers/marktoberdorf/baastad.pdf) de [Philip Wadler](http://homepages.inf.ed.ac.uk/wadler/) explicando un patrón común en programación funcional usa un intérprete como motivador. 

En el mundo de lenguajes tipo lisp también es muy común, dada la facilidad de recorrer las expresiones. Por ejemplo en el [curso de lenguajes de programación en coursera](https://www.coursera.org/course/proglang) hacen el ejercicio de construir un pequeño intérprete usando racket. O tal vez mas conocido es el libro ["Structure and Interpretation of Computer Programs"](https://mitpress.mit.edu/sicp/) donde en una buena parte del libro se dedican a hacer lo mismo.

Y mas recientemente la idea de los intérpretes ha sido usada con [propósitos más complejos](https://www.youtube.com/watch?v=hmX2s3pe_qk).

El caso es que la idea de construir algo que ejecute un lenguaje de programación suena bastante ambiciosa y compleja. Pero todos estos ejemplos, traídos del lado de programación funcional, demuestran que, a pequeña escala, la tarea no es tan difícil.

La idea de esta serie de artículos es demostrar eso usando Scala. Y debido a que vamos a usar Scala algunas cosas serán más complicadas. En particular debido a que Scala tiene tipado estático tenemos la tarea de convencer al _typechecker_ que lo que estamos haciendo tiene sentido. 

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

Primero vamos a crear una jerarquía de tipos, detallando lo que queremos. Por una parte vamos a tener solo dos tipos de datos: números y booleanos. Pero ciertos tipos de expresiones, por ejemplo asignaciones, no tienen un tipo de retorno. Entonces otro tipo dentro de nuestra jerarquía será `Void`. 

Empezamos con un tipo abstracto que represente la base que comparten todos los tipos de nuestro lenguaje:

```scala
sealed trait Value
```

Los booleanos simplemente serán "wrappers" de los booleanos de Scala:

```scala
case class BooleanValue(value: scala.Boolean) extends Value
```

Y de forma similar con los números, a los que les agregarémos algunas funciones que nos resultarán útiles en el momento de evaluar expresiones:

```scala
case class NumberValue(value: Float) extends Value {

  def +(other: NumberValue):  NumberValue  = NumberValue(value + other.value)
  def *(other: NumberValue):  NumberValue  = NumberValue(value * other.value)
  def <(other: NumberValue):  BooleanValue = BooleanValue(value < other.value)
  def >(other: NumberValue):  BooleanValue = BooleanValue(value > other.value)
  def eq(other: NumberValue): BooleanValue = BooleanValue(value == other.value)

}
```

Y por último "`Void`" que será un tipo y un valor (podríamos hacerlo solo un valor pero hacerlo de esta forma nos evita anotar algunas cosas como "`Void.type`" lo que es un poco raro):

```scala
trait Void extends Value
object Void extends Void
```

Algunos tal vez estén familiarizados con este patrón. Se denomina [Abstract Data Types](http://tech.esper.com/2014/07/30/algebraic-data-types/).

Pero todo lo anterior solo describe el resultado final de las computaciones. Necesitamos describir las expresiones que nuestro lenguaje soporta que al evaluarse producen alguno de los anteriores tipos.

La base de todo va a ser un tipo abstracto llamado `Expression` que está parametrizado según el tipo de la expresión:

```scala
sealed trait Expression[V <: Value]
```

Aquí estamos usando un [límite de tipo](http://www.scala-lang.org/old/node/136) (el extraño `<:`) para decir que el parámetro de tipo `V` debe ser un subtipo de `Value`, es decir o `NumberValue` o `BooleanValue` o `Void`.

Ahora veamos que tipos de expresiones tiene nuestro pequeño lenguaje:

* Hay **literales** que son valores que no se pueden evaluar más como "`123`" o "`True`".
* Hay **asignaciones** que son expresiones de tipo "`x = <alguna expresión>`" donde atamos el valor de una expresión al nombre de una variable.
* Hay **referencias a variables** que son cuando usamos el nombre de una variable para usar su valor. Por ejemplo con nombres válidos que sean secuencias de carácteres alfabéticos como "`x`" o "`miVariable`".
* Hay **expresiones booleanas** como **comparaciones** ("`1 < 2`" o "`miVariable < 4`") o referencias a variables booleanas.
* Hay **expresiones numéricas** como **operaciones binarias** ("`1 + 3`" o "`x * 7`") o referencias a variables numéricas.
* Hay **estructuras de control** como `if() {} else {} ` o `while () {}`