#
# The objects MUES::CommandShell command.
# Time-stamp: <14-Sep-2002 08:02:24 deveiant>
# $Id: objects.cmd,v 1.2 2002/09/15 07:44:37 deveiant Exp $
#
# == Authors:
# * Michael Granger <ged@FaerieMUD.org>
#

= objects

== Abstract
Display server objectspace table.

== Description
This command displays a table of all objects in memory that are derived from
MUES::Object, along with information about each one. This command should be used
with caution, as it is not only resource-intensive, but can potentially output a
very large amount of information.

== Usage
  objects

== Restriction
implementor

== Code

  objectList = []
  ObjectSpace.each_object( MUES::Object ) {|obj| objectList << obj}

  objectTable = "#{objectList.length} active MUES objects:\n\n" <<
	  "\t        Id  Class                          Frozen  Tainted\n"

  objectList.sort {|a,b|
	  (a.class.name <=> b.class.name).nonzero? || a.id <=> b.id
  }.each {|obj|
	  objectTable << "\t%10d  %-30s   %1s      %1s\n" % [
		  obj.id,
		  obj.class.name,
		  obj.frozen? ? "y" : "n",
		  obj.tainted? ? "y" : "n"
	  ]
  }
  objectTable << "\n"
  return [MUES::OutputEvent.new(objectTable)]

