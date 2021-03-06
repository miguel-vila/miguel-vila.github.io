---
title: The unreasonable effectiveness of functional streams
description: On the unreasonable effectiveness of functional streams
tags: Scala, Functional Programming, Functional Streams, Concurrency
---

Recently we had an interesting problem to solve which involved some "file" processing.

We will be processing a large file stored in [S3](https://aws.amazon.com/s3/). 
We estimate it's going to be very large, so just downloading it and reading it line by
line won't be feasible. Instead, we thought we could  use 
[`ZStream`](https://zio.dev/docs/datatypes/datatypes_stream)s to read it fully and process
it line by line. All of this without instantiating in memory the full file at any point.

First thing to note is that AWS allows you to read segments of a file by using the 
[`Range`](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.35) HTTP header. You 
can specify the range of bytes from the object you want to read. For example `"Range: bytes=100-299"` 
means "give me the bytes starting, inclusive, the 100th byte, up to, inclusive, the 299th".

As it turns out, doing this with functional streams is really easy.

First thing to figure out is how to split the file. Let's say the file is 11 bytes long.
Yeah, not so long, just so we can imagine how we would do it. And, let's say we are going
to fetch 3 bytes at a time. Then the ranges should be:

- `0-2`
- `3-5`
- `6-8`
- `9-10`

We can write this function like this:

```scala
def splitInSegments(
    chunkSize: Long,
    totalLength: Long
): UStream[(Long, Long)] = {
  require(chunkSize <= totalLength)
  require(totalLength > 0)
  ZStream
    .iterate((0, chunkSize - 1): (Long, Long)) { case (_, previousEnd) =>
      val newEnd =
        if (previousEnd + chunkSize > totalLength - 1) totalLength - 1
        else previousEnd + chunkSize
      (previousEnd + 1) -> newEnd
    }
    .takeUntil { case (_, end) =>
      end == totalLength - 1
    }
}
```

So far, so good. Let's start building the whole file. We'll have some function that allows us to query S3:

```scala
def getObject(request: GetObjectRequest): ZIO[S3Async, Exception, Array[Byte]] = ???
```

It uses AWS's SDK [`GetObject`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html) operation.
"Objects" are just what S3 calls files and this function is just calling that API given some request parameters.

Let's build a partial stream out of it:

```scala
def getBytesSegment(bucket: String, key: String)(
    start: Long,
    end: Long
): ZStream[S3Async, Exception, Byte] =
  ZStream
    .fromEffect {
      getObject(
        GetObjectRequest
          .builder()
          .bucket(bucket)
          .key(key)
          .range(s"bytes=$start-$end")
          .build()
      )
    }
    .map(_.toIterable)
    .flattenIterables
```

In this function we receive the "folder" (bucket in S3) and the "filename" (key in S3),
and the range of bytes we want to retrieve. This is just wrapping the API call into
a ZStream, nothing groundbreaking here.

Now, we also need to know the total length of the object. We can use the 
[`HeadObject`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html) 
operation for this. Like `getObject` this is just a function from AWS's SDK:

```scala
def headObject(bucket: String, key: String): ZIO[S3Async, Exception, HeadObjectResponse] = ???
```

Now, we can start joining together some stuff. 

```scala
def bytesStream(
    bucket: String,
    key: String
): ZStream[S3Async, Exception, Byte] =
  ZStream
    .fromEffect(headObject(bucket, key))
    .flatMap { metadata =>
      splitInSegments(
        chunkSize = fetchSize,
        totalLength = metadata.contentLength()
      ).flatMapPar(concurrentFactor) { case (start, end) =>
        getBytesSegment(bucket, key)(start, end)
      }
    }
```

We are doing the requests in parallel, given some `concurrentFactor` and each
request retrieves some fixed number of bytes given by `fetchSize`.

A cool thing is that even though the requests go in parallel the order of the segments
in the stream will be preserved.

But we don't want to process this file byte by byte, instead we want to each element
of the stream to be one line of the file. Finally:

```scala
def linesStream(
    bucket: String,
    key: String
): ZStream[S3Async, Exception, String] =
  bytesStream(bucket, key)
    .transduce(ZTransducer.utf8Decode >>> ZTransducer.splitLines)
```

The first transducer decodes batches of bytes into `String`s and the second one takes
batches of `String`s and separates them into lines.

And that's it. The `linesStream` function returns a stream that can be processed with
each element being a line from the original file.

<div class="note">
<p class="aside-header"><strong>Aside</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">

Transducers is a topic I don't understand completely and don't think I have found
comprehensive docs about it. Conceptually, they are supposed to be equivalent to
a function `ZStream[I] => ZStream[O]`. To be more specific, they act on chunks of 
the input stream, producing chunks for the output stream. That's the little I can 
get from reading [the signature at it's definition](https://github.com/zio/zio/blob/42f754e459a41013c61902dd2c75926dd87265d7/streams/shared/src/main/scala/zio/stream/ZTransducer.scala#L14):

```scala
// Contract notes for transducers:
// - When a None is received, the transducer must flush all of its internal state
//   and remain empty until subsequent Some(Chunk) values.
//
//   Stated differently, after a first push(None), all subsequent push(None) must
//   result in Chunk.empty.
abstract class ZTransducer[-R, +E, -I, +O](
  val push: ZManaged[R, Nothing, Option[Chunk[I]] => ZIO[R, E, Chunk[O]]]
)
```

The signature is a bit complicated to read. You could ignore the `ZManaged` part which
I think is used just to allow streams close over some resource. So essentially it's 
"just" a function:

```scala
Option[Chunk[I]] => ZIO[R, E, Chunk[O]]
```

(`Chunk` is ZIO's immutable Array data type).

This function is telling us that a `ZTransducer` is implemented by a function that
may or may not receive a `Chunk[I]` and that effectfully returns a `Chunk[O]`.
Being called with a `None`, according to the comment, means that 

`ZTransducer`s can be composed just like functions with `>>>`.

</div>
</div>

After this you can do whatever you want, treating the `ZStream[S3Async, Exception, String]`
as a file reader.

And that's the cool thing about functional streams. They allow you to treat complex
processes as values that you can pass to other functions. Imagine the effort involved
in doing something like this with Java's concurrency primitives. You could submit each
fetch to a `Thread`/`ExecutorService` to do it in parallel and you would have to keep 
things in order on your own. Doing this not blocking further processing would be really hard.

<div class="note">
<p class="aside-header"><strong>Aside</strong> <span class="clickable">(Click!)</span></p>

<div class="note-content">
[fs2](https://fs2.io/#/getstarted/example?id=example) allows you to do very similar things.
No surprise there given fs2 pre-dates ZIO.

</div>
</div>

Maybe this is the killer feature of Functional Programming. Not so much anything about
purity or parametricity. No need to talk about abstract stuff to see the value in this
style of writing things. Just the easiness in which you can build complex logic flows
without compromising efficiency or legibility.