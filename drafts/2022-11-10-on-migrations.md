---
title: On migrations 
description: A few tips on how to do version migrations
tags: migrations, software engineering, system design
include_plotly: false
---

During my last job we operated one particular service / API that was central to
the operation of the platform. As time passed, the API became insufficient for
new use cases. We needed to move away from an old API to a better one, and we
needed to migrate the underlying data to a new data model. Old clients would
have to move to the new APIs and we had to coordinate this process.

This kind of process is not exciting, but it is a very common
problem if you have been working on the same service for a long time. Even if it
seems like a pedestrian task, it is important to get it right, and it's not
trivial to do so. You have to reason about coordinating systems and how to make
things safe.

## Some requirements

- Zero downtime: this is an implicit assumption in most platforms nowadays.
- Read clients of the old service should continue to be able to read old data, and new data. Reason for this is that some read clients would take a long time to migrate to the new API.

## A few techniques

Here are some of the techniques we used in order to do this in an incremental
way.

### Backfill / dual writes

The first thing is that we followed a sort of backfill strategy: each request
against the new service meant a dual write to the old service (what we sometimes
called a backfill or a write back), and to the new persistence.

Before the migration, clients would simply hit the old service directly:

<img src="/images/backfill-before.png" class="article-centered-image"/>

The new service, would provide the same functionality to clients, but it would
also perform a dual write:

<img src="/images/backfill-after.png" class="article-centered-image"/>

There are some interesting details about how to make this dual write process
safe. On one hand, we need some atomicity guarantees, so that we don't end up
with inconsistent data. Depending on whether the operation is expected to be
visible immediately or not, we can make our life easier. For example, let's
suppose that the operation is not expected to be visible immediately. It could
be because the API represents receiving a notification from a system that is
already asynchronous, for example. Then, we could have some asynchronous process
pulling from a queue and performing the dual writes, as long as each operation
is idempotent, then it should be OK. If a command fails, it will be retried,
and as the operation is idempotent, it will be safe.

<img src="/images/backfill-async.png" class="article-centered-image"/>

How about the case in which the operation is expected to be visible immediately
after the request? For example, something an end user is performing, let's say,
updating their profile. In this case, we could still apply the same strategy, if
clients are still reading from the old service:

<img src="/images/backfill-sync-write.png" class="article-centered-image"/>


## On-demand migrations

A given when we were talking about this migration is that it had to be zero
downtime process. This meant that:

- we would not coordinate downtime during which we would run a data migration
- the whole process should be transparent to end users.


## Clients switch over

A way that 

- on-demand migrations
- clients do switch overs: no coordination
- emit entity migrated domain event
- do this incrementally
- derisk
