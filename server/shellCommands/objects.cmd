#
# The objects MUES::CommandShell command.
# Time-stamp: <28-Oct-2002 09:05:17 deveiant>
# $Id: objects.cmd,v 1.3 2002/10/29 07:38:04 deveiant Exp $
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

If the optional pattern argument is given, only those objects whose class name
matches the pattern (case-insensitively) are shown.

== Usage
  objects [<pattern>]

== Restriction
implementor

== Code

	# Get the user-supplied pattern, if any
	pat = if ! argString.empty?
			  Regexp::new( argString, Regexp::IGNORECASE )
		  else
			  nil
		  end

	# Look for objects, keeping those that match, or all of 'em if there's no
	# pattern.
	objectList = []
	ObjectSpace.each_object( MUES::Object ) {|obj|
		objectList << obj if
			pat.nil? || pat.match( obj.class.name )
	}

	# If no objects were returned, state either that the pattern failed to match
	# any class if one was specified, or that the physical laws of the universe
	# are crumbling to ash around us if not.
	if objectList.empty?
		if pat.nil?
			return [MUES::OutputEvent::new(">>> What?!? No objects?\n\n")]
		else
			return [MUES::OutputEvent::new("No matching objects.\n\n")]
		end
	end

	# Build a table out of the found objects
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
	return [MUES::OutputEvent::new(objectTable)]
