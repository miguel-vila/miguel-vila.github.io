---
title: Algo de lo que hice estas semanas (06/02/2017 - 19/02/2017)
description: Algo de lo que hice estas semanas (06/02/2017 - 19/02/2017)
tags: Vida
---

Terminé [_Sunset Park_](https://www.goodreads.com/book/show/7944987-sunset-park) de Paul Auster. Me gustó, fue una lectura rápida y al mismo tiempo con algo de profundidad. Empecé a leer [_Leviathan_](https://www.goodreads.com/book/show/456.Leviathan) pero esta vez en inglés. Hasta ahora también me ha gustado.

También terminé [_Understanding Computation_](http://computationbook.com/). Arreglé un [_bug_](https://github.com/miguel-vila/understanding-computation/commit/5ab0d0548e09cae43cb68d38981c1094ff43bfa0) que tenía en mi traducción a Scala de uno de los primeros capítulos. Había dejado la lectura en una parte en la que hablan de [_"Tag systems"_](https://en.wikipedia.org/wiki/Tag_system) (no sé cuál sea la traducción). Se trata de un modelo computacional muy simple que es [Turing-completo](https://en.wikipedia.org/wiki/Turing_completeness). Esta parte en la que me quedé era básicamente una sucesión de ejemplos de modelos computacionales que a pesar de sus diferencias o aparentes fortalezas resultan tener el mismo poder que una maquina de Turing. Francamente esta parte fué aburrida. 

Pero el siguiente capítulo fué mucho más interesante: habla sobre programas "imposibles", explica el problema de la parada y menciona qué es un [lenguaje de programación total](https://en.wikipedia.org/wiki/Total_functional_programming) entre otras cosas. También habla de un fenómeno bastante conocido y es el de que cuando un sistema es lo suficiente poderoso como para poder referenciarse y analizarse a sí mismo esto a su vez produce que el sistema tenga "agujeros". Esto es similar a uno de los [resultados de Gödel](https://en.wikipedia.org/wiki/G%C3%B6del%27s_incompleteness_theorems#First_incompleteness_theorem) con respecto a sistemas formales en matemáticas: cualquier sistema formal **consistente** es **incompleto**, es decir existen afirmaciones que el sistema formal no va a poder demostrar o rechazar. En computación la cosa es similar. Por ejemplo con lenguajes de programación: cualquier lenguaje con la capacidad de ser autorreferencial no es capaz de responder todas las preguntas sobre sí mismo.

Ahora quiero retomar [_GEB_](https://en.wikipedia.org/wiki/G%C3%B6del,_Escher,_Bach).

También he estado haciendo maricadas intentando entender eso que llaman "_type-level programming_" en Scala. Quiero ver si puedo programar [FizzBuzz](https://en.wikipedia.org/wiki/Fizz_buzz) en tipos. Hasta ahora logré escribir un _type-class_ que sirve como evidencia de que un número divide a otro. Esto fue en parte gracias a que Travis Brown [respondió una pregunta](http://stackoverflow.com/a/42328370/864306) que hice en StackOverflow.

Salí ambos domingos a montar en cicla. Tengo la esperanza de algún día subir Patios en menos de 35 minutos, que creo que fué mi record el año pasado. Los últimos 5 meses del año pasado casi no monté bici y eso me bajó el "nivel". Ahora estoy intentándo subir Patios pero sin dejar que los segmentos más difíciles me cuesten tanto y también intentado acelerar en los pocos segmentos semiplanos.

<div align="center">
<iframe height='405' width='590' frameborder='0' allowtransparency='true' scrolling='no' src='https://www.strava.com/activities/864314307/embed/296ca82217f1d389b0db5baa6f6f1b284543398c'></iframe>
</div>
