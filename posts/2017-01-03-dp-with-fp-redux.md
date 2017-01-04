---
title: Solving Dynamic Programming problems using Functional Programming (Redux)
description: How to implement Dynamic Programming algorithms using Functional Programming
tags: Functional Programming, Dynamic Programming, Scala, Laziness
image: https://miguel-vila.github.io/images/dp-fp-1.png
---

## Going top-down

Going back to [solving Dynamic Programming (DP) problems by using Functional Programming](https://miguel-vila.github.io/posts/2017-01-02-dp-with-fp.html) I found [this](http://jelv.is/blog/Lazy-Dynamic-Programming/) article. In the article they describe a way to solve DP problems in a top-down fashion by using laziness. Scala doesn't have the same lazy semantics as Haskell. If we are going to try to follow their same approach we are going to need a lazy array: an array whose elements are computed just when they are needed. Here's a very simple implementation of that idea:

```scala
class LazyVector[A](thunks: Vector[() => A]) {
    
    private val values: Array[Option[A]] = Array.fill(thunks.length)(None)
    
    def apply(i: Int): A = {
        if(!values(i).isDefined) {
            values(i) = Some( thunks(i)() )
        }
        values(i).get
    }
    
    def last: A = apply(values.length - 1)
    
}

object LazyVector {
    
    def tabulate[A](n: Int)(f: Int => A): LazyVector[A] = {
        new LazyVector( Vector.tabulate(n)( i => () => f(i) ) )
    }

    def tabulate[A](m: Int, n: Int)(f: (Int,Int) => A): LazyVector[LazyVector[A]] = {
        tabulate(m)( i => tabulate(n)( j => f(i,j) ) )
    }

}
```

We construct an instance of `LazyVector` by providing a vector of computations. And when we try to access the i-th element of the vector we perform the computation if we hadn't done it before and return the saved value. Under the hood we are using a mutable array but don't worry, our intentions are pure.

We also provide two useful `tabulate` constructors, similar to the ones `Vector` has.

With this we can solve once again the _0/1 knapsack_ problem:

```scala
def knapsack(maxWeight: Int, value: Vector[Int], weight: Vector[Int]): Int = {
    val n = value.length
    lazy val solutions: LazyVector[LazyVector[Int]] = 
        LazyVector.tabulate(n + 1, maxWeight + 1) { (i,j) =>
            if( i == 0 || j == 0 ) {
                0
            } else if( j - weight(i-1) >= 0 ) {
                Math.max( 
                    solutions(i-1)(j) , 
                    solutions(i-1)(j - weight(i-1)) + value(i-1) 
                )
            } else {
                solutions(i-1)(j)
            }
        }
    solutions(n)(maxWeight)
}
```

There are a lot of interesting details here. First we define the matrix of solutions recursively: the function that builds it uses the `solutions` value (this is the reason we have to declare it as a `lazy val`, because we are referencing it before we are done defining it). Second: the base cases are just another clause in the function that describes the matrix. This has the same time complexity as we had before but space complexity of $O(nW)$ which is not the best we can do if we are only interested in computing the maximum total value.

There is an important advantage with this approach, though. The code is way more declarative. It doesn't say how to iterate over the matrix of solutions in such a way that dependencies are pre-computed. It just says: here's what the solution looks like, let the data structure's laziness avoid re-computations.

## Returning the concrete solution

If we also want to know *which* items conform the maximum total value then we have to record all the decisions we make, so the space complexity will be $O(nW)$ anyway. This just implies returning more information when we are looking for the maximum:

```scala
def max[A](a: (Int, A), b: (Int, A)): (Int, A) =
    if(a._1 > b._1)
        a
    else
        b

def knapsackWithItems(
    maxWeight: Int, value: Vector[Int], weight: Vector[Int]): List[Int] = {
    val n = value.length
    lazy val solutions: LazyVector[LazyVector[(Int, List[Int])]] = 
        LazyVector.tabulate(n + 1, maxWeight + 1) { (i,j) =>
            if( i == 0 || j == 0 ) {
                (0, List.empty)
            } else if( j - weight(i-1) >= 0 ) {
                val (including, itemsIds) = solutions(i-1)(j - weight(i-1))
                max( 
                    solutions(i-1)(j) ,
                    (including + value(i-1), (i-1) :: itemsIds )
                )
            } else {
                solutions(i-1)(j)
            }
        }
    val (_,items) = solutions(n)(maxWeight)
    items
}
```

Similarly we can solve [Project Euler's 81-th problem](https://projecteuler.net/problem=81) like this:

```scala
sealed trait Instruction
case object GoRight extends Instruction
case object GoDown extends Instruction

def minPath(values: Vector[Vector[Int]]): List[Instruction] = {
    val m = values.length
    val n = values(0).length
    lazy val solutions: LazyVector[LazyVector[(Int, List[Instruction])]] = 
        LazyVector.tabulate(m, n) { 
            case (0,0) => (values(0)(0), List.empty)
            case (0,j) => 
                val (leftVal, leftInsts) = solutions(0)(j-1)
                (values(0)(j) + leftVal, leftInsts ++ List(GoRight))
            case (i,0) => 
                val (upVal, upInsts) = solutions(i-1)(0)
                (values(i)(0) + upVal, upInsts ++ List(GoDown))
            case (i,j) =>
                val (leftVal, leftInsts) = solutions(i)(j-1)
                val (upVal  , upInsts  ) = solutions(i-1)(j)
                if(leftVal < upVal) {
                    (leftVal + values(i)(j), leftInsts ++ List(GoRight))
                } else {
                    (upVal + values(i)(j)  , upInsts ++ List(GoDown))                    
                }
        }
    val (_,insts) = solutions(m-1)(n-1)
    insts
}
```

## Conclusions

This top-down approach has the disadvantage that it may consume more memory than we need (if we are just interested in the maximum / minimum value). But for the kind of problems where we _need_ to have all the decisions then it's worth it anyway. It produces very clear and declarative code. The only disadvantage I can think of is that it may produce stack-overflows for large inputs.
