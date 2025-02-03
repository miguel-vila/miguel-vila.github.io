---
title: Side Projects
description: A list of side projects I have done in the past.
---

I have done a few side projects in the past in order to learn new things and have fun. 
Here is a list of them:

### [X Recs Remover](https://github.com/miguel-vila/x-recs-remover)

A [Firefox plugin](https://addons.mozilla.org/en-GB/firefox/addon/x-recommendations-remover/) to remove recommendations bars on X / Twitter, in order to have a
distraction-free experience. This project was quickly done with the help of
ChatGPT.

### [Fetch](https://github.com/miguel-vila/fetch)

A proof of concept about implementing [Haxl](https://community.haskell.org/~simonmar/papers/haxl-icfp14.pdf) using Scala.
Haxl is a library from Facebook that allows you to batch and cache requests in an easy way.
Some recent libraries that have implemented this are ["fetch"](https://github.com/47degrees/fetch)
or ["zio-query"](https://github.com/zio/zio-query).

### [Hoja Cálculo](https://github.com/miguel-vila/hoja-calculo)

Implemented a collaborative spreadsheet. Used [this blog post](https://semantic-domain.blogspot.com/2015/07/how-to-implement-spreadsheet.html?utm_source=pocket_reader) as a reference to make it reactive (i.e. declare a cell that depends on another). In order to make it collaborative I used a CRDT library.

### [Incremental Compiler](https://github.com/miguel-vila/incremental-compiler)

Implemented a toy compiler. Initially, I followed [this tutorial](https://web.archive.org/web/20071216140227/http://www.cs.indiana.edu/~aghuloum/compilers-tutorial-2006-09-16.pdf), but did a few things differently. I used [recursion schemes](https://blog.sumtypeofway.com/an-introduction-to-recursion-schemes/) to implement the compiler.
