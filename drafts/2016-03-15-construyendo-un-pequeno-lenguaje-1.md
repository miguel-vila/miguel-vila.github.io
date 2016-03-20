---
title: Construyendo un pequeño lenguaje de programación (Parte 1)
description: Segunda parte de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, Programming languages, Construyendo un pequeño lenguaje
---

En el [anterior _post_](http://miguel-vila.github.io/posts/2016-03-15-construyendo-un-pequeno-lenguaje-0.html) establecimos unas bases para poder construir nuestro pequeño lenguaje. Definimos un tipo llamado `Value` para representar los tipos de valores de nuestro lenguaje y definimos otro tipo `Exp` que representa expresiones.

<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">

A manera de referencia el siguiente es un listado de los tipos que definimos:

```scala
/*
 ***********
 * Valores *
 ***********
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

Ahora el objetivo será tomar algo de tipo `Exp` e interpretarlo. A lo largo de estos artículos vamos a utilizar las palabras "interpretar" y "evaluar" para referirnos el proceso en el que una expresión es reducida a un valor. También nos referiremos a las expresiones sin valor de retorno (las de tipo `Exp[Void]`) como "instrucciones".

## ¿Qué significa interpretar un árbol de sintaxis?

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

Esto sirve muy bien para algunas expresiones aritméticas como "`1 + 3*( 2 + 7)`" e incluso comparaciones como "`1 < (2 * 3)`". Pero en cambio expresiones que usan variables como "`x + 1`" o "`i < 10`" no se ajustan al mismo molde. Para poder evaluar este último tipo de expresiones necesitamos tener acceso al entorno de variables definidas. Este entorno lo vamos a describir así:

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

Ahora veamos cómo podríamos implementar este método para cada tipo de expresión:

Los **literales** son particularmente fáciles. Como un literal es un valor solo tenemos que retornarlo, con el mismo entorno:

```scala
trait Literal[ V <: Value ] extends Exp[V] {
  def value: V
  def evaluate(environment: Environment) = (environment, value)
}
```

Y debido a que nuestros tipos `Number` y `Boolean` extienden de `Literal` no necesitamos implementar `evaluate` para ellos.

Ahora veamos otro tipo abstracto: las **variables**. Para evaluar una variable simplemente tenemos que extraerla del entorno:

```scala
trait Var[ V <: Value ] extends Exp[ V ] {
  def name: String

  def evaluate(environment: Environment) = {
    val value = environment(name).asInstanceOf[T]
    (environment, value)
  }

}
```

Podrán notar que aquí estamos rompiendo varias "reglas". Primero la forma en la que extraemos el valor del mapa no es segura: si no existe ninguna variable definida con ese nombre entonces la llamada arroja una excepción. Y segundo: estamos haciendo un _casteo_ que también podría fallar si existe una variable definida con ese nombre pero con el tipo incorrecto. La idea de esta serie de artículos es presentar algo muy simple entonces no nos vamos a preocupar por esto.

<!--div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span>(Click!)</span></p>

<div class="note-content">

Ambos errores sirven para hablar de qué decisiones toman algunos lenguajes. 

La primera situación, intentar usar una variable que no está definida, se convierte en un error en la mayoría de lenguajes. En algunos, como JavaScript o Python, este error se da en tiempo de ejecución. En cambio en otros lenguajes como Java o C (y en general lenguajes con tipado estático) este error se da en tiempo de compilación.

La segunda situación es más interesante: cuando una variable se intenta referenciar con un tipo distinto al que se usó cuando se definió. Esto sirve para ilustrar el difuso concepto de [tipado débil versus tipado fuerte](https://en.wikipedia.org/wiki/Strong_and_weak_typing). Algunos lenguajes, [como JavaScript](https://github.com/getify/You-Dont-Know-JS/blob/master/types%20%26%20grammar/ch4.md#chapter-4-coercion), intentan "adivinar" cuál era la intención del programador en algunas de estas situaciones y adapta los tipos según corresponda. Es decir tiene una noción débil de cuales son los tipos. Por ejemplo en JavaScript:

```javascript
>> '2' * 3
6
>> '1' + 2
'12'
```

En el primer caso el motor de JavaScript observa que se está intentando realizar una multiplicación entre un caracter y un número, convierte el primero en un número y continua la operación. En el segundo caso pasa algo similar, solo que el segundo elemento es convertido en un caracter y la operación que se ejecuta es la concatenación de caracteres.

En cambio en Python hay una noción mas fuerte de los tipos:

```python
>>> '2' * 3
'222'
>>> '1' + 2
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: cannot concatenate 'str' and 'int' objects
```

...el primer comando funciona en Python por que `*` es un método definido para los caracteres. Y el segundo comando falla por que no se tiene definida una forma de concatenar objetos de tipo `str` e `int`. La diferencia es que python no hace ninguna conversión de tipos. Esta es una noción más fuerte de los tipos. Como podrán notar 

</div>

</div-->

Antes de atacar las **expresiones numéricas** vamos agregar algunos métodos dentro de la clase `NumberValue` para facilitarnos la vida:

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

En la suma en la segunda línea las expresiones de ambos lados modifican el entorno y más aún la expresión del lado derecho usa una variable modificada en el lado izquierdo.

</div>
</div>

Como se podrán imaginar implementar el evaluador para `Multiply` es muy parecido, con la excepción de que combinamos los valores usando `*`. Y si en un futuro decidimos incluir otros operadores como la resta y la división también repetiremos esta estructura. Debido a esto es que podemos aprovechar el ancestro que todos ellos tienen en común y factorizar esta repetición:

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

Con esto los distintos tipos de operaciones binarias quedan más simples:

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

De forma muy similar podemos implementar los evaluadores para las **comparaciones**:

```scala
sealed trait Comparison extends Exp[BooleanValue] {
  def left: Exp[NumberValue]
  def right: Exp[NumberValue]

  def compareWith(
    environment: Environment, 
    compare: (NumberValue, NumberValue) => BooleanValue
  ): (Environment, BooleanValue) = {
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

Ahora vamos a ver cómo evaluar las **instrucciones**:

Para evaluar una **asignación** primero debemos evaluar la expresión, almacenar el valor dentro del entorno y retornar el entorno actualizado junto con el valor `Void`:

```scala
case class Assign(name: String, expression: Exp[ _ <: Value ]) extends Exp[Void] {

  def evaluate(environment: Environment) = {
    val (environment2, expressionValue) = expression.evaluate(environment)
    val environment3 = environment2 + (name -> expressionValue)
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

Por último para evaluar una secuencia de instrucciones evaluamos la primera instrucción, lo que retorna un entorno actualizado, usamos ese entorno para evaluar la segunda instrucción que a su vez retorna otro entorno actualizado, el cual usamos para evaluar la tercera instrucción y así. Una forma de hacerlo es un con `fold`, aunque también se podría hacer con un `while`:

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

Y así hemos logrado describir cómo se pueden evaluar todas las expresiones dentro nuestro lenguaje.

## Probando

Ya con esto podemos hacer una prueba simple. Tratemos de ejecutar este mismo código de JavaScript:

```javascript
var foo = 0
var bar = 1
while(foo < 5) {
    foo = foo + 1;
    if(foo<3){
       bar = bar + 1;
    } else {
        bar = bar + foo + 2;
    }
}
```

Traducido a nuestro lenguaje el árbol de sintaxis es:

```scala
val exp = Sequence(
    Assign("foo", Number(0)),
    Assign("bar", Number(1)),
    While(LessThan(NumberVar("foo"), Number(5)),
        Sequence(
            Assign("foo", Add(NumberVar("foo"), Number(1))),
            If(LessThan(NumberVar("foo"), Number(3)),
                Assign("bar", Add(NumberVar("bar"), Number(1))),
                Assign("bar", Add(Add(NumberVar("bar"), NumberVar("foo")), Number(2)))
            )
        )
    )
)
```

Para ejecutarlo le pasamos un entorno vacío:

```scala
> exp.evaluate(Map.empty)
(Map(foo -> NumberValue(5), bar -> NumberValue(21)), Void)
``` 

Y obtenemos de vuelta un entorno modificado.

## Semántica operacional

Hemos capturado el significado de nuestro lenguaje de programación por medio de reglas que dicen como cada tipo de expresión se ejecuta. Esto se denomina **semántica operacional**. Y en particular lo que hicimos fue algo llamado **_big-step semantics_**: describir como pasar de una expresión _directamente_ a su resultado. Existe una alternativa y es hacerlo iterativamente, reduciendo cada expresión a una expresión equivalente pero más simple. Este acercamiento se llama **_small-step semantics_**. 

En nuestro caso vamos a considerar que una expresión está completamente reducida solamente si es de tipo `Literal`. Si una expresión no está reducida debemos buscar la forma de simplificarla. Por ejemplo:

```scala
> Add( Number(1), Multiply( Number(2), Number(3) ) ) // Expresión inicial
> Add( Number(1), Number(2) * Number(3) )            // Reducción del lado derecho
> Add( Number(1), Number(6) )                        // Expresión reducida
> Number(1) + Number(6)                              // Reducción de la suma
> Number(7)                                          // Expresión reducida
```

Para reducir una suma inspeccionamos ambos lados. El lado izquierdo ya está completamente reducido pero el lado derecho no. Para reducir el lado derecho, que es una multiplicación, inspeccionamos ambos lados, vemos que ambos ya están reducidos y realizamos la multiplicación. Con esto ya hemos reducido el lado derecho de la suma y con esto la podemos reducir completamente.

Lo mismo se puede hacer para otros tipos de expresiones. Pueden ver en detalle este otro acercamiento [acá](https://github.com/miguel-vila/understanding-computation/blob/master/src/main/scala/understanding_computation/chapter2/execution/operational_semantics/SmallStepSemantics.scala#L9) (aunque admito que el código no está tan organizado y se le podrían hacer mejoras).

La ventaja de este acercamiento es que es mas eficiente en el uso del _stack_. El acercamiento de **_big-step semantics_** realiza muchas llamadas recursivas que podrían llenar el _stack_ para programas grandes. En contraste el acercamiento de **_small-step semantics_** es iterativo.

## Concluyendo

Gran parte de este _post_ toma como base el capítulo 2 del libro [Understanding Computation](http://computationbook.com/), donde hacen un ejercicio similar. En los próximos _posts_ vamos a desviarnos un poco. Primero vamos a ver una formulación alterna de lo que acabamos de hacer, que aprovecha un patrón común en programación funcional. Y después vamos a ver un tema que no es detallado en ése capítulo: cómo construir un objeto `Exp[V]` a partir de una cadena de caracteres, es decir el "_parseo_". 