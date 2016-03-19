---
title: Construyendo un pequeño lenguaje de programación (Parte 1)
description: Segunda parte de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, ADT, GADT, Reader Monad, Construyendo un pequeño lenguaje
---

En el [anterior _post_](http://miguel-vila.github.io/posts/2016-03-15-construyendo-un-pequeno-lenguaje-0.html) establecimos unas bases para poder construir nuestro pequeño lenguaje. Definimos un tipo llamado `Value` para representa los tipos de valores de nuestro lenguaje y definimos otro tipo `Exp` que representa expresiones.

<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">

A manera de referencia el siguiente es un listado de los tipos que definimos:

```scala
/*
 *********
 * Tipos *
 *********
*/
sealed trait Value

case class BooleanValue(value: scala.Boolean) extends Value
case class NumberValue(value: Float) extends Value
trait Void extends Value
object Void extends Void

/*
 ***************
 * Expresiones *
 ***************
*/
sealed trait Exp[ V <: Value ]

trait Literal[ V <: Value ] extends Exp[V] {
  def value: V
}

// Expresiones Booleanas
case class Boolean(value: BooleanValue) extends Literal[BooleanValue]

sealed trait Comparison extends Exp[BooleanValue] {
  def left : Exp[NumberValue]
  def right: Exp[NumberValue]
}

case class LessThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison 

case class Equal(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison

case class GreaterThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison

// Expresiones numéricas
case class Number(value: NumberValue) extends Literal[NumberValue]

sealed trait BinaryOp extends Exp[NumberValue] {
  def left : Exp[NumberValue]
  def right: Exp[NumberValue]
}

case class Add(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp

case class Multiply(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp

// Variables
trait Var[ V <: Value ] extends Exp[ V ] {
  def name: String
}

case class NumberVar(name: String) extends Var[NumberValue]

case class BooleanVar(name: String) extends Var[BooleanValue]

// Instrucciones / Expresiones sin retorno
case class Assign(name: String, expression: Exp[ _ <: Value ]) extends Exp[Void]

case class If(
  condition:   Exp[BooleanValue],
  consequence: Exp[Void],
  alternative: Exp[Void]
) extends Exp[Void]

case class While(
  condition: Exp[BooleanValue],
  body:      Exp[Void]
) extends Exp[Void]

case class Sequence(exps: Exp[Void]*) extends Exp[Void] 
```
</div>
</div>

Ahora el objetivo será tomar algo de tipo `Exp` e interpretarlo (asd).

## ¿Qué significa interpretar un árbol de sintáxis?

En nuestro caso decidimos que una expresión estuviera parametrizada por su tipo:

```scala
sealed trait Exp[ V <: Value ]
```

Un valor de tipo `Exp[V]` representa una expresión que al evaluarse produce algo de tipo `V`. Entonces una primera definición de evaluar podría ser precisamente eso: retornar un `V`. Vamos a definir una función abstracta dentro del `trait` que debe ser implementada por las extensiones:

```scala
sealed trait Exp[ V <: Value ] {
    def evaluate(): V
}
```

Esto sirve muy bien para algunas expresiones aritméticas como "`1 + 3*( 2 + 7)`" e incluso comparaciones como "`1 < (2 * 3)`". Pero en cambio expresiones que usan variables como "`x + 1`" o "`i < 10`" no se ajustan al molde. Para poder evaluar este último tipo de expresiones necesitamos tener acceso al entorno de variables definidas. Este entorno lo vamos a describir así:

```scala
type Environment = Map[String, Value]
```

Un entorno será algo que dado el nombre de una variable retorna su valor. Con esto podemos redefinir `evaluate` de la siguiente forma:

```scala
sealed trait Exp[ V <: Value ] {
    def evaluate(environment: Environment): V
}
```

Por último nos resta tener en cuenta el efecto de las asignaciones. Una asignación altera el entorno: inserta o actualiza un registro. Vamos a hacer las cosas de la forma funcional, es decir sin alterar el estado. Esto tiene varios beneficios pero el principal es que para entender una función solo tenemos que tener en cuenta los argumentos de entrada e inspeccionar lo que retorna:

```scala
sealed trait Exp[ V <: Value ] {
    def evaluate(environment: Environment): (Environment, V)
}
```

Leyendo la firma de la función podemos decir que al evaluar una expresión obtenemos dos cosas: un entorno, posiblemente modificado, y un valor.

## Implementando el evaluador

Ahora veamos como podríamos implementar este método para cada tipo de expresión:

Los **literales** son particularmente fáciles. Como un literal es un valor solo tenemos que retornarlo, con el mismo entorno:

```scala
trait Literal[ V <: Value ] extends Exp[V] {
  def value: V
  def evaluate(environment: Environment) = (environment, value)
}
```

Y debido a que nuestros tipos `Number` y `Boolean` extienden de `Literal` no necesitamos implementar `evaluate` para ellos.

Ahora veamos otro tipo abstracto: las **variables**. Para evaluar una variable simplemente tenemos que extraerla del mapa de variables:

```scala
trait Var[ V <: Value ] extends Exp[ V ] {
  def name: String
  def evaluate(environment: Environment) = {
    val value = environment(name).asInstanceOf[T]
    (environment, value)
  }
}
```

Podrán notar que aquí estamos rompiendo varias "reglas". Primero la forma en la que extraemos el valor del mapa no es segura: si no existe ninguna variable definida con el nombre entonces ese método arroja una excepción. Y segundo: estamos haciendo un _casteo_ que también podría fallar si existe una variable definida con ese nombre pero con el tipo incorrecto. La idea de esta serie de artículos es presentar algo muy simple entonces no nos vamos a preocupar por eso.

<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">

Sin embargo ambas situaciones sirven para hablar de qué decisiones toman algunos lenguajes. 

La primera situación, intentar usar una variable que no está definida, se convierte en un error en la mayoría de lenguajes. En algunos, como JavaScript o Python, este error se da en tiempo de ejecución. En cambio en otros lenguajes como Java o C (y en general lenguajes con tipado estático) este error se da en tiempo de compilación.

La segunda situación es más interesante: cuando una variable se intenta referenciar con un tipo distinto al que se usó cuando se definió. Esto sirve para ilustrar el difuso concepto de [tipado débil versus tipado fuerte](https://en.wikipedia.org/wiki/Strong_and_weak_typing). Algunos lenguajes como JavaScript intentan "adivinar" cuál era la intención del programador en algunas de estas situaciones y adapta los tipos según corresponda. Es decir tiene una noción débil de cuales son los tipos. Por ejemplo:

```javascript
>> '2' * 3
6
>> '1' + 2
'12'
```

En el primer caso el motor de JavaScript observa que se está intentando realizar una multiplicación entre un caracter y un número, debido a lo cuál convierte el primero en un número y continua la operación. En el segundo caso pasa algo similar, solo que el segundo elemento es convertido en un caracter y la operación que se ejecuta es la concatenación de caracteres.
En cambio en Python tiene una noción mas fuerte de los tipos:

```python
>>> '2' * 3
'222'
>>> '1' + 2
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: cannot concatenate 'str' and 'int' objects
```

...el primer comando funciona en Python por que ese es un método definido para los caracteres


pero ambos tipos de errores se podrían evitar si antes de ejecutar la evaluación se hacen dos chequeos: uno de que todas las variables referidas hayan sido definidas previamente

</div>

</div>

Antes de atacar las expresiones numéricas vamos agregar algunos métodos dentro de la clase `NumberValue` para facilitarnos la vida:

```scala
case class NumberValue(value: Float) extends Value {

  def +(other: NumberValue): NumberValue  = NumberValue(  value + other.value )
  def *(other: NumberValue): NumberValue  = NumberValue(  value * other.value )
  def <(other: NumberValue): BooleanValue = BooleanValue( value < other.value )
  def >(other: NumberValue): BooleanValue = BooleanValue( value > other.value )

}
```

Estos métodos simplemente reusan los mismos métodos disponibles dentro del tipo `Float` solamente que retornan algo de tipo `NumberValue` o `BooleanValue` (nuestros tipos) en vez de `Float` o `Boolean` respectivamente.

Empecemos con las sumas. Para evaluar una suma primero evaluamos ambos lados de la expresión y sumamos los resultados:

```scala
case class Add(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp {
  def evaluate(environment: Environment) = {
    val (environment2, leftValue ) = left.evaluate(environment)   
    val (environment3, rightValue) = right.evaluate(environment2) 
    val sum = leftValue + rightValue                              
    (environment3, sum)                                           
  }
}
```

Primero evaluamos el lado izquierdo de la expresión y obtenemos dos cosas: el entorno, tal vez modificado, y el resultado de evaluar la expresión a la izquierda. Después evaluamos el lado derecho de la expresión usando el anterior entorno y volvemos a obtener dos cosas: un tercer entorno y el valor del lado derecho. Una vez obtenidos ambos valores los combinamos usando `+`, la función definida sobre objetos de tipo `NumberValue`, y finalmente devolvemos el entorno final y la suma.

<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">
¿Por que tenemos que pasar el entorno si solo estamos evaluando expresiones numéricas que no modifican el entorno?

En un futuro podríamos querer incluir un operador como el `++`, común en algunos lenguajes, que al mismo tiempo devuelve un valor y modifica una variable. Por ejemplo el siguiente código en C es legal:

```c
int x = 3;
int y = (x++) + (x++);
```

Las expresiones de ambos lados modifican el entorno y más aún la expresión del lado derecho usa una variable modificada en el lado izquierdo.

</div>
</div>

Como se podrán imaginar implementar el evaluador para `Multiply` es muy parecido, con la excepción de que combinamos los valores usando `*`. Y si en un futuro decidimos incluir otros operadores como la resta y la división también repetirémos esta estructura. Debido a esto es que podemos aprovechar el ancestro que todos ellos tienen en común y factorizar esta repetición:

```scala
sealed trait BinaryOp extends Exp[Number] {
  def left: Exp[NumberValue]
  def right: Exp[NumberValue]
  
  def combineWith(
    environment: Environment, 
    combine: (NumberValue, NumberValue) => NumberValue
  ): (Environment, NumberValue) = {
    val (environment2, leftValue ) = left.evaluate(environment)
    val (environment3, rightValue) = right.evaluate(environment2)
    val combinedValue = combine(leftValue, rightValue)
    (environment3, combinedValue)
  }

}
``` 

```scala
case class Add(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp {
  def evaluate(environment: Environment) = combineWith(environment, _ + _)
}
```

```scala
case class Multiply(left: Exp[NumberValue], right: Exp[NumberValue]) extends BinaryOp {
  def evaluate(environment: Environment) = combineWith(environment, _ * _)
}
```

De forma muy similar podemos implementar los evaluadores para las comparaciones:

```scala
sealed trait Comparison extends Exp[BooleanValue] {
  def left: Exp[NumberValue]
  def right: Exp[NumberValue]
  def compareWith(
    environment: Environment, 
    compare: (NumberValue, NumberValue) => BooleanValue) = {
    val (environment2, leftValue ) = left.evaluate(environment)
    val (environment3, rightValue) = right.evaluate(environment2)
    val comparisonValue = compare(leftValue, rightValue)
    (environment3, comparisonValue)
  }

}
```

```scala
case class LessThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison {
  def evaluate(environment: Environment) = compareWith(environment, _ < _)
}
```

```scala
case class Equal(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison {
  def evaluate(environment: Environment) = compareWith(environment, _ eq _)
}
```

```scala
case class GreaterThan(left: Exp[NumberValue], right: Exp[NumberValue]) extends Comparison {
  def evaluate(environment: Environment) = compareWith(environment, _ > _)
}
```

Ahora vamos a ver como evaluar las instrucciones:

Para evaluar una **asignación** primero debemos evaluar la expresión, almacenar el valor dentro del entorno y retornar el entorno actualizado junto con el valor `Void`:

```scala
case class Assign(name: String, expression: Expression[ _ <: Value ]) extends Exp[Void] {
  def evaluate(environment: Environment) = {
    val (environment2, expressionValue) = expression.evaluate(environment)
    val environment3 = environment2 + ((name, expressionValue))
    (environment3, Void)
  }
}
```

Ahora las instrucciones `If` y `While` son un poco más interesantes ya que condicionan la ejecución de una instrucción según un predicado.

Para evaluar un `If` primero evaluamos la condición y según el valor de la condición continuamos evaluando un lado u otro del condicional:

```scala
case class If(
               condition:    Exp[BooleanValue],
               consequence:  Exp[Void],
               alternative:  Exp[Void]) extends Exp[Void] {

  def evaluate(environment: Environment) = {
    val (environment2, evaluatedCondition) = condition.evaluate(environment)
    if(evaluatedCondition.value) {
      consequence.evaluate(environment2)
    } else {
      alternative.evaluate(environment2)
    }
  }

}
```

Y para evaluar un `While` podemos hacerlo recursivamente. Si la condición evalúa a verdadero evaluamos el cuerpo del `While` e invocamos recursivamente la función pero con el entorno resultante de evaluar el cuerpo. Si el predicado es falso retornamos el entorno resultante del predicado junto al valor `Void`:

```scala
case class While(condition: Exp[BooleanValue], body: Exp[Void]) extends Exp[Void] {
  def evaluate(environment: Environment) = {
    val (environment2, evaluatedCondition) = condition.evaluate(environment)
    if(evaluatedCondition.value) {
      val (environment3, _) = body.evaluate(environment2)
      evaluate(environment3)
    } else {
      (environment2, Void)
    }
  }
}
```

Por último para evaluar una secuencia de instrucciones primero evaluamos la primera instrucción, lo que retorna un entorno actualizado, usamos ese entorno para evaluar la segunda instrucción que a su vez retorna otro entorno actualizado, el cuál usamos para evaluar la tercera instrucción y así. Una forma de hacerlo es un con `fold`, aunque también se podría hacer con un `while`:

```scala
case class Sequence(exps: Exp[Void]*) extends Exp[Void] {
  def evaluate(environment: Environment) = {
    val finalEnvironment = exps.foldLeft(environment) { (environment, exp) =>
      val (newEnvironment,_) = exp.evaluate(environment)
      newEnvironment
    }
    (finalEnvironment, Void)
  }
}
```