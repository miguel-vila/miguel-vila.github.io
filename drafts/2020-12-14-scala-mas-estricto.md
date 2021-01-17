---
title: Scala más estricto con scalafix
description: Como agregar aún más restricciones con Scalafix, para escribir código más seguro
tags: Scala
---

En proyectos pasados había usado [WartRemover](http://www.wartremover.org/) para forzar algunas verificaciones sobre el código.
Esto es importante por que ayuda a mantener la calidad del código y facilita _code reviews_. En particular permite evitar usar
cosas no tan seguras del lenguaje, por ejemplo:

- Invocar `.get` sobre un `Option` (o lo mismo sobre un `Left` o un `Try`).
- Evitar `.isInstanceOf` o `.asInstanceOf`. Usualmente estos son indicadores de que uno no está aprovechand ciertas cosas del lenguaje y está transformando errores de compilación en posibles errores en tiempo de ejecución.
- Declarar `var`s.

Una lista completa de los "warts" se encuentra [acá](https://www.wartremover.org/doc/warts.html).

