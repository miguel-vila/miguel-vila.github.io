---
title: Sobre sistemas de tipos
description: Una pequeña opinión sobre sistemas de tipos
tags: Type Systems, Opinion
---

Una de las ventajas de un sistema de tipos fuerte (¿qué es?) es la de evitar, en tiempo de compilación, errores comunes. Un ejemplo sencillo de esto es invocar una función con un argumento que es una cadena de texto cuando realmente la función espera recibir un entero:

```scala
def computeTotalPrice(numItems: Int): Double = ???

val userInput: String = ???
computeTotalPrice(userInput) // <- Type Error
```

En este caso el proceso que chequea la concordancia de los tipos (_type checker_) nos va a señalar el error y se puede corregir fácilmente.

* ejemplo más complejo

* la discusión types vs tests

* ejemplo de listas con tipo que codifica su longitud

* ¿es útil en prod?

* determinismo vs no determinismo

* ejemplo: funciones en Listas

* tipos excelentes para cosas deterministicas -> tests para cosas no deterministicas
