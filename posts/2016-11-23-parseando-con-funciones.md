---
title: Parseando con funciones
description: Cómo podemos parsear usando solamente funciones y combinandolas
tags: Scala, Parsing, Functional Programming, Parser Combinators
---

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Este _post_ iba a ser originalmente el último de [esta](https://miguel-vila.github.io/tags/Construyendo%20un%20peque%C3%B1o%20lenguaje.html) serie pero creo que terminé escribiendo algo que es más autocontenido. Tal vez con el tiempo escriba el último _post_ de esa serie.

_Sorry_ por el [spanglish](http://dle.rae.es/?w=parsear) en este _post_.
</div>
</div>

¿Qué significa _parsear_? Es el proceso de tomar una secuencia de _tokens_ (usualmente caracteres) y construir alguna estructura de datos. Esta estructura de datos usualmente tiene significado dentro del dominio de un programa. Por ejemplo puede ser un objeto JSON: 

* Tomamos una cadena de caracteres como `"{ "foo":"bar" , "baz": 1 }"`.
* Retornamos una estructura como `Map(foo -> "bar" , baz -> 1)`

## Una aproximación funcional

La idea de construir un _parser_ siempre se me ha hecho intimidante. Es el tipo de problema al que no sabía como aproximarme. Pero gracias a un acercamiento funcional esa tarea se vuelve más accesible y entendible. Este acercamiento consiste en describir qué es un _parser_ en terminos de funciones.

Intentémos describir cómo se vería una función que _parsea_ alguna estructura de datos. Si nuestro objetivo es manipular números enteros entonces el tipo de nuestro _parser_ podría ser:

```scala
String => Int
```

En cambio si nuestro objetivo es manipular `Float`s entonces podría ser:

```scala
String => Float
```


## Refinando la definición

En general si nuestro objetivo es _parsear_ algo de tipo `A` entonces el tipo de nuestro _parser_ será:

```scala
String => A
```

Creemos un _type alias_ para esto:

```scala
type Parser[A] = String => A
```

Pero esto no tiene en cuenta varias cosas. La primera es que esto no tiene en cuenta los errores que se pueden producir al intentar _parsear_ alguna estructura que no tiene sentido. Podríamos usar un tipo como `Either` pero un acercamiento más simple es una lista que estará vacía si al intentar _parsear_ se produjo un error. Nuestro tipo refinado será:

```scala
type Parser[A] = String => List[A]
```

Por último queremos combinar nuestros _parsers_ para expresar _parsers_ más complejos. Digamos que queremos _parsear_ expresiones que son sumas. Por ejemplo cadenas como "123+456". Y digamos que tenemos algo que _parsea_ un número y algo que parsea el signo `+`. Entonces deberíamos poder combinar ambos de la siguiente forma: "Primero _parsee_ el primer número, después _parsee_ el signo más y por último _parsee_ el segundo número". Pero bajo nuestro esquema actual no hay forma de hacerlo por que nuestras funciones _parseadoras_ hacen "demasiado". La cosa funciona bien para una cadena que en su totalidad consiste de un número:

```scala
val parseNumber: Parser[Int] = ???
parseNumber("123")
//List(123)
```

Eso está bien, pero cuando le pasamos un `String` que al principio tiene un número entonces va a fallar:

```scala
val parseNumber: Parser[Int] = ???
parseNumber("123+456")
//List()
```

Falla justificadamente por que toda la cadena `"123+456"` no es un número. Más sin embargo el principio de la cadena sí es un número. Ahora mismo el significado de nuestro tipo `Parser` es demasiado estricto. Es "_parsee_ **toda** la cadena de entrada y devuelva un valor si es posible". Pero para poder **"componer"** con otros _parsers_ quisieramos ejecutar ese _parser_ para que identifique el **primer** número que pueda y una vez hecho eso disponer del **resto de la cadena** para que podamos _parsear_ otras cosas. Podemos ajustar nuestra definición para que no necesariamente _parsee_ toda la cadena de entrada y para que devuelva el resto de cadena que no fue utilizada durante el _parseo_. Ajustando el tipo tenemos lo siguiente:

```scala
type Parser[A] = String => List[(A,String)]
```

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
Este tipo también se puede leer en como una rima en inglés (Tomado de [Programming in Haskell](https://www.amazon.com/Programming-Haskell-Graham-Hutton-ebook/dp/B01JGMEA3U/) por Graham Hutton):

_A parser for things_

_Is a function from strings_

_To lists of pairs_

_Of things and strings_
</div>
</div>

Para facilitarnos la cosa un poco no vamos a hacer que nuestro tipo `Parser` sea un alias sino que esté contenido como el atributo de una clase:

```scala
case class Parser[A](run: String => List[(A,String)]) extends AnyRef {

}
```

Esto nos permitirá agregar métodos.

## Un _parser_ muy básico

Uno de los _parsers_ más básicos que podemos escribir es el que consume el primer caracter de una cadena, si es que existe:

```scala
val parseChar: Parser[Char] = 
    Parser { str =>
        if(str.isEmpty)
            List.empty
        else
            List( (str.head, str.tail) )
    }
```

Pero si queremos reconocer un solo dígito necesitamos reconocer si un caracter es o no un número. Podemos agregar una función `filter` que nos permita filtrar los resultados de un _parseo_:


```scala
case class Parser[A](run : String => List[(A,String)]) extends AnyRef { self => //(1)
                                                                       
    def filter(f: A => Boolean): Parser[A] = 
        Parser { str => //(2)
            self.run(str).filter { case (value,_) => //(3)
                f(value)
            }
        }
        
}
```

Vamos por partes: en **(1)** ponemos el nombre `self` a la instancia actual para podernos referir a ella desde otras instancias de `Parser`. En **(2)** iniciamos una nueva instancia de `Parser`. Esta instancia deberá leer un `String` y retornar algo de tipo `List[(B,String)]`. En **(3)** ejecutamos el _parser_ inicial (para esto hacemos `self.run`), lo que nos retorna una lista de `List[(A,String)]` que a su vez filtramos conservando las tuplas cuyo primer elemento cumpla el predicado que recibimos como argumento.

Podríamos entonces tener un _parser_ de dígitos así:

```scala
val parseDigit: Parser[Char] =
    parseChar.filter { c => '0' <= c && c <= '9' }    
```

Pero tal vez quisieramos que el valor reconocido por el _parser_ sea por ejemplo el **número** `1` y no el **caracter** `'1'`. Entonces necesitamos una forma de transformar el valor reconocido por el _parser_. Es decir una función que nos permita transformar el valor _parseado_:

```scala
case class Parser[A](run : String => List[(A,String)]) extends AnyRef { self =>

    def map[B](f: A => B): Parser[B] =
        Parser { str =>
            self.run(str).map { case (value,rest) =>
                (f(value),rest)
            }
        }

}
```

Así podemos volver a escribir nuestro _parser_ de dígitos (nótese que ahora el tipo es `Parser[Int]` y no `Parser[Char]`):

```scala
val parseDigit: Parser[Int] =
    parseChar
        .filter { c => '0' <= c && c <= '9' }
        .map { c => c - '0' }
```

## Parseando alternativas

En ocasiones vamos a necesitar describir un _parser_ como el resultado de múltiples alternativas. Por ejemplo:

```scala
val parseTrue  = parseChar.filter( c => c == 't' ).map( _ => true )
val parseFalse = parseChar.filter( c => c == 'f' ).map( _ => false )
val parseBoolean = ???
```

Para hacer esto podemos tomar dos _parsers_, ejecutar el primero sobre la cadena de entrada y si eso arroja un resultado retornarlo, de lo contrario retornar lo que devuelva ejecutar el segundo _parser_:

```scala
case class Parser[A](run : String => List[(A,String)]) extends AnyRef { self =>

    def or(other: => Parser[A]): Parser[A] = Parser { str =>
        val firstResult = self.run(str)
        if(!firstResult.isEmpty) {
            firstResult
        } else {
            other.run(str)
        }
    }

}
```

Y así podemos describir el anterior _parser_ como:

```scala
val parseBoolean = parseTrue or parseFalse
```

## Secuenciando _parsers_

Digamos que en nuestra aplicación nuestros ids consisten de un dígito y de un caracter en mayúsculas:

```scala
case class Id(n: Int, char: Char)
```

Guardamos en algún lado los ids como String y quisieramos _parsear_ esos `String`s para convertirlos en objetos de tipo `Id`. El formato con el que los guardamos es primero el dígito concatenado con el caracter. Por ejemplo "5A". Podríamos hacer algo como lo siguiente:

```scala
val idParser: Parser[Id] = Parser { str =>
  if(str.length() < 2) {
    List.empty
  } else {
    val nchar = str(0)
    if(isDigit(nchar)) {
      val n: Int = nchar - '0'
      val char = str(1)
      if( 'A' <= char && char <= 'Z') {
        List((Id(n,char), str.substring(2)))
      } else {
        List.empty
      }
    } else {
      List.empty
    }
  }
}
```

Pero acá estamos repitiendo mucho de lo que hicimos antes: no estamos aprovechando el hecho de que ya definimos un `parseDigit` y un `parseChar`. El patrón general que estamos buscando es el siguiente: ejecutamos un _parser_, con lo que queda de cadena sin procesar ejecutamos otro _parser_ y si ambos son exitosos combinamos los valores parseados de alguna forma. La firma de la función que podríamos estar buscando es algo como:

```scala
(Parser[A], Parser[B], (A,B) => C) => Parser[C]
```

Creo que usualmente esta operación se llama `map2`. La podríamos implementar así:

```scala
def map2[A,B,C](p1: Parser[A], p2: Parser[B], f: (A,B) => C): Parser[C] = 
  Parser { str =>
    for {
      (a, rest1) <- p1.run(str)
      (b, rest2) <- p2.run(rest1)
    } yield (f(a,b), rest2)
  }    
```

Aquí estamos aprovechando que `run` retorna una lista para realizar un _for comprehension_. También cabe notar como estamos pasando los argumentos `rest1` y `rest2`. Esto es importante para conservar el significado de _parser_: usamos partes de la cadena y siempre retornamos el pedazo de cadena que no procesamos.

Ahora podemos reescribir `idParser` así:

```scala
val idParser: Parser[Id] = 
    map2(parseDigit, parseChar.filter(isUpperCase), (n: Int, c: Char) => Id(n,c) )
```

Mucho más conciso así, ¿no?

Todas estas funciones que tomán uno o más `Parser`s y retornan uno nuevo son denominadas **combinadoras**. Aquí yace la riqueza del acercamiento funcional: en vez de describir explícitamente paso a paso lo que el `Parser` debe hacer podemos usar funciones combinadoras y poco a poco expresamos lo que deseamos.

## Una algebra con un constructor base

Hasta ahora pareciera que estamos construyendo una algebra que nos permite combinar valores de tipo `Parser`. Como es usual nos puede servir una función que coja un valor cualquiera y lo encierre como un valor dentro de la algebra. Podemos llamar esta función `succeed` por que es como construir un _parser_ que siempre será exitoso con el valor que le pasemos:

```scala
def succeed[A](value: A): Parser[A] = Parser { str => (value,str) }
```

Está función nos servirá más adelante para definir ciertos casos base.

## Repeticiones

Ahora queremos _parsear_ no solamente un caracter sino una repetición de caracteres. Por ejemplo podríamos querer _parsear_ las cadenas de texto que empiezan por cero o más `A`s. 

```scala
def rep[A](pa: Parser[A]): Parser[List[A]] = ???

val charA = parseChar.filter(_ == 'A')
val parseAs = rep(charA)

parseAs.run("AAAAxxx")
// List( (List('A','A','A','A'), "xxx") )

parseAs.run("xxx")
// List( (List(), "xxx") )
```

Podríamos intentar primero parsear una `A`, si eso falla, como en el segundo ejemplo retornamos una lista vacía. Si logramos parsear una `A` cogemos el resto de la cadena e intentamos parsear una repetición de `A`s sobre esa cadena (es decir: ¡recursión!) y por último cogemos lo que retorne ese _parseo_ y lo combinamos con la primera `A` que _parseamos_.

Resulta que para hacer lo anterior YA tenemos los suficientes ingredientes:

```scala
def rep[A](pa: Parser[A]): Parser[List[A]] = 
    map2(pa, rep(pa), (a:A, tl: List[A]) => a :: tl ) or succeed(List.empty)
```

Esto funciona así:

El primer parser (lo que va antes del `or`) se encarga de _parsear_ una lista no vacía de caracteres. Si ese primer _parser_ falla el `or` se encargará de reintentar con el segundo que siempre va a ser exitoso con una lista vacía. El primer _parser_ funciona _parseando_ una sola instancia (el argumento `pa`), después **recursivamente** _parsea_ otra lista de repeticiones del resto de la cadena y une los dos resultados concatenándolos.

Pero resulta que si intentamos usar `rep` vamos a obtener un _overflow_ de la pila de ejecución. Esto es por que la definición recursiva se está expandiendo indefinidamente:

```scala
rep(charA) == map2(charA, rep(charA), ...) or (...)
           == map2(charA, map2(charA, rep(charA), ...) or (...), ...) or (...)
           == etc...
```

El problema es que antes de que se ejecute `map2` se deben evaluar sus argumentos. Esto se puede solucionar haciendo que el segundo argumento de `map2` sea [_call by name_](https://www.safaribooksonline.com/library/view/programming-scala/9780596801908/ch08s12.html) de forma tal que las invocaciones no lo evaluan inmediatamente:

```scala
def map2[A,B,C](p1: Parser[A], p2: => Parser[B], f: (A,B) => C): Parser[C] = ...
```

## Cuando el contexto importa

Digamos que tenemos que reconocer las cadenas que empiezan por un número y después de las que hay tantas `X's como ese número. Por ejemplo "1X" o "2XX" o "3XXX", etc... Primero construyamos un _parser_ para repeticiones fijas de un _parser_:

```scala
def repN[A](p: Parser[A], n: Int): Parser[List[A]] = 
    if(n == 0) {
        succeed(List.empty)
    } else {
        map2(p, repN(p,n-1), (head: A, tail: List[A]) => head :: tail)
    }
```

Eso funciona cuando sabemos cuantas repeticiones queremos:

```scala
val twoXs = repN(parseChar.filter(_ == 'X'), 2)
twoXs.run("XXA")
// List((List('X', 'X'), "A"))
```

Con esto podríamos construir un _parser_ para el caso especial de cuando el número es `2`:

```scala
map2(
    parseChar.filter(_ == '2'),
    repN(parseChar(_ == 'X'), 2), 
    (c: Char, reps: List[Char]) => (c,reps)
)
```

Pero queremos generalizar esto para cualquier entero que se nos pueda aparecer. El problema es que tenemos 2 _parsers_ y el segundo tiene un pedazo de información que depende del resultado del primero. Más concretamente el parámetro `n` del segundo parser depende de lo que aparezca al principio de la cadena: si _parseamos_ un caracter `'3'` entonces en el momento de construir el segundo _parser_ el parámetro `n` deberá ser el número `3`. El patrón que estamos buscando es el siguiente:

* _Parseamos_ usando un _parser_ lo que nos arroja un resultado y el resto de la cadena.
* Con ese resultado construimos un nuevo _parser_ que usamos para el resto de la cadena.

Llamemos a esta operación `andThen` por que dice sirve para "secuenciar" resultados. Podría tener una firma como la siguiente:

```scala
def andThen[A,B](first: Parser[A], f: A => Parser[B]): Parser[B]
```

Recibe un primer _parser_ y una función que construye un nuevo _parser_ usando el resultado del primero. Al final devuelve lo que devuelva ese segundo _parser_ que construimos. Implementémosla:

```scala
def andThen[A,B](first: Parser[A], f: A => Parser[B]): Parser[B] = Parser { str =>
   first.run(str).map { case (a, rest1)  =>
          f(a).run(rest1)
      }.flatten
   }
```

Y podemos ver este nuevo combinador en acción:

```scala
val parseNandReps = 
  andThen(
    parseDigit,
    { n: Int => 
      repN(parseChar.filter(_ == 'X'), n) 
    }
  )
  
parseNandReps.run("2XX")
// List((List('X', 'X'), ""))
parseNandReps.run("3XX")
// List()
``` 

Este es un ejemplo de algo que las expresiones regulares no pueden hacer: interpretar el resultado de un _parseo_ parcial para continuar _parseando_.

## Solo el principio

Con estas bases se pueden construir _parsers_ para cosas más complejas: por ejemplo expresiones aritméticas, JSON _objects_ o incluso podemos construir el árbol de sintáxis de un lenguaje de programación. Incluso para cosas más simples pueden reemplazar expresiones regulares y pueden servir para terminar con código más entendible.

Por ejemplo para _parsear_ expresiones aritméticas en una hoja de cálculo escribí [esto](https://github.com/miguel-vila/hoja-calculo/blob/3a2206569a0019117a5488cc533bb4c3a21051b7/client/src/main/scala/spreadsheet/parsing/Parser.scala#L7). Son ménos de 60 líneas de código y usan la librería estándar de _parser combinators_ de Scala. Esa librería tiene muchas más funciones de las que describí acá, pero la idea base es la misma.

Así que si algún día necesitan _parsear_ algo pueden usar esta aproximación. Es fácil de entender y el código resultante suele ser legible.

## Fuentes y otros enlaces

Este _post_ está basado en lo que aprendí leyendo varias fuentes:

* El Capítulo 9 de [Functional Programming in Scala](https://www.manning.com/books/functional-programming-in-scala): Toman un acercamiento distinto para explicar la idea general de _parser combinators_.
* Múltiples artículos por Erik Meijer y Graham Hutton: [Este](http://www.cs.nott.ac.uk/~pszgmh/monparsing.pdf) es bastante detallado y [este](http://www.cs.nott.ac.uk/~pszgmh/pearl.pdf) es mucho más conciso.

Varias librerias que implementan de formas distintas la misma idea:

* En JavaScript está [mona](https://github.com/zkat/mona)
* En Scala: [uno de la librería estándar](https://github.com/scala/scala-parser-combinators) y [FastParse](http://www.lihaoyi.com/fastparse/)
* En Haskell: [Parsec](https://wiki.haskell.org/Parsec) y también está [Attoparsec](https://hackage.haskell.org/package/attoparsec)

Una forma alternativa (no funcional) de _parsear_ es [esta](https://en.wikipedia.org/wiki/Recursive_descent_parser).
