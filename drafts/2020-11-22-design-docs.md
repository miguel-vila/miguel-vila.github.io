---
title: Sobre documentos de diseño
description: Sobre documentos de diseño
tags: software engineering
---

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
[Lucid](lucid.app) es que los diagramas son escritos en un lenguaje y el archivo
puede ser versionado a través de, por ejemplo, git. De esta forma la
documentación puede quedar en el mismo sitio que el código.
* [Swagger](https://swagger.io/), [OpenAPI](https://www.openapis.org/) o algo
como [Smithy](smithy.io/) pueden ser usados para discutir APIs. Estos son
especialmente importantes cuando uno quiere discutir los detalles de una
integración con otro equipo, o por lo general dejar documentadas las capacidades
de un sistema.

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
Puede ser útil usar [Lucid](lucid.app) en estos casos para agregar diagramas
informales.

Ejemplos de herramientas que se pueden usar para esto:

* Documentos en Markdown
* Google docs

Ambos pueden permitir agregar comentarios en partes específicas del documento
(para markdown usando algo como PRs de github).

Estos son preferibles a otros medios de comunicación como:

* Threads de slack
* Cadenas de correos



## "Future proofing"

* ¿Qué hacer con el problema de "se nos olvidó actualizar la documentación cuando hubo un cambio"?
* ADRs: por su naturaleza son immutables
* PlantUML:
* API Specs: e2e/integration tests con clientes generados a partir de la especificación. Adicionalmente: tener un job en jenkins qué ejecute los tests e2e con los clientes generados usando la última verión de los specs

# Decision tecnica:

- el problema
- contexto técnico
- solución(es)
