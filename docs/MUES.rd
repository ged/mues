=begin

= MUES - A multi-user environment server

There is an ((<online
version|URL:http://docs.faeriemud.org/bin/view/Dream/TheEngine>))
of this document, which may be more recent.

== Introduction 

The Multi-User Environment Server is a multiplexing, multithreaded, event-driven
internet game environment server. It facilitates the building of online
multiplayer games or simulations by providing one or more dynamically-programmed
object environments (worlds), the means to access these environments using a
network client, various useful services or daemons for creating in-game systems,
and an event model for facilitating the interaction of all the parts.

== System Overview

=== Requirements

* Load, configure, and maintain one or more World objects, which are
  database-defined dynamic metaclass environments

* Handle player connection, login, and player object maintenance through a
  client protocol or simple telnet/HTTP

* Maintain a proxy interface to one or more distributed services, called
  Sciences

* Coordinate, queue, and dispatch Events between the World object/s, Player
  object/s, and the Sciences.

* Execute an event loop which serves as the fundamental unit of time for each
  world((-Instances of the World class-))

=== Secondary systems

* Offer tools for creating and modifying classes in the metaclass environments,
  accessable from a web browser or other generic interface. 

== Design Considerations

=== Assumptions and Dependencies

(1) A working Ruby 1.6 interpreter
(2) A MySQL((-MySQL Homepage: ((<URL:http://www.mysql.com/>))-)) or PostgreSQL((-PostgreSQL Homepage: ((<URL:http://www.postgresql.org/>))-)) database

=== General Constraints

(1) Define distributed services protocol and reference implementation
(2) Must be able to talk to third-party clients easily
(3) Metaclass code must be kept isolated from the core system for security
(4) Coder's interface must be

=== Goals and Guidelines

(1) Simple is better
(2) Implement first, optimize later
(3) The better the tools are, the more people will use them

=== Development Methods

((|Not done yet|))

== Architectural Strategies

((*Describe any design decisions and/or strategies that affect the overall
organization of the system and its higher-level structures. These strategies
should provide insight into the key abstractions and mechanisms used in the
system architecture. Describe the reasoning employed for each decision and/or
strategy (possibly referring to previously stated design goals and principles)
and how any design goals or priorities were balanced or traded-off. Such
decisions might concern (but are not limited to) things like the following:*))

* Use of a particular type of product (programming language, database, library, etc. ...)
* Reuse of existing software components to implement various parts/features of the system
* Future plans for extending or enhancing the software
* User interface paradigms (or system input and output models)
* Hardware and/or software interface paradigms
* Error detection and recovery
* Memory management policies
* External databases and/or data storage management and persistence
* Distributed data or control over a network
* Generalized approaches to control
* Concurrency and synchronization
* Communication mechanisms
* Management of other resources

((*Each significant strategy employed should probably be discussed in its own
subsection, or (if it is complex enough) in a separate design document (with an
appropriate reference here of course). Make sure that when describing a design
decision that you also discuss any other significant alternatives that were
considered, and your reasons for rejecting them (as well as your reasons for
accepting the alternative you finally chose). Sometimes it may be most effective
to employ the "pattern format" for describing a strategy.*))

== System Architecture

((*This section should provide a high-level overview of how the functionality and
responsibilities of the system were partitioned and then assigned to subsystems
or components. Don't go into too much detail about the individual components
themselves (there is a subsequent section for detailed component
descriptions). The main purpose here is to gain a general understanding of how
and why the system was decomposed, and how the individual parts work together to
provide the desired functionality.*))

((*At the top-most level, describe the major responsibilities that the software
must undertake and the various roles that the system (or portions of the system)
must play. Describe how the system was broken down into its
components/subsystems (identifying each top-level component/subsystem and the
roles/responsibilities assigned to it). Describe how the higher-level components
collaborate with each other in order to achieve the required results. Don't
forget to provide some sort of rationale for choosing this particular
decomposition of the system (perhaps discussing other proposed decompositions
and why they were rejected). Feel free to make use of design patterns, either in
describing parts of the architecture (in pattern format), or for referring to
elements of the architecture that employ them.*))

((*If there are any diagrams, models, flowcharts, documented scenarios or use-cases
of the system behavior and/or structure, they may be included here (unless you
feel they are complex enough to merit being placed in the Detailed System Design
section). Diagrams that describe a particular component or subsystem should be
included within the particular subsection that describes that component or
subsystem.*))

: The Engine

  The main server executable

: World Objects

  Game world objects, subclasses of MetaClass::Milieu, metaclass environments.

: Event Queues

  Two queues of events to be processed from the worlds, players, and internal systems -- one is a prioritized immediate event queue, and the other is a time-controlled delayed event queue.

: Thread Pools

  The pools of worker threads tasked with handling queued events, socket I/O, and other internal tasks

: Listener Socket

  The incoming connection socket

: Player Objects

  Player connection class; each has its own thread, and is reponsible for interacting with the Engine on the user's behalf.

: MODS Proxy

  Proxy interface to the distributed services (Sciences)

: Object Store

  Database-backed game object store

== Policies and Tactics

== Detailed System Design

== Glossary

: Sciences

  Services which provide the mechanics of the hosted world/s

: The Game Client

  The end-user interface to the game

: Events

  The objects which encapsulate server and game tasks

== Bibliography

The structure of this specification was copied pretty much wholesale from:

((<A Software Design Specification Template|URL:http://www.enteract.com/~bradapp/docs/sdd.html>))
by Brad Appleton <((<bradapp@enteract.com|URI:mailto:bradapp@enteract.com>))>
Copyright (c) 1994-1997 by Bradford D. Appleton

The original also has the following declaration in it, which is included here
despite the fact that it's not a "verbatim copy":

Permission is hereby granted to make and distribute verbatim copies of this
document provided the copyright notice and this permission notice are preserved
on all copies.

== History

  $Id: MUES.rd,v 1.1 2001/03/15 02:22:16 deveiant Exp $

=end
