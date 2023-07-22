---
title: Sobre compatibidad, hacia adelante y hacia atrás
description: Explicando algo sobre compatibilidad, en relación a arquitecturas orientadas a eventos
tags: compatibility, software engineering, system design
include_plotly: false
---

En mi actual trabajo estamos trabajando en construir herramientas relacionadas
con modelamiento de interfaces de servicios y eventos. Para precisar la cosa un
poco, mi equipo mantiene un repositorio donde varios equipos versionan los
_specs_ de sus servicios y de sus eventos, esto en el contexto de una plataforma
orientada servicios. Ese repositorio incluye validaciones de compatibilidad: si
un cambio en un servicio o evento tiene el riesgo de romper algo, nuestra lógica
lo detecta y lo advierte.

¿Qué significa que un cambio rompa algo? Un ejemplo claro es en la relación
servidor-cliente. Una instancia es cambiar el tipo de un campo, por ejemplo,
de `string` a `int`. Si el servidor espera un `int` para un request y el cliente
le envía un `string`, entonces el servidor va a rechazar la solicitud. Lo mismo
pasaría si el campo estuviera en la respuesta: el cliente va a esperar un `string`
y recibe un `int`.

El anterior es un ejemplo de un rompimiento que sucede en cualquier dirección:
sea en la solicitud o en la respuesta, sea que se despliegue el servidor o el
cliente primero. Hay otro tipo de rompimientos que se dan en una sola dirección,
y que se pueden desplegar de forma segura si primero se despliega el cambio en
un lado y luego en el otro.

Por ejemplo, si el servidor empieza a requerir un nuevo campo
*obligatorio* entonces cualquier solicitud que el cliente haga sin ese campo va
a fallar. Este tipo de cambio es incompatible _**hacia atrás**_, porque el cliente
tiene un esquema antiguo que es incompatible con el nuevo esquema que el
servidor usa para validar las solicitudes. Este es el tipo de rompimiento con el
que seguramente estamos más familiarizados. En el caso anterior, si se despliega
el cambio en el cliente primero, entonces no habrá rompimiento.

Hay otra forma de rompimiento menos común. Si el cambio consiste en agregar un
nuevo campo obligatorio a la respuesta (por obligatorio me refiero a que el servidor
_garantiza_ que el campo va a estar presente), entonces
dependiendo del esquema que use el cliente, este puede ser compatible o no. Si
el cliente usa, por adelantado, el nuevo esquema mientras el servidor emite
respuestas con el viejo esquema, entonces el cliente se va a romper tratando de
leer las respuestas del servidor. Este es un rompimiento _**hacia adelante**_. Como
podrán intuir este tipo de incompatibilidad es menos común, por que no es tan
usual que sean los clientes los que deseen usar una versión del esquema más
nueva. Usualmente son los servidores los que quieren empezar a emitir respuestas
con un esquema más nuevo.

Es importante recordar que en cualquier caso, el rompimiento afecta a los
clientes: puede suceder en forma de un _bad request_ o en forma de un error de
procesamiento de una respuesta.

La noción de compatibilidad _hacia adelante_ y _hacia atrás_ es un poco confusa
y difícil de interiorizar, al ménos para mí. La forma en la que yo lo pienso es
preguntarme quién tiene el esquema nuevo y quién el esquema viejo.

Nota aparte: es difícil traducir _backwards compatible_ y _forward compatible_
al español. Se me ocurre hablar de compatibilidad _hacia atrás_ y
_hacia adelante_ por que así se transmite la idea de que es con respecto a un
esquema nuevo o viejo.

Hay varias complejidades en las compatibilidades para clientes/servidores que no
he mencionado. Por ejemplo, dependiendo de si el cambio es en la solicitud o en
la respuestas, la compatibilidad puede ser _hacia adelante_ o _hacia atrás_.
Este _post_ hablará de compatibilidad en un contexto diferente y más fácil de
abordar: en el contexto de arquitecturas orientadas a eventos.

Primero, algunas definiciones. En una arquitectura orientada eventos, diferentes
servicios o dominios emiten eventos hacia _canales_ o _tópicos_. Entidades
interesadas en esos eventos se suscriben a esos _canales_. Los procesos emisores
son llamados _productores_ y los procesos que se suscriben a los _canales_ son
llamados _consumidores_. En medio de estos dos procesos hay un _broker_ que es
el que hace la transmisión de los eventos. Ejemplos de _brokers_ son Kafka,
RabbitMQ, AWS SNS, AWS Kinesis, etc.

Vamos a hacer una suposición, que es cierta en varios brokers: para el broker
un evento es un _blob_ de datos. El broker no sabe nada sobre el contenido del
evento, si debe adherirse a un esquema, si es un JSON, si es un XML, etc.
Esto quiere decir, que por ejemplo, si mi servicio tiene un cliente de AWS Kinesis
y produce un evento que no cumple con el esquema acordado para ese canal, entonces
esa solicitud va a ser aceptada por Kinesis. El evento va a ser transmitido al
consumidor y este va a ser quebrado al intentar leerlo.

Otra suposición es que no queremos que los consumidores tengan que estar procesando
multiples versiones de un evento. Versionar los eventos es una opción, pero puede
ser un dolor de cabeza para los consumidores. Además, la mayoría del tiempo los
consimidores solo van a estar procesando un mismo tipo o versión de un mensaje.

Pensemos en ejemplos de cambios que pueden producir rompimientos:

Uno muy fácil es remover un campo que solía ser obligatorio. En este caso, el
rompimiento es _hacia atrás_, por que el consumidor tiene un esquema viejo que
no sirve con nuevos eventos.

Para desplegar este cambio una opción es desplegar el cambio primero en los
consumidores: esto significa dejar de usar el campo que se va a remover. Luego,
el productor se puede actualizar de forma segura.

Ahora, otro ejemplo de un cambio sería agregar un nuevo campo obligatorio. En
este caso, el rompimiento es _hacia adelante_, por qué en caso de que el consumidor
utilice el nuevo esquema, los eventos viejos no van a tener el campo nuevo.

Desplegar este cambio de forma segura es el contrario del anterior: primero se
despliega el cambio en el productor, y luego en los consumidores. Pero hay un
detalle adicional. Por pasos:

1. Desplegar el cambio en el productor. En este punto el tópico va a contener
   eventos con el nuevo esquema y eventos con el viejo esquema, es decir eventos
   con y sin el nuevo campo.
2. Esperar que los consumidores hayan procesado todos los eventos viejos (sin el
   nuevo campo).
3. Desplegar el cambio en los consumidores. En este punto los consumidores van
   a esperar que el campo nuevo esté presente en todos los eventos.

