---
title: On migrations 
description: A few tips on how to do version migrations
tags: migrations, software engineering
include_plotly: false
---

During my last job we operated one particular service that was central to the
operation of the platform. As time went on, the API became insufficient for new
use cases and we also found the need to improve the consistency guarantees of
the system. But mainly, we needed to move away from old APIs to a better ones
and we needed to migrate the underlying data to a better model. Old clients had
to move to the new APIs and we had to coordinate this process.

Here are some of the techniques we used in order to do this in an incremental
way.

## Backfill strategy

The first thing is that we followed a sort of backfill strategy: each request
against the new service meant a dual write to the old service (what we sometimes
called a backfill or a write back), and to the new persistence.

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
