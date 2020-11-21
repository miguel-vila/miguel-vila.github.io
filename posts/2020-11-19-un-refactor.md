---
title: Un pequeño refactor
description: Un pequeño refactor que hice en zio-metrics
tags: Scala, ZIO, Open source
---

Hace poco hice un Pull Request a una librería de métricas en Scala, con el objetivo de mejorar el API expuesto a usuarios.
Resumiendo la cosa [`zio-metrics`](https://github.com/zio/zio-metrics) es una pequeña librería para publicar métricas
con ZIO. La estamos usando para reportar una métrica a la medida pero al usarla, en su momento, me dí cuenta que
tenía unos detalles de diseño que no me gustaban. 

La librería funciona con una cola de métricas. Esta cola de métricas es muestreada de forma asíncrona para reportarlas:

- Hay un proceso que de forma continua lee esa cola y usa un cliente UDP para reportarlas.
- Cuando uno quiere reportar una métrica uno invoca una función que empuja un valor a esa cola.

Un ejemplo, tomado de los docs viejos, de como se usaba antes:

```scala
val program = {
    val messages = List(1.0, 2.2, 3.4, 4.6, 5.1, 6.0, 7.9)
    val client   = Client()
    client.queue >>= (queue => {
      implicit val q = queue
      for {
        z <- client.listen          // uses implicit 'q'
        opt <- RIO.foreach(messages)(d => Task(Counter("clientbar", d, 1.0, Seq.empty[Tag])))
        _   <- RIO.collectAll(opt.map(m => client.send(q)(m)))
      } yield z
    })
}
```

Hay varios detalles:

- Los usuarios de la librería _tienen_ que llamar `.listen` para inicializar el proceso que va a extraer valores de la cola.
- Después de eso, cada vez que quieran enviar una métrica tienen que, además, proveer la referencia a la cola.

Esto conlleva varios problemas:

- Un usuario puede olvidar llamar `.listen` perfectamente. Nada en la librería evitaría que esto pasase. 
- Un usuario puede enviar una métrica con una referencia a una cola _distinta_ a la que fué usada al llamar a `.listen`. Una vez más, nada en la librería evitaría que esto sucediera.
- Por último, tal vez no sea evidente en el ejemplo anterior, pero en programas más complicados, dónde los pasos de inicialización están muy alejados
de los usos, puede resultar incómodo usar este API. Habría que propagar la referencia a la cola desde dónde se inicializó.

En pocas palabras la cola es un detalle de implementación que el API está exponiendo.

Debido a eso, me tomé el "atrevimiento" de abrir un [_issue_](https://github.com/zio/zio-metrics/issues/52). Lo discutí con el autor de la librería y después abrí un [Pull request](https://github.com/zio/zio-metrics/pull/53) para intentar arreglarlo.

El resultado final implica que ahora ningún cliente tiene que pasar ninguna referencia a ninguna cola. El código anterior se transformó en:

```scala
val program = {
    val messages = List(1.0, 2.2, 3.4, 4.6, 5.1, 6.0, 7.9)
    val createClient = Client()
    createClient.use { client =>
      for {
        opt <- RIO.foreach(messages)(d => Task(Counter("clientbar", d, 1.0, Seq.empty[Tag])))
        _   <- RIO.collectAll(opt.map(m => client.sendM(true)(m)))
      } yield ()
    }
}
```

La diferencia principal es que ahora los constructores de los clientes retornan un [`ZManaged`](https://zio.dev/docs/datatypes/datatypes_managed) que encapsula la creación de la cola, y la inicialización del proceso que escucha la cola:

```scala
  def apply(
    bufferSize: Long,
    timeout: Long,
    queueCapacity: Int,
    host: Option[String],
    port: Option[Int]
  ): ZManaged[ClientEnv, Throwable, Client] =
    ZManaged.make {
      for {
        queue  <- ZQueue.bounded[Metric](queueCapacity)
        client = new Client(bufferSize, timeout, host, port)(queue)
        fiber  <- client.listen
      } yield (client, fiber)
    } { case (client, fiber) => client.queue.shutdown *> fiber.join.orDie }
      .map(_._1)
```

A partir de ahí las instancias de `Client` contarán con una referencia fija y privada a una cola. Además serán libres de empujar mensajes a ella cuando requieran reportar una métrica, sin tener que obligar a los invocadores a que provean la cola correcta.

Eso era todo, la lección principal es que uno no se tiene que aguantar APIs incómodos y que siempre hay forma de mejorarlos.

Gracias a [toxicafunk](https://github.com/toxicafunk) por permitirme contribuir esto y asistirme en el PR.