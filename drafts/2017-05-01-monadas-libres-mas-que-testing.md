---
title: Monadas libres ¡mucho más que testing!
description: Un poco sobre porqué la idea de las monadas libres pueden servir para muchas más cosas además de testing
tags: Free Monads, Scala
---

Si están familiarizados con la idea de las monadas libres sabrán que uno de los atractivos es la posibilidad de testear fácilmente aplicaciones construidas con este patrón. Esto es una consecuencia de que con monadas libres la estructura de un programa queda separada de su interpretación. Eso es lo que permite "inyectar" un interprete distinto según sea la situación: si estamos ejecutando la aplicación en producción entonces usamos un intérprete que realice los _side-effects_ contra el "mundo real" pero si estamos en pruebas podemos usar un intérprete que nos permita _testear_ nuestra lógica.

Resulta que estructurar una aplicación con monadas libres permite mucho mas que esto. Empecemos con un ejemplo más o ménos simple 
