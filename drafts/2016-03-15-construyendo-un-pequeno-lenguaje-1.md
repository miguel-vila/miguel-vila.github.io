---
title: Construyendo un pequeño lenguaje de programación (Parte 1)
description: Segunda parte de una serie de posts en las que se construye un pequeño lenguaje de programación usando Scala
tags: Scala, Interpreter, Functional Programming, ADT, GADT, Reader Monad, Construyendo un pequeño lenguaje
---

En el [anterior _post_](miguel-vila.github.io/posts/2016-03-15-construyendo-un-pequeno-lenguaje-0.html) establecimos unas bases para poder construir nuestro pequeño lenguaje. Definimos un tipo llamado `Exp` que nos sirve para representa arboles de sintáxis y ahora el objetivo será tomar algo de ese tipo e interpretarlo.

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

(Aquí elegimos definir un método definido dentro del `trait` pero también es posible definir una función que tomara como argumento el `Exp[V]`. Sin embargo esta alternativa nos implica de)

Esto sirve muy bien para algunas expresiones aritméticas como "`1 + 3*( 2 + 7)`" e incluso comparaciones como "`1 < (2 * 3)`". Pero en cambio expresiones que usan variables como "`x + 1`" o "`i < 10`" no se ajustan al molde. Para poder evaluar este tipo de expresiones necesitamos tener acceso al entorno de variables definidas. Este entorno lo vamos a definir así:

```scala
type Environment = Map[String, Value]
```

Un entorno será algo que dado el nombre de una variable retorna su valor. Con esto podemos redefinir `evaluate` de la siguiente forma:

```scala
sealed trait Exp[ V <: Value ] {
    def evaluate(environment: Environment): V
}
```

Por último nos resta tener en cuenta el efecto de las asignaciones. Una asignación altera el entorno: inserta o actualiza un registro. Vamos a hacer las cosas de la forma funcional, es decir sin alterar el estado. Esto tiene varios beneficios: pero el principal es que para entender una función solo tenemos que tener en cuenta los argumentos de entrada e inspeccionar lo que retorna:

```scala
sealed trait Exp[ V <: Value ] {
    def evaluate(environment: Environment): (Environment, V)
}
```

Leyendo la firma de la función podemos decir que al evaluar una expresión obtenemos dos cosas: un entorno final y un valor. El tipo de esta función es `Environment => (Environment, V)`.

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

Podrán notar que aquí estamos rompiendo varias "reglas". Primero la forma en la que extraemos el valor del mapa no es segura: si no existe ninguna variable definida con el nombre entonces ese método arroja una excepción. Y segundo: estamos haciendo un _casteo_ que también podría fallar si existe una variable definida con ese nombre pero con el tipo incorrecto. La idea de esta serie de artículos es presentar algo muy simple. Sin embargo ambas situaciones sirven para hablar de qué decisiones toman algunos lenguajes.

<div class="note">
<p class="clickable aside-header"><strong>Nota aparte</strong> <span class="clickme">(Click!)</span></p>

<div class="note-content">

La primera situación, intentar usar una variable que no está definida, se convierte en un error en la mayoría de lenguajes. En algunos, como JavaScript o Python, este error se da en tiempo de ejecución. En cambio en otros lenguajes como Java o C (y en general lenguajes con tipado estático) este error se da en tiempo de compilación.

La segunda situación es más interesante: cuando una variable se intenta referenciar con un tipo distinto al que se usó cuando se definió. Esto sirve para ilustrar el difuso concepto de [tipado débil versus tipado fuerte](https://en.wikipedia.org/wiki/Strong_and_weak_typing). Algunos lenguajes como JavaScript intentan "adivinar" cuál era la intención del programador en unas cuantas de esas situaciones y adapta los tipos según corresponda. Es decir tiene una noción débil de cuales son los tipos. Por ejemplo:

```javascript
>> '2' * 3
6
>> '1' + 2
'12'
```

En estos casos se "relaja" el tipo  
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

