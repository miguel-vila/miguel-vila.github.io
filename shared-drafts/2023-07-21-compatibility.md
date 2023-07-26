---
title: Sobre compatibilidad, hacia adelante y hacia atrás [Borrador]
description: |
   ¿Sabes qué cambios de esquema son seguros de desplegar en un sistema 
   distribuido? En este post hablo sobre conceptos de compatibilidad, de cómo
   pensar cuáles son los cambios que se pueden desplegar de forma segura y
   , en especial, en el contexto de arquitecturas orientadas a eventos.
tags: compatibility, software engineering, system design, event-driven architecture
include_plotly: false
image: https://miguel-vila.github.io/images/breaking-chain.jpg
---

<p class="image__article">
<img src="/images/breaking-chain.jpg" class="article-photo" style="float: right">
</p>

En mi actual trabajo estamos construyendo herramientas relacionadas
con modelamiento de interfaces de servicios y eventos. Para ser más precisos, mi
equipo mantiene un repositorio donde varios equipos gestionan las versiones de
las especificaciones (_specs_) de sus servicios y eventos, todo esto en el contexto
de una plataforma orientada a servicios. Ese repositorio incluye validaciones de
compatibilidad: si un cambio en un servicio o evento tiene el riesgo de romper
algo, nuestra lógica lo detecta y lo advierte.

¿Qué significa que un cambio rompa algo? Veámoslo en el contexto de un servidor
y un cliente. Un ejemplo de una ruptura, _breaking change_ en inglés, es cambiar
el tipo de un campo, digamos, de `string` a `int`. Si el servidor espera un
`int` para un _request_ y el cliente le envía un `string`, entonces el servidor va
a rechazar la solicitud. Lo mismo pasaría si el campo estuviera en la respuesta:
el cliente va a esperar un `string` y recibe un `int`.

Este es un ejemplo de una ruptura que sucede en cualquier dirección:
sea en la solicitud o en la respuesta, sea que se despliegue el servidor o el
cliente primero. Pero, existe otro tipo de rupturas que se dan en una sola dirección,
y que se pueden desplegar de forma segura si primero se despliega el cambio en
un lado y luego en el otro.

## Compatibilidad hacia atrás y hacia adelante

Por ejemplo, si el servidor empieza a requerir un nuevo campo
_obligatorio_ entonces cualquier solicitud que el cliente haga sin ese campo va
a fallar. Este tipo de cambio es incompatible **hacia atrás**, porque el cliente
tiene un esquema antiguo que es incompatible con el nuevo esquema que el
servidor usa para validar las solicitudes. Este es el tipo de ruptura con el
que seguramente estamos más familiarizados. En el caso anterior, si se despliega
el cambio en el cliente primero, entonces no habrá ruptura.

Hay otra forma de ruptura menos común. Si el cambio consiste en agregar un
nuevo campo obligatorio a la respuesta (por obligatorio me refiero a que el servidor
_garantiza_ que el campo va a estar presente), entonces
dependiendo del esquema que use el cliente, este puede ser compatible o no. Si
el cliente usa, por adelantado, el nuevo esquema mientras el servidor emite
respuestas con el viejo esquema, entonces el cliente se va a romper tratando de
leer las respuestas del servidor. Esta es una ruptura **hacia adelante**. Como
podrán intuir este tipo de incompatibilidad es menos común, porque no es tan
usual que sean los clientes los que deseen usar una versión del esquema más
nueva. Usualmente son los servidores los que quieren empezar a emitir respuestas
con un esquema más nuevo.

Es importante recordar que, en cualquier caso, una ruptura afecta a los
clientes: puede suceder en forma de un _bad request_ o en forma de un error de
procesamiento de una respuesta.

La noción de compatibilidad **hacia adelante** y **hacia atrás** es un poco confusa
y difícil de interiorizar, al menos para mí. La forma en la que yo lo pienso es
preguntarme quién tiene el esquema nuevo y quién el esquema viejo.

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">

Es difícil traducir **backwards compatible** y **forward compatible**
al español. Se me ocurre hablar de compatibilidad **hacia atrás** y
**hacia adelante** por que así se transmite la idea de que es con respecto a un
esquema nuevo o viejo.

</div>
</div>

Hay varias complejidades en las compatibilidades para clientes/servidores que no
he mencionado. Por ejemplo, dependiendo de si el cambio es en la solicitud o en
la respuestas, la compatibilidad puede ser **hacia adelante** o **hacia atrás**,
desde el punto de vista de quién produce un valor y quién lo lee. Si esto suena
confuso, es por que lo es. Este _post_ abordará la compatibilidad en un contexto
distinto: el de arquitecturas orientadas a eventos. En este contexto, hablar de
compatibilidad es un poco más simple.

## Compatibilidad en arquitecturas orientadas a eventos

Primero, algunas definiciones. En una arquitectura orientada a eventos, diferentes
servicios o dominios emiten eventos hacia _canales_ o _tópicos_. Entidades
interesadas en esos eventos se suscriben a esos _canales_. Los procesos emisores
son llamados _productores_ y los procesos que se suscriben a los _canales_ son
llamados _consumidores_. En medio de estos dos procesos hay un _broker_ que es
el que hace la transmisión de los eventos. Ejemplos de _brokers_ son Kafka,
RabbitMQ, AWS SNS, AWS Kinesis, etc. Para más información pueden ver
[esta](https://www.asyncapi.com/docs/tutorials/getting-started/event-driven-architectures)
documentación de AsyncAPI.

Vamos a hacer una suposición, que es cierta en varios _brokers_: para el _broker_
un evento es un _blob_ de datos. El _broker_ no sabe nada sobre el contenido del
evento, si debe adherirse a un esquema, si es un JSON, si es un XML, etc.
Esto quiere decir, que por ejemplo, si mi servicio utiliza un cliente de AWS
Kinesis y emite un evento que no se adhiere al esquema acordado para ese canal,
AWS Kinesis aún aceptará y transmitirá ese evento. El evento va a ser transmitido al
consumidor y este va a tener una ruptura al intentar leer el evento.

Otra suposición es que no queremos que los consumidores tengan que procesar
multiples versiones de un evento. Podríamos hacer que los consumidores inspeccionen
un campo `version` en el evento y lo procesen según esa versión. Si
no hay un "match" entre la versión del evento y la versión que el consumidor espera,
entonces el consumidor puede rechazar el evento. Esta es una opción, pero puede
ser un dolor de cabeza para los consumidores. Además, la mayoría del tiempo los
consumidores solo van a estar procesando un mismo tipo o versión de un mensaje.

Pensemos en ejemplos de cambios que pueden producir rupturas:

Por ejemplo: remover un campo que solía ser obligatorio. En este caso, la
ruptura es **hacia atrás**, por que el consumidor tiene un esquema viejo que
no sirve con nuevos eventos.

Para desplegar este cambio, una opción es implementarlo primero en los
consumidores: esto significa dejar de usar el campo que se va a remover. Luego,
el productor se puede actualizar de forma segura.

Ahora, otro ejemplo de un cambio sería agregar un nuevo campo obligatorio. En
este caso, la ruptura es **hacia adelante**, por qué en caso de que el consumidor
utilice el nuevo esquema, los eventos viejos no van a tener el campo nuevo.

Desplegar este cambio de forma segura es el contrario del anterior: primero se
despliega el cambio en el productor, y luego en los consumidores. Pero hay un
detalle adicional. Los pasos son:

1. Desplegar el cambio en el productor. En este punto, el tópico va a contener
   eventos con el nuevo esquema **y** eventos con el viejo esquema, es decir eventos
   **con y sin** el nuevo campo.
2. Esperar que los consumidores hayan procesado todos los eventos viejos (sin el
   nuevo campo).
3. Desplegar el cambio en los consumidores. En este punto, los consumidores
   podrán procesar todos los eventos en el tópico.

¿Qué otros tipos de cambios existen y cuáles de ellos son compatibles o no?

Listemos algunos:

- Hacer opcional un campo que antes era obligatorio
- Remover una variante de una enumeración: por ejemplo, si el campo `status` puede
  ser `CREATED`, `PROCESSING` o `COMPLETED`, remover `PROCESSING`.
- Contrario al anterior: agregar una variante a una enumeración.
- Agregar un campo opcional.
- Agregar un nuevo tipo de evento.

Para el lector: ¿cuáles de estos cambios son compatibles? ¿cuáles son rupturas
hacia adelante o hacia atrás?

## Conclusión

Pensar en compatibilidad es una noción que se necesita tener en cuenta en sistemas
que evolucionan y que se encuentran en producción. Desarrollar nociones de qué
cambios son seguros y cuales no es importante para poder desplegar cambios de
forma segura. En un _post_ futuro hablaré sobre el mismo problema en el contexto
de clientes y servidores.
