---
title: Entendiendo Haxl usando Scala: (Parte 0)
description: Parte 0 de una serie de posts que intentan explicar Haxl usando Scala
tags: Haxl, Haskell, Scala, Functional Programming, Free Monads, Monads, Applicative Functors, Concurrency
---

<img src="/images/haxl-logo.png" style="float: right; padding: 0.5em;">

[Haxl](https://github.com/facebook/Haxl) es una librería de Haskell que facilita la obtención de datos de diferentes fuentes. Haxl fue desarrollada por Facebook y en 2014 publicaron un [artículo académico](http://community.haskell.org/~simonmar/papers/haxl-icfp14.pdf) explicándola. Hace poco ménos de un año leí ese artículo y, para mi sorpresa, entendí lo suficiente como para tratar de traducirla a Scala. Escribo esta serie de entradas con la intención de usar Haxl como vehículo para hablar de varias cosas sobre programación funcional.

[//]: <> (Podría ser tema para otra entrada, pero resulta muy curioso que una empresa como Facebook, que todos conocemos y usamos, decida invertir en un paradigma no tan usado como lo es la programación funcional. Por ahora esta inversión parece ser en infraestructura como es evidenciado por éste proyecto y por otro como [Flow](http://flowtype.org/).)

Este es el inicio de una serie de posts en los que intentaré explicar qué hace Haxl y cómo está implementado. Para esto usaré código en Scala, que será una traducción más o ménos equivalente del mismo código en Haskell. Existen varias implementaciones en Scala: [una](https://engineering.twitter.com/university/videos/introducing-stitch) desarrollada por twitter y [otra](https://github.com/getclump/clump) por desarrolladores de soundcloud. La implementación de juguete que se mostrará en esta serie de posts, por su parte, se ceñirá mucho a su origen en Haskell pero utilizará muchas cosas propias de Scala.

[//]: <> (Nos toparemos con conceptos como "monadas" y "funtores aplicativos" que tienen nombres raros y hasta cierto punto podrían ser innecesarios. Si fuera posible no nombrar estos conceptos y aún así explicar Haxl lo haría. Sin embargo una de las principales agudezas de Haxl es aprovechar la diferencia entre estos conceptos para implementar una librería eficiente. En este sentido los conceptos "monadas" y "funtores aplicativos", palabras decididamente raras, nos sirven para referirnos a dos tipos de computaciones diferentes. Y el beneficio de usar esas extrañas denominaciones es comunicar los mismos conceptos.)

[//]: <> (> You can capture abstractions as classes, interfaces, and functions that you can refer to in your actual programs. But the primary benefit is *conceptual integration*. When you recognize common structure among different solutions in different contexts, you unite all of those instances of the structure under a single definition and give it a *name*. The benefit, as you gain experience with this, is that you can look at the general shape of a problem and say, for example: “That looks like a *monad*!” You’re then already far along in finding the shape of the solution. A secondary benefit is that if other people have developed the same kind of vocabulary, you can communicate your designs to them with extraordinary efficiency.)

Entonces empecemos:

### ¿Para que sirve Haxl?

[Principalmente](https://code.facebook.com/posts/302060973291128/open-sourcing-haxl-a-library-for-haskell/) Haxl permite:

* Acumular multiples consultas a una fuente de datos en una sola consulta en _batch_.
* Realizar consultas en paralelo sobre multiples fuentes de datos.
* Cachear consultas anteriores.

Esto le permite a un programador delegar el _batching_, paralelismo y cacheo a la librería y así concentrarse en la lógica de negocio. Esto facilita escribir código que es mas entendible y que al mismo tiempo tiene buen rendimiento. Y dado que tendencias actuales como microservicios exigen el uso de multiples fuentes de datos Haxl aparece como una excelente alternativa a hacer estas optimizaciones manualmente.

Veamos cada uno de los anteriores puntos en detalle:

### _Batching_

¿A que me refiero con _batching_? Digamos que tenemos un _endpoint_ HTTP donde podemos solicitar un recurso, por ejemplo un usuario según su id:

```
GET /usuarios/<id-usuario>
``` 

y queremos consultar los usuarios con identificadores `usuario-1`, `usuario-2` y `usuario-3`. Podríamos realizar 3 consultas independientes a ese _endpoint_:

```
GET /usuarios/usuario-1
``` 

```
GET /usuarios/usuario-2
``` 

```
GET /usuarios/usuario-3
``` 

Pero esto es costoso, aun cuando paralelicemos las consultas. Estámos abriendo y cerrando 3 conexiones HTTP a, posiblemente, la misma maquina. En cambio si el _endpoint_ ofrece un API en _batch_ podríamos hacer una sola solicitud:

```
GET /usuarios?ids=usuario-1,usuario-2,usuario-3
```

Esto no solo cuenta para APIs HTTP. Por ejemplo Redis tiene el comando [MGET](http://redis.io/commands/mget) que permite obtener múltiples valores a partir de una secuencia de llaves.

La promesa de Haxl en este aspecto es hacer el _batching_ automáticamente (dado que uno configure la librería para que reconozca el API en batch) sin que el programador tenga que hacerlo. El programador por su parte puede trabajar pensando que va a utilizar el API que retorna un solo recurso y Haxl se encargaría de identificar consultas que se pueden acumular. 

### Paralelismo

Ahora, ¿qué pasa si hay que consultar, de forma independiente, multiples fuentes de datos? Por ejemplo: un recurso `/usuarios` y otro `/blogs`. En estos casos, cuando las consultas son *independientes* (una no depende del resultado de la otra) se pueden paralelizar las consultas y posteriormente unir sus resultados para su procesamiento en conjunto. Las promesas o futuros son una solución a estos problemas. En efecto estos mecanismos sirven para paralelizar, unir y secuenciar computaciones. Pero desafortunadamente no proveen las otras ventajas de Haxl. Sin embargo, como verémos más adelante Haxl ofrece un API de combinadores funcionales muy similares a los de los futuros.

## Cacheo

Por último ¿qué pasa si en el curso de atender una solicitud debemos consumir otra API posiblemente multiples veces y existe la posibilidad de que consultemos el mismo recurso mas de una vez? Por ejemplo en el siguiente diagrama el microservicio `A` para responder el recurso `X` posiblemente necesite el recurso `Y` que está en el microservicio `B`:

<img src="/images/sketch.png" width="40%" style="display: block; margin-left: auto; margin-right: auto;"></img>

Además dicha solicitud se puede dar en dos lugares distintos: en la función `f1` o en la función `f3`. Una optimización obvia es que `f1` propague el valor de `Y` hasta `f3`, posiblemente modificando la firma de `f2` para que simplemente propague el valor. Tal vez esta no sea una solución tan mala en este caso, pero uno puede imaginarse casos mas complicados: ¿que pasa si se trata de más de un recurso? ¿que pasa si entre `f1` y `f3` hay muchas mas funciones? ¿que pasa si la obtención del recurso es condicionada por algún predicado? y así...

De forma similar a los anteriores puntos Haxl ofrece manejar esta responsabilidad sin que el desarrollador tenga que hacerlo explícitamente. En estos casos el programador trabaja cómo si siempre estuviera accediendo al recurso remoto, pero finalmente accediendo al recurso cacheado, si lo hay.

Esto, además de los claros beneficios en rendimiento y en claridad de código, tiene una ventaja desde el punto de vista funcional. Esto permite recuperar la *transparencia referencial* cuando se consultan datos de fuentes externas, lo que es algo que normalmente no se tiene aún en lenguajes puramente funcionales cómo Haskell. 

### Rompiendo reglas

Por último me gustaría detallar las cosas que me parecen mas interesantes de Haxl. Por una parte Haxl es interesante por que hace uso de conceptos rimbonbantes como monadas, funtores aplicativos y monadas libres, entre otros. Pero más allá de eso lo más interesante es que en su construcción Haxl ha roto muchas "reglas" o "dogmas" usuales en programación funcional. 

Por ejemplo, la implementación de Haxl viola una propiedad que exige la consistencia entre la definición como monada y como funtor aplicativo. Si esto suena pedante es por que lo es. Romper esta regla es uno de los puntos más centrales del artículo y sin esto Haxl no tendría sentido. 

Por otra parte en Haxl pululan las referencias mutables (como se debería de esperar dado el cacheo), que son una de las primeras cosas que uno aprende que son "malas" en programación funcional.

Y por último uno de los dogmas mas comunes en programación funcional tipada es la idea de que el código, por construcción y buen uso de los tipos, debe evitar errores en tiempo de ejecución. En esencia: si el código pasa el chequeo de tipos no debería haber razón para que haya errores en tiempo de ejecución. Para garantizar esto uno tendría que evitar mecanismos que "engañan" al sistema de tipos como por ejemplo casteos. Haxl en su implementación utiliza dos mecanismos no seguros: casteos y un match no seguro (para los que sepan de Scala esto sería similar a invocar `Option#get`).