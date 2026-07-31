---
title: Diez años en la industria
description: Algo de lo que he aprendido después de diez años en la industria
tags: software engineering, career development
include_plotly: false
---

Llevo poco más de 10 años en la industria del desarrollo de software, y a forma
de conmemoración voy listar algunas lecciones que he tenido y que me han
cambiado la perspectiva sobre lo que hacemos.

Sin más:

## Ir lento no es ir seguro

Esto aplica a muchas cosas, y es un poco relacionado a la aversión al
riesgo. Un ejemplo:

* La empresa A establece que solo se puede desplegar a producción una vez al
  mes.
* La empresa B establece que cada equipo elige cuando desplegar según como le
  convenga.

¿Cuál empresa piensan que va a tener más errores en producción? Esto será obvio
para cualquier persona que haya estado en esta industria por algún tiempo pero
no lo era para mí: La empresa B va a encontrar errores más rápido. Al desplegar
con mayor frecuencia, menos errores se van a acumular y la retroalimentación
será mas rápida. Mientras mas pequeño sea un _release_ menor será la probabilidad de que
tenga un _bug_. Un _release_ que acumula muchos cambios por otra parte, puede
contener muchos _bugs_ en potencia, y a la hora de "debuggear" algo no quieres
revisar muchos cambios.

El punto mas general es que hay prácticas que tienen la apariencia de ser más
seguras (como esa de desplegar solo en ciertos días), pero que reflejan una
aversión al riesgo que puede ser contraproducente a largo plazo.

Esto también aplica a otras cosas como el mismo flujo de un proyecto.
TODO poner ejemplo

## ¡El trabajo son detalles técnicos!

Una frase que escuchaba en Colombia, y que seguro yo también pronuncié, era "eso
es un detalle técnico" para referirse a que cierto detalle no necesita
discutirse en tal reunión por que es un detalle de implementación. Y no sé si la
cosa es que en Colombia la gente se acostumbra a hablar mierda (o
[_"handwave"_](https://en.wikipedia.org/wiki/Hand-waving) en inglés) pero es
común escucharla.

Resulta que los detalles técnicos no son cosa menor. ¡Los "detalles técnicos"
son el trabajo! Resolver las consecuencias e implicaciones de esos detalles
es parte de lo que hacemos. Necesitamos implementar una nueva funcionalidad:
¿cuáles son las implicaciones? ¿Es técnicamente posible? ¿Tenemos que hacer
alguna migración de datos? ¿Estamos seguros de que esta funcionalidad no va a
romper alguna cosa en otra parte del sistema?

Es claro que para ciertos problemas no podemos determinar todos los detalles
técnicos de frente. Lo que queremos, en cambio, es detallar lo suficiente como
para saber que el camino es viable y no van a haber obstáculos que nos obliguen
a detenernos a mitad de camino. Significa hacer la "debida diligencia" para
ahorrarnos problemas.

Cuando he entrevistado ingenieros, en la entrevista de "diseño de sistemas", he
notado que es la parte en la que uno puede separar a la gente que habla mierda y
la gente que sabe que hay que detallar soluciones. Como entrevistador, uno puede
pedirle al entrevistado que detalle al máximo: no es suficiente un diagrama de
componentes de alto nivel. En cambio, que haga un bosquejo del API, que detalle
las estructuras de datos, que escriba algo de pseudocódigo, etc... Haciendo esto
el candidato se puede dar cuenta de que lo que propuso tiene o no sentido.
Y dependiendo de como reaccione, uno puede determinar si es el tipo de ingeniero
que se ha acostumbrado a atacar problemas técnicos de forma detallada o no.

Imaginen que, en una entrevista de estas, el candidato propone usar un producto
de terceros para resolver la totalidad del problema (esta sería la forma más grande de hacerle _handwave_ a un problema). Aparte del obvio _"vendor lock-in"_, ¿el candidato puede explicar en
detalle cuales serían las consecuencias? ¿el candidato está seguro que ese producto
resuelve el problema con las garantías y funcionalidades que necesitamos? ¿el
candidato sabe exactamente qué funcionalidades del producto (e.g. cuales APIs)
debemos usar y qué implicaría conectar nuestro sistema con ese producto?

En otras palabras: no le hagan _handwave_ a problemas técnicos,
[sean específicos](https://www.lesswrong.com/posts/NgtYDP3ZtLJaM248W/sotw-be-specific).

## Tener la carne en el asador

Creo que nunca he trabajado en un sitio donde haya arquitectos. Es decir,
personas cuyo único trabajo es diseñar sistemas para que _otros_ los implementen.
Lo que he visto en cambio, es que si tu lo propones, tu lo implementas, mantienes
y operas (esto último ha cambiado un poco con las últimas tendencias de la
industria pero no voy a desviarme). Tal vez no en su totalidad, pero diseñar
algo usualmente ha implicado estar involucrado en su ejecución.

El punto es que la mejor forma de construir sistemas es alinear incentivos:
¿quieres que los sistemas de la empresa respondan bien ante fallas? entonces haz
que los que los diseñen sean los mismos que tengan que responder por esas fallas.
¿Quieres que tu sistema sea mantenible desde el comienzo? una vez más: los que
lo crean son los mismos que lo mantienen. Y un largo etc.. Esta actitud o
estrategia se llama tener carne en el asador, o en inglés ["skin in the game"](https://en.wikipedia.org/wiki/Skin_in_the_game_(phrase))

Este punto está muy relacionado con el anterior. ¿Quieres que un ingeniero sea
específico en su diseño de soluciones? Para obligarlo a ser específico recuérdale
que no es un simple ejercicio de diseño sino que ellos van a tener que implementarlo.

## Resolver problemas "simples" de la mejor forma

Algo que suelo escuchar de muchos ingenieros describiendo lo que hacen (sobre
todo ingenieros de _backend_) es que su trabajo apenas consiste en conectar APIs
, como disculpándose por el hecho de que su trabajo no tiene un resultado visual
como el de un ingeniero de _frontend_ o un ingeniero móvil. Creo que existe esta
idea de que "conectar APIs" es un trabajo simple y por lo tanto no tan valioso.

Una de las cosas que he descubierto es que incluso esos problemas tan sencillos
pueden ser oportunidades para mejorar y afinar el oficio de uno. Uno de los
proyectos en los que más aprendí fue desarrollando un sistema de autenticación.
Uno podría pensar, ¿donde está la complejidad en esto? Y en efecto sabíamos que
iba a ser simple, pero eso no evitó que el equipo decidiera poner la barra de
calidad lo más alto que pudiéramos, haciendo uso de las mejores prácticas que
conociéramos y siendo lo más exhaustivos en el _testeo_. Hicimos pruebas unitarias
exhaustivas, pruebas de integración con un entorno en docker-compose, y pruebas
e2e sobre los ambientes desplegados (y terminamos aprendiendo en qué punto esto
era demasiado y en qué partes era necesario). Hicimos despliegues con _zero downtime_,
establecimos políticas de escalamiento y las probamos con pruebas de rendimiento,
etc...

El típico ejemplo de subestimar problemas es ese que produce sistemas con un
[modelo de dominio anémico](https://martinfowler.com/bliki/AnemicDomainModel.html).
Por ejemplo un CRUD cuando un API semánticamente significativo habría sido lo
adecuado.

Entonces, la próxima vez que les den un problema sencillo, pregúntense ¿Cuál es
la mejor forma de resolverlo? ¿Si es tan sencillo, estamos simplificándolo o 
subestimando las complejidades? ¿Como podemos evitar el _boilerplate_
, el trabajo simplón y reemplazarlos por algo más inteligente?

## No descuidar el "oficio"

Al principio de la carrera de uno, ciertas decisiones como qué IDE vas a usar,
qué terminal, etc.. son lo primero en lo que pensamos para ser más productivos.

Cosas como:

* ¿El IDE que usas te permite trabajar de forma fluida y lo sabes manejar?
* ¿Conoces atajos de teclado que te permiten ahorrar tiempo?
* ¿Usas `curl` o usas algo más elaborado como httpie?
* ¿Tienes automatizadas tareas recurrentes en tu trabajo con _scripts_?

Hacer este tipo de cosas de forma eficiente es importante cuando eres un contribuidor
individual dentro de tu equipo. Pero a medida que atacas problemas más grandes, te tienes que concentrar en otras
prioridades de mayor abstracción. Y al hacer eso, puedes terminar descuidando
esa parte del "oficio", que si bien no pensamos es importante, si nos puede
seguir ahorrando tiempo y haciéndonos más efectivos. 

El punto es que no hay que descuidar esta
parte del trabajo y menospreciarla. Tener un flujo de trabajo eficiente te da mas
tiempo para trabajar en los problemas mas carnudos, y va a seguir ahorrandote tiempo
seas un _junior_ o un _engineering manager_.

<!-- ## El ego es el enemigo

Viniendo de trabajar en Colombia con ciertos estándares, a trabajar en empresas
con mayores recursos y con otro tipo de selección de personal, tuve que
acostumbrarme a recibir _feedback_ de otra forma. Siendo colombiano, me he dado
cuenta que no solemos decir ciertas cosas de
frente. Y la razón es que tememos el hecho de que la otra persona se lo tome
personal. Trabajando con europeos me di cuenta que no es sostenible asociar el
ego de uno con el trabajo. ¿Abres un _pull request_? Espera recibir comentarios.
¿Tu propuesta técnica recibió mas críticas de las que esperabas? Recuerda que no
se trata de ti sino del proyecto, y así.

## Este es un trabajo social

Esto se me hace que se da a todo nivel. No importa si eres un ingeniero junior
o un _engineering manager_. Este trabajo tiene un componente social bastante
importante. No nos están pagando por escribir código y resolver _tickets_ de
Jira, y gran parte del valor que entregamos es determinado por la forma en la
que nos relacionamos con los demás.

A "bajo nivel" es obvio que necesitas llevarte bien con tus compañeros, y no me
refiero a ser mejores amigos o algo por el estilo. Pero a "alto nivel" (i.e.
entre equipos) también es necesario: será frecuente que tu equipo tenga que
colaborar con otros, por lo tanto ahí también vale la pena tener buenas
relaciones. En mi experiencia, una actitud de servicio y colaboración son clave
cuando uno quiere sacar un proyecto adelante con otros equipos.
 -->
