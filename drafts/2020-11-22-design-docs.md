---
title: Sobre documentos de diseño
description: Sobre documentos de diseño
tags: Ingenieria
---

Como ingenieros o desarrolladores una de nuestras responsabilidades, más allá de programar, es definir qué trabajo se necesita hacer para materializar _features_ nuevos. Para esto es útil escribir propuestas y diseños. Este es un corto post sobre algunas "herramientas" que he usado (y algunas que quiero probar) para estos fines.

Por decisiones técnicas me refiero a:

* La creación de un nuevo servicio/componente.
* La implementación de un nuevo _feature_.

Por diseños técnicos me refiero a la necesidad de especificar cosas como:

* La creación de un nuevo servicio/componente.
* La coordinación de múltiple componentes para entregar una nueva funcionalidad.

Algo que motiva el uso de estas herramientas es que toda decisión importante debería ser:

* Documentada: Los integrantes del equipo deberían poder referirse a documentación que explique diseños y decisiones pasadas.
* Compartida: Debería producir artefactos que puedan ser compartidos en la organización. Resulta especialmente útil incluir enlaces a este tipo documentación dentro del proceso de _onboarding_ de nuevos integrantes.
* Discutida: Toda decisión debería ser discutida entre los miembros relevantes del equipo. Y preferiblemente de forma asíncrona, sin incurrir en reuniones que bloqueen el tiempo de toda la gente.
* Versionada: Este es un punto más importante para los diseños técnicos que para las decisiones técnicas. La idea es que cada cambio a un diseño sea reflejado como un cambio a la documentación con un responsable y con una fecha.

## No estructuradas / Informales

Por no estructuradas o informales me refiero a documentos que no tienen "campos" o esquemas bien definidos. Muchas veces estos son simplemente documentos, en lenguaje natural, con secciones definidas por los ingenieros. Por lo general este tipo de herramientas se usan en etapas muy exploratorias y muchas veces no se hacen dentro del contexto de un proyecto. Por ejemplo, varios ingenieros han identificado problemas de diseño o implementación con un servicio y quieren proponer una reescritura o una reestructuración. En estos casos no es tan útil llegar al nivel de formalidad de especificar hasta el último detalle el API del nuevo servicio. En fases exploratorias es mejor hacer una descripción informal. Una vez haya luz verde de la propuesta y el proyecto empieze si valdrá la pena usar formas de documentación más formales.

Ejemplos de herramientas que se pueden usar para esto:

* Documentos en Markdown
* Google docs

Ambos pueden permitir embeder comentarios en partes específicas del documento (para markdown usando algo como PRs de github).

Estos son preferibles a otros medios de comunicación como:

* Threads de slack
* Cadenas de correos

## Semi estructurados

En la categoría de semi estructurados encontramos documentación que tiene algunos campos definidos pero que no dictan detalles específicos todavía. 

### Requests For Comments

Estos sirven para definir propuestas y empezar discusiones alrededor de ellas. Juan Pablo Buriticá tiene 

* [Request for Comments - Wikipedia](https://en.wikipedia.org/wiki/Request_for_Comments)
* [RFCs en "prod"](https://buriti.ca/6-lessons-i-learned-while-implementing-technical-rfcs-as-a-management-tool-34687dbf46cb)
* [Guía de RFCs](https://github.com/buritica/mgt/blob/master/es/guia-de-rfcs.md#gu%C3%ADa-de-rfcs)
* [ADRs](https://github.com/joelparkerhenderson/architecture_decision_record#architecture-decision-record-adr)
* [template ejemplo](https://github.com/joelparkerhenderson/architecture_decision_record/blob/master/adr_template_by_michael_nygard.md)

## Formales

Guian implementación (?), detalles finos

Especificando detalles de implementación:

* [PlantUML](https://plantuml.com/)
* [API Specs - e.g. swagger](https://swagger.io/)
* [Home - OpenAPI Initiative](https://www.openapis.org/)

## "Future proofing"

* ¿Qué hacer con el problema de "se nos olvidó actualizar la documentación cuando hubo un cambio"?
* ADRs: por su naturaleza son immutables
* PlantUML:
* API Specs: e2e/integration tests con clientes generados a partir de la especificación. Adicionalmente: tener un job en jenkins qué ejecute los tests e2e con los clientes generados usando la última verión de los specs

# Decision tecnica:

- el problema
- contexto técnico
- solución(es)
