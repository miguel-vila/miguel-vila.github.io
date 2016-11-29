---
title: Dynamic Programming with Functional Programming
description: How to implement Dynamic Programming algorithms using Functional Programming
tags: Functional Programming, Dynamic Programming
image: https://miguel-vila.github.io/images/dp-table.png
---

Dynamic programming problems, when solved in a bottom-up fashion, usually rely in some mutable data structure which holds the solutions for some smaller problems. For example a traditional solution for the classical knapsack problem can be:

```scala
def knapsack(maxWeight: Int, value: Vector[Int], weight: Vector[Int]): Int = {
    val n = value.length
    val solutions = Array.fill(n+1, maxWeight + 1)( 0 )
    (1 to n - 1) foreach { i =>
        (1 to maxWeight) foreach { j =>
            solutions(i)(j) = if( j - weight(i-1) >= 0 ) {
                Math.max( solutions(i-1)(j) , solutions(i-1)(j - weight(i-1)) + value(i-1) )                                            } else {
                solutions(i-1)(j)                                            
            }
        }
    } 
    solutions(n)(maxWeight)                                            
}
```

The time complexity of this is $\mathcal{O}(nW)$ where $n$ is the number of items to consider and $W$ is the maximum weight. And the space complexity is also $\mathcal{O}(nW)$. This can be improved given that we only need the last row of solutions for each iteration:

```scala
def knapsack(maxWeight: Int, value: Vector[Int], weight: Vector[Int]): Int = {
    val n = value.length
    var solutions = Array.fill(maxWeight + 1)( 0 )
    (1 to n - 1) foreach { i =>
        val newSolutions = Array.fill(maxWeight + 1)( 0 )
        (1 to maxWeight) foreach { j =>
            newSolutions(j) = if( j - weight(i-1) >= 0 ) {
                Math.max( solutions(j) , solutions(j - weight(i-1)) + value(i-1) )
            } else {
                solutions(j)
            }
        }
        solutions = newSolutions
    } 
    solutions(maxWeight)                                                            
}
```

The space complexity of this will be $\mathcal{O}(W)$

## How to do the same thing functionally?

How could we go on to do the same thing functionally? One of the main objectives in functional programming is avoiding side-effects. The main side-effect that we have here is the mutation of a data structure and this can be avoided with immutable data structures among other techniques we will see later. 

But before doing that we should ask ourselves: is it worth it? Should someone calling the function `knapsack` care if it is implemented using mutable variables? My opinion is that no: it doesn't matter if `knapsack` is implemented with or without mutability even from a functional programming point of view. Let me explain.

This is because the implementation of `knapsack` that I listed before is already "purely functional" with respect to observable mutations! Will it return the same results when called with the same arguments? Yes! Is it implemented with any side-effect? Well, it has a mutable variable but does that mutable variable escape the function definition? No. Is it a global variable whose mutation can be observed from the outside? No. Thus, with respect to "observable mutations" the function `knapsack` is referentially transparent.

Having said that the idea behind implementing `knapsack` functionally is purely an exercise on how we can model this problem in a purely functionally fashion but my opinion is that even when trying to follow the functional programming ideas mutation is not bad as long as it's just an implementation detail and not something that can be observed by the bigger system.

## Translating every mutation to a state modification


