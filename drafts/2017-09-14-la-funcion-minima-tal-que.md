---
title: La función mínima
description: Un pensamiento suelto
tags: OOP, Diseño
---

Hay un "principio", a falta de una mejor palabra, para una idea que he visto al diseñar APIs. Esto es especificamente
al escribir un método/función. Se trata de qué elegimos que la función reciba y retorne.

Empecemos por qué debería recibir. Digamos que tenemos una función que toma un valor de tipo `Animal` (si, no tengo 
imaginación, síganme la corriente). La función, en su implementación, requiere usar ese parámetro de alguna forma. Por
ejemplo, invoca el método `respirar` sobre ese argumento. Y ahora, digamos que hay toda una jerarquía de subclases para
el tipo del argumento. Por ejemplo `Perro`, `Gato`, etc... Entonces, ¿Qué le deberíamos exigir a alguien que invoque
esta función si en la implementación solamente usamos el método `respirar`, qué todo `Animal` debería tener? Debería
ser claro que, dada esa condición sobre la implementación, no tiene sentido exigirle a alguién que invoque esta función
que pase, por ejemplo, solo valores de tipo `Perro`. Deberíamos, contentarnos con recibir cualquier cosa de tipo 

La razón es que uno debería **demandar lo ménos posible de aquél que invoque esta función**. Esto es útil por que 
podría permitir reusar esta función en muchos otros contextos, más de los que requieren las condiciones actuales. 
También es útil desde el punto de vista del implementador por que, mientras más general sea un tipo, ménos funciones/
métodos tiene, y por lo tanto es más claro cuál es la implementación correcta.

Empecé explicando esto usando subtipos/subclases. Pero este "principio" es más general y aplica a otras formas
de polimorfismo. Por ejemplo, digamos que vamos a escribir una función que invierte el orden de una lista. Usando la 
sintáxis de Haskell ¿tiene sentido que esa función tenga tipo `[Int] -> [Int]`? Puede que ahora mismo la necesitemos
solamente para listas de enteros, pero no hay nada en su implementación que lo exija. Un tipo más adecuado sería
`[a] -> [a]` dónde `a` es un tipo parámetro. Los beneficios siguen siendo los mismos que antes. 

(Esto está relacionado con la noción de parametricidad en [programación funcional](http://ecee.colorado.edu/ecen5533/fall11/reading/free.pdf))



Algunos lenguajes de programación tienen la noción de suptipos. Formalmente: 

> Un tipo $S$ es subtipo de un tipo $T$, denotado por $S \leq T$, si todos los valores en $S$ también 
> son valores en $T$. 

De forma práctica esto quiere decir que dónde requiera usar algo de tipo $T$ entonces también puedo usar 
algo de tipo $S$. En lenguajes orientados a objetos este concepto es materializado a través de la relación 
de subclases: si puedo invocar un método en un objeto de la clase `T` y la clase `S` es subclase de `T`
entonces puedo invocar ese mismo método en un objeto de clase `S`.

Podemos usar la relación $\leq$ para crear un órden parcial sobre tipos y dados dos tipos podemos intentar
responder la pregunta de si uno es un subtipo del otro. 

Podemos hacernos esa pregunta con el tipo de dos funciones, digamos $S_1 \Rightarrow T_1$ y $S_2 
\Rightarrow T_2$. ¿Cómo se deberían relacionar $S_1$ con $S_2$ y $T_1$ con $T_2$ para que $(S_1 
\Rightarrow T_1) \leq (S_2 \Rightarrow T_2)$? Resulta que para que esto suceda se tiene que dar que 
$S_2 \leq S_1$ y $T_1 \leq T_2$, un hecho que se suele resumir diciendo que las funciones son 
contravariantes en sus argumentos y covariantes en sus retornos.

Una explicación de por qué esto último se puede encontrar en [este](https://www.irif.fr/~gc/papers/contravarianceagain.pdf) _paper_:

<img src="/images/paper-cov-contra.png" style="display: block; margin-left: auto; margin-right: auto; padding: 0.5em; width: 65%;">

</div>
</div>

Digamos que al diseñar un API tenemos la opción de implementar una función con distintos tipos. Por lo
general queremos imponerle la mínima cantidad de restricciones al invocador, es decir queremos que los
parámetros de una función sean tan generales como sea posible. Por ejemplo si una función necesita algo
con la capacidad de 

Y por otra parte también es ideal que
le devolvamos algo del tipo mas preciso en lo posible.


La función que le exija lo ménos posible al que la invoca y que le devuelva lo más específico que pueda.
