=begin

= MUES - A multi-user environment server
== Introduction 

The Multi-User Environment Server is a multiplexing, multithreaded, event-driven
internet game environment server. It facilitates the building of online
multiplayer games or simulations by providing one or more dynamically-programmed
object environments (worlds), the means to access these environments using a
network client, various useful services or daemons for creating in-game systems,
and an event model for facilitating the interaction of all the parts.

== System Overview
=== The Engine

The engine is the server part of the MUES. It is reponsible for containing world
objects and facilitating the interaction between clients which connect to the
server and the worlds it contains.

=== The Metaclass Library

The metaclass library is the collection of classes which allows the code running
inside the world objects to be written an executed dynamically. It is used to
build libraries of world object classes which do not exist as traditional
disk-loaded classes, but rather as in-memory or in-network constructs.

=== Secondary systems

There will eventually be tools built for creating and modifying the game class
libraries from a web browser or other generic interface.

== System Architecture
=== The Ruby-MUES Modules

These modules are the classes which make up the MUES server. At startup, the
Config class is loaded, and is used to load the server configuration file. The
'Engine' class is then loaded and instantiated, and the method (({start()})) is
called with the Config object as an argument.

==== MUES Classes

: ((*MUES*)) - (({mues/Namespace}))

  A collection of modules, functions, and base classes for the MUES
  namespace. Requiring it defines the (({MUES::})) namespace, the base object
  class ((({MUES::Object}))), and several mixin/interfaces for MUES Classes
  ((({MUES::AbstractClass})), (({MUES::Notifiable})), and
  (({MUES::Debuggable}))).

: ((*MUES::Engine*)) - (({mues/Engine}))

  This class is the main server class for the Multi-User Environment Server
  (MUES). The server encapsulates and provides a simple front end/API for the
  following tasks:

  * Loading, configuring, and maintaining one or more World objects, which contain a
    class library made up of metaclasses stored in a database

  * Handle player connection, login, and player object maintenance through a
    client protocol or simple telnet/HTTP connection

  * Maintain one or more game Sciences, which provide shared event-driven
    services to the hosted game worlds

  * Coordinate, queue, and dispatch Events between the World objects, Player
    objects, and the Sciences.

  * Execute an event loop which serves as the fundamental unit of time for
    each world

: ((*MUES::Service*)) - (({mues/Service}))

  An abstract base class for MUES services. A service is a subsystem which
  provides some functionality to the hosted worlds or other subsystems through
  (({ServiceEvent}))s. There are several services (that will be) included with
  the MUES by default: (({MUES::Service::RPC})),
  (({MUES::Service::Linguistics})), and (({MUES::Service::HTTP})).

: ((*MUES::Config*)) - (({mues/Config}))

  Configuration file reader/writer class. Given an IO object, a filename, or a
  String with configuration contents, this class parses the configuration and
  returns an instantiated configuration object that provides a hash interface to
  the config values. MUES::Config objects can also dump the configuration back
  into a string for writing.

: ((*MUES::Log*)) - (({mues/Log}))

  A log handle class. Creating one will open a filehandle to the specified file,
  and any message sent to it at a level greater than or equal to the specified
  logging level will be appended to the file, along with a timestamp and an
  annotation of the level.

: ((*MUES::EventQueue*)) - (({mues/EventQueue}))

  MUES::EventQueue is a queue with an embedded thread work crew for event
  handling.

: ((*MUES::Player*)) - (({mues/Player}))

  The MUES::Player class encapsulates a remote socket connection to a client. It
  contains the raw socket object, an IOEventStream object which is used to
  manipulate and direct input and output between the remote user and the player
  object, an array of characters which are currently being controlled, and some
  miscellaneous information about the client.

: ((*MUES::IOEventFilters*)) - (({mues/IOEventFilters}))

  A collection of input and output event filter classes. Instances of these classes
  act as filters for an IOEventStream object in interactive components of the
  FaerieMUD Engine. They can be used to filter or channel input from the user and
  output from Engine subsystems or the user's player object. The modules
  themselves live under the (({mues/filters})) directory, but you shouldn't have
  to require them individually (though you can, of course).

: ((*MUES::IOEventStream*)) - (({mues/IOEventStream}))

  (({MUES::IOEventStream})) is a filtered input/output stream class for the
  intercommunication of objects in the FaerieMUD engine. It it primarily used for
  input and output events bound for or coming from the socket object contained in
  a ((<MUES::Player>)) object, but it can be used to route input and output events
  for any object which requires a complex I/O abstraction.

: ((*MUES::Science*)) - (({mues/Science}))

  An abstract base class for world "science" object classes. World sciences are
  world-specific subsystems that either require privileged access to information
  or are used as general function groups throughout the world classes.

: ((*MUES::ClassLibrary*)) - (({mues/ClassLibrary}))

  A metaclass collection container object class.

: ((*MUES::Events*)) - (({mues/Events}))

  This module is a collection of system-level event classes in the MUES
  server. See the documentation for the class for a more in-depth coverage of the
  various event classes.

: ((*MUES::Exceptions*)) - (({mues/Exceptions}))

  This module contains exception classes for use in the MUES server.

: ((*MUES::ObjectStore*)) - (({mues/ObjectStore}))

  This class is a generic front end to various means of storing MUES objects. It
  uses one or more configurable back ends which serialize and store objects to
  some kind of storage medium (flat file, database, sub-atomic particle inference
  engine), and then later can restore and de-serialize them.

: ((*MUES::WorkerThread*)) - (({mues/WorkerThread}))

  A derivative of the Thread class which is capable of storing an associated
  timestamp. This functionality can be used to ascertain how long the thread has
  been running.

: ((*MUES::World*)) - (({mues/World}))

  An abstract factory class for MUES world objects.

===== MUES Interfaces/Mixins

: ((*MUES::Notifiable*)) - from (({mues/Namespace}))

  An interface that can be implemented by objects (typically, but not
  necessarily, classes) which need global notification of changes to the
  Engine^s state outside of the event system. This can be used for
  initialization, cleanup, etc. when the event system is not running.
  
  The methods which it requires/implements are:

--- atEngineStartup( engineObject )

    This method will be called after the engine has started and is ready for
    events.

--- AtEngineShutdown( engineObject )

	This method will be called just before the engine shuts down, and can be
	used to queue critical cleanup events that need to be executed before the
	event subsystem is shut down.

: (({MUES::Debuggable})) - from (({mues/Namespace}))

  A mixin that can be used to add debugging capability to a class and
  its instances.

  Mixing Debuggable into your class gives you the following methods:

--- debugMsg( level, message )

    Output the specified messages to STDERR if the debugging level for the
    receiver is at ((|level|)) or higher.

--- debugLevel=( value )

	Set the debugging level for the receiver to the specified
	((|level|)). The ((|level|)) may be a (({Fixnum})) between 0 and 5, or
	(({true})) or (({false})). Setting the level to 0 or (({false})) turns
	debugging off.
    
--- debugLevel()

	Return the debug level of the receiver as a (({Fixnum})).

--- debugged?

	Return true if the receiver's debug level is >= 1.

== History

  $Id: MUES.rd,v 1.5 2001/07/26 00:32:27 deveiant Exp $

=end
