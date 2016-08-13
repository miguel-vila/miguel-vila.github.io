---
title: Monoides, homomorfismos y homomorfismos de monoides
description: Sobre monoides, homomorfismos y otras cosas
tags: Matemáticas, homomorfismos, isomorfismos, asociatividad
---

Un monoide es un conjunto con una operación binaria sobre ese conjunto que sea asociativa y que tenga un elemento identidad. Más formalmente un conjunto $A$ y una operación binaria $+ : (A,A) \Rightarrow A$ forman un monoide si:

* Para todo $x,y,z \in A$ se cumple que $(x + y) + z = x + (y + z)$
* Existe un elemento $e \in A$ tal que para todo $a \in A$ se cumple que $e + a = a + e = a$ 

La palabra monoide simplemente formaliza una noción que de seguro ya habrémos visto con anterioridad. Por ejemplo:

* Los enteros con la suma y la identidad el cero.
* Los enteros con la multiplicación y la identidad el uno.
* Las cadenas con la concatenación y la identidad la lista vacía.


Un homomorfismo es, en palabras simples, una transformación que "conserva" la forma. El nombre mismo lo dice: _homo_ mismo, _morfismo_ forma. 

Siendo más formales supongamos un conjunto $A$ con una operación binaria $*$ y otro conjunto $B$ con su propia operación binaria $+$. Entonces una función $f : A \Rightarrow B$ es un homomorfismo con respecto a ambas operaciones si se cumple que:

<p style="text-align: center">
$f(x*y) = f(x) + f(y)$
</p>

En otras palabras: si operar los elementos en $A$ y después aplicar la transformación resulta en lo mismo que aplicar la transformación a cada elemento y después operar los elementos en $B$.

Veamos un ejemplo simple en programación, usando Haskell:

* Nuestros conjuntos seran `String` e `Int`
* Nuestra operación en las cadenas de texto será la concatenación `(++)`
* Nuestra operación en los enteros será la suma `(+)`
* Nuestra transformación será `length`, que retorna un entero que es la longitud de la cadena de entrada

Es fácil ver que:

```haskell
length ( x ++ y ) == (length x) + (length y)

```

Es decir la función `length` se puede descomponer operando a operando y seguirá dando el mismo resultado (con respecto a `(++)` y `(+)`).

Pero por el contrario la función `size` en los conjuntos, junto a las operaciones `union` y `(+)` no son un homomorfismo. Por ejemplo

```haskell
import Data.Set (union, fromList, size)

let s1 = fromList [1,2,3]
    s2 = fromList [3,4,5]
in size (union s1 s2) == (size s1) + (size s2)
```

Al unir el conjunto $\{1,2,3\}$ con el conjunto $\{3,4,5\}$ obtenemos el conjunto $\{1,2,3,4,5\}$, cuyo tamaño es $5$. En cambio el tamaño de cada conjunto, independientemente, es $3$ y al sumar ambos tamaños obtenemos $6$. Esto sucede por que `union` es una operación que no conserva la forma de sus entradas.

Para contrastar supongamos que alguien nos pone un acertijo para encontrar el operando original de una transformación. En el caso de las cadenas y la longitud alguien nos dan la cadena de texto `"abc"` y nos dicen que el resultado de una concatenación `"abc" ++ x` es `"abcde"`. Entonces es fácil deducir que `x == "de"`.

Ahora en cambio si alguien nos pone el mismo acertijo con conjuntos y uniones no siempre vamos a poder obtener una respuesta única. Por ejemplo el conjunto $\{1,2,3\}$ y la "ecuación" $\{1,2,3\} \cup X = \{1,2,3,4\}$. La única cosa que podemos decir con certeza es que $4 \in X$. Pero $X$ podría ser $\{1,4\}$ o $\{2,4\}$ o $\{1,2,4\}$, etc... Y esto pasa, como se podrán dar cuenta, por que la unión revuelve ambos operandos en una sopa que es imposible de separar con exactitud.

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
## Isomorfismos

Un isomorfismo "simplemente" es un homorfismo biyectivo. ¿Qué significa biyectivo? Simplificando la cosa un poco significa que la transformación es un emparejamiento perfecto: que a cada elemento en $B$ le corresponde exactamente un elemento en $A$. Con nuestro ejemplo anterior de las cadenas esto no sucede ya que existen muchas cadenas con la misma longitud. Por ejemplo si alguien nos dice que `length x == 2` y después nos pregunta a qué es igual `x` entonces no podemos dar una respuesta única. Podría ser la cadena `"ab"` o `"xy"`, etc... 

En cambio si nos restringimos a las cadenas formadas únicamente con el caracter `'s'` y al conjunto de los naturales entonces si nos encontramos con un isomorfismo. El conjunto de cadenas $S=\{$ `""`,`"s"`,`"ss"`,`"sss"`$,...\}$. En este caso, dado un número natural, es fácil revertir el proceso e identificar la cadena origen.
</div>
</div>

## Contando palabras

Una aplicación 