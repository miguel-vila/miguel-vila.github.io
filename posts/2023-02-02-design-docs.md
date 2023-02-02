---
title: Sobre documentos de diseño
description: |
    Sobre algunos tipos de documentos que podemos usar para hablar de
    decisiones técnicas: RFCs, ADRs, y propuestas técnicas, entre otros.
tags: software engineering, technical decisions, software architecture, systems design
image: https://miguel-vila.github.io/images/design.jpg
use_plotly: false
---

<p class="image__article">
<img src="/images/design.jpg" class="article-photo" style="float: right">
</p>

Como ingenieros o desarrolladores una de nuestras responsabilidades, más allá de
programar, es definir qué trabajo se necesita hacer para materializar _features_
nuevos. Para esto es útil escribir propuestas y diseños. Este es un corto post
sobre algunas "herramientas" que he usado para estos fines.

Por decisiones técnicas me refiero a:

* La creación de un nuevo servicio/componente.
* La implementación de un nuevo _feature_.
* Un patrón de integración con otro equipo.

Por diseños técnicos me refiero a la necesidad de especificar cosas como:

* La creación de un nuevo servicio/componente.
* La coordinación de múltiple componentes para entregar una nueva funcionalidad.

Algo que motiva el uso de estas herramientas es que toda decisión importante
debería ser:

* Documentada: Los integrantes del equipo deberían poder referirse a
documentación que explique diseños y decisiones pasadas.
* Compartida: Debería producir artefactos que puedan ser compartidos en la
organización. Resulta especialmente útil incluir enlaces a este tipo
documentación dentro del proceso de _onboarding_ de nuevos integrantes.
* Discutida: Toda decisión debería ser discutida entre los miembros relevantes
del equipo. Preferiblemente de forma asíncrona, sin incurrir en reuniones que
bloqueen el tiempo de toda la gente. Tiene sentido tener reuniones para alinear
a alto nivel, pero detalles finos (e.g. el nombre de esta variable) tienen más
sentido ser discutidos de forma asíncrona.
* Versionada (opcional): Este es un punto más importante para los diseños
técnicos que para las decisiones técnicas.

Hay tres grandes categorías de documentos:

* Formales
* Semi estructurados
* Informales

## Formales

Estos son documentos escritos en algún lenguaje de _markup_. Este tipo de
documentos guían implementación y presentan detalles finos. Un líder técnico o
ingeniero _senior_ pueden escribir estos para materializar una visión técnica
y guiar la implementación. También pueden ser usados para coordinar detalles
finos con otros equipos.

Ejemplos de estos:

* [PlantUML](https://plantuml.com/) o [Mermaid](https://mermaid-js.github.io/)
pueden ser usados para diferentes tipos de diagramas (de secuencia, de clases,
de componentes, etc...). La ventaja de uno de estos sobre, por ejemplo
[Lucid](https://lucid.app/) es que los diagramas son escritos en un lenguaje y
el archivo puede ser versionado a través de, por ejemplo, git. De esta forma la
documentación puede quedar en el mismo sitio que el código.
* [OpenAPI](https://www.openapis.org/) o algo
como [Smithy](https://smithy.io/2.0/index.html) pueden ser usados para discutir
APIs. Estos son especialmente importantes cuando uno quiere discutir los
detalles de una integración con otro equipo, o por lo general dejar documentadas
las capacidades de un sistema.

## Semi estructurados

A diferencia de los anteriores estos documentos son escritos en lenguaje natural
, tienen una estructura semi definida (un listado de campos) y suelen ser de más
alto nivel.

Por ejemplo _Requests For Comments (RFCs)_ son comunes para iniciar discusiones
técnicas alrededor de un tópico. Esto puede ser: qué lenguaje de programación
vamos a usar, como vamos a emitir eventos de dominio, como vamos a integrarnos
con un servicio externo, etc... Algunos de los campos involucrados en estos
documentos pueden ser un resumen, la motivación, una propuesta de implementación
y desventajas entre otros.

Aquí hay varios enlaces a cosas relacionadas con RFCs:

* [Request for Comments - Wikipedia](https://en.wikipedia.org/wiki/Request_for_Comments)
* [RFCs en "prod"](https://buriti.ca/6-lessons-i-learned-while-implementing-technical-rfcs-as-a-management-tool-34687dbf46cb)
* [Guía de RFCs](https://github.com/buritica/mgt/blob/master/es/guia-de-rfcs.md#gu%C3%ADa-de-rfcs)

Otro tipo de documentos, muy similar, son los _Architecture Design Records_ y
son usados para describir decisiones o acercamientos arquitecturales.
Por ejemplo, como vamos a aprovisionar la infraestructura, como vamos a exponer
APIs públicos, como vamos a monitorear los servicios, etc...

Algunos enlaces:

* [ADRs](https://github.com/joelparkerhenderson/architecture_decision_record#architecture-decision-record-adr)
* [Template ejemplo](https://github.com/joelparkerhenderson/architecture-decision-record/blob/main/templates/decision-record-template-by-michael-nygard/index.md)
* En mi trabajo actual usamos [adr-tools](https://github.com/npryce/adr-tools)
para centralizar los ADRs.

Algunos de estos documentos no son finales y suelen evolucionar con el tiempo.
Suelen ser [_Living Documents_](https://en.wikipedia.org/wiki/Living_document)
que son discutidos por un buen tiempo hasta que en un punto convergen a una
decision. Los RFCs suelen invitar discusión. Pero los ADRs suelen ser más finales
(e.g. este es el acercamiento que vamos a tener de ahora en adelante), pero en
general siento que pueden ser usados para los mismos objetivos.

Algunas compañías pueden formalizar el proceso a que un documento empiece como
un RFC y termine como un ADR (cuando se trata de una decisión arquitectónica).
Otras compañías pueden ser más informales: empiezan con una discusión _ad hoc_ y
concluyen con un ADR.

## No estructuradas / Informales

Estos son documentos que no tienen "campos" o esquemas bien definidos. Muchas
veces estos son simplemente documentos, en lenguaje natural, con secciones
definidas por los ingenieros. Por lo general este tipo de herramientas se usan
en etapas muy exploratorias y muchas veces no se hacen dentro del contexto de un
proyecto o de un equipo. Por ejemplo, un equipo quiere desarrollar un nuevo
_feature_ y se ha dado cuenta de que tienen que haber varios cambios técnicos
con distintas posibilidades.

En estos casos no es tan útil llegar al nivel de formalidad de especificar hasta
el último detalle el API del nuevo servicio. En fases exploratorias es mejor
hacer una descripción informal. Una vez haya luz verde de la propuesta y el
proyecto empiece si valdrá la pena usar formas de documentación más formales.
Puede ser útil usar [Lucid](https://lucid.app/) en estos casos para agregar
diagramas informales.

Ejemplos de herramientas que se pueden usar para esto:

* Documentos en Markdown
* Google docs
* Agregar diagrams con Lucid

Con markdown y Google Docs se pueden agregar comentarios en partes específicas
del documento (para markdown usando algo como PRs de github). Esto permite
iniciar discusiones sobre temas puntuales, hacer sugerencias, preguntas o
requerir cambios.

En varios trabajos he necesitado escribir este tipo de documentos. La estructura
es usualmente informal pero la motivación común es resolver un problema. Es útil
poner un párrafo breve con contexto y empezar a proponer una solución. También
es común proponer varias soluciones y listar los pros, cons, y consecuencias de
cada alternativa. Si se proponen varias soluciones es buena idea que el autor
ponga su preferida de primero.

Para los detalles de la solución puede ser útil poner diagramas informales, o
pseudocódigo.

## Future proofing

En el desarrollo de software es importante asegurarse que la documentación está
actualizada. Cosas como el código pueden ser entendidos a través de los tests
(que ojalá se tengan), pero no tenemos un mecanismo similar para la
documentación. Mantener buena documentación es más responsabilidad de los
sistemas de trabajo que tenga la compañía o el equipo.

Uno de los tipos de documento que es más importante de mantener actualizado es
aquel que describe como funciona un sistema específico a alto nivel. Por
ejemplo: como esperamos recibir pagos asíncronos, o como funciona tal integración
con terceros. Otros tipos de documentos como los ADRs, por su naturaleza,
terminan convergiendo y pueden dar lugar al diseño de otros sistemas. Estos no
tienen que ser actualizados, en cambio son reemplazados por nuevos ADRs si se
quiere cambiar una decisión técnica.

Una idea que he visto es que cada equipo mantenga una lista con los documentos
que tienen que ser actualizados cada X meses. Una buena idea es darle estos
documentos a nuevos integrantes y que verifiquen que están a la fecha.

Por último, los documentos formales son los que más sujetos están a ser
verificados. De forma superficial la sintaxis se puede verificar. Pero los API
specs pueden ser verificados con respecto a una implementación.
Por ejemplo a través de tests _end to end_ / de integración, donde los clientes
son generados a través de los APIs specs. Esto sirve para verificar
la estructura de las entradas y las salidas, pero vienen con la desventaja de
ser lentos y frágiles, entre otras desventajas. Otra posibilidad es usar
[pact testing](https://www.infoq.com/presentations/pact/).

<div class="note">
<p class="aside-header"><strong>Nota aparte</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">

Un acercamiento para sincronizar API specs e implementación es general el API
spec a partir de la implementación. Por ejemplo en Scala esto se puede hacer con
[Tapir](https://tapir.softwaremill.com/en/latest/). Este acercamiento tiene
varias desventajas:

* No permite discutir solamente el API spec en un formato neutro. Por ejemplo,
si mi servicio en Scala usa Tapir, sería raro compartir un PR con código de Tapir
a otro equipo que usa una tecnología distinta, por ejemplo Python.
* Tener un único lugar donde se reúnan todos los API specs de la compañía se
vuelve un poco más complicado.

En mis trabajos recientes he visto el acercamiento contrario (API first) y los
servicios se adhieren al spec generando una interfaz (por ejemplo
[smithy4s](https://disneystreaming.github.io/smithy4s/)). La ventaja es que las
discusiones se pueden empezar en un formato neutro y es agnóstico a cualquier
tecnología.

</div>
</div>

## Palabras Finales

No voy a concluir diciendo una burrada como "documentar es bueno y se puede
hacer de muchas formas". Creo que es más importante enfatizar que estas son
herramientas de comunicación y discusión: sirven para hacer más explicita la
visión que tenemos en nuestras cabezas y compartirla con otras personas. El
éxito de su uso depende de como se den las conversaciones que estos documentos
inician.
