#!/usr/bin/ruby
######################################################################
=begin

=Role.rb

== Name

Role - An environment role class

== Synopsis

  require "mues/Role"

  genevaCharacter = MUES::Role.new( anEnvironment, "geneva", "Female silver-skinned elf with green eyes" )

== Description

Role objects describe available roles for participation within a environment in
the context of a specific user. They may represent different levels of
functionality, different characters, or available accounts that are open to a
given user.

== Classes
=== MUES::Role
==== Public Methods

--- MUES::Role#<=>( otherRole )

    Comparison operator -- sort roles by the environments to which they belong.

--- MUES::Role#description

    Return the description of the role.

--- MUES::Role#environment

    Return the ((<MUES::Environment>)) to which the role belongs.

--- MUES::Role#name

    Return the name of the role.

--- MUES::Role#to_s()

    Returns a stringified version of the role object.

==== Protected Methods

--- MUES::Role#initialize(  environment, name, description )

    Initialize the role with the given ((|environment|)) (a
    ((<MUES::Environment>)) object), ((|name|)), and ((|description|)) string.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
######################################################################

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"

module MUES
	class Role < Object ; implements Debuggable

		include Event::Handler

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: role.rb,v 1.3 2001/11/01 16:54:06 deveiant Exp $

		### (PROTECTED) METHOD: initialize(  aEnvironment=MUES::Environment, aNameString, aDescString )
		### Initialize the role with the given environment, name, and description string.
		protected
		def initialize( anEnvironment, aNameString, aDescString )
			checkType( anEnvironment, MUES::Environment )
			checkType( aNameString, ::String )
			checkType( aDescString, ::String )

			@environment	= anEnvironment
			@name			= aNameString
			@description	= aDescString

			super()
		end

		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public
		attr_accessor :environment, :name, :description

		### METHOD: to_s()
		### Returns the role description as a string.
		def to_s
			return "%-15s %-50s" % [ @name, @description ]
		end

		### METHOD: <=>( otherRole )
		### Comparison operator
		def <=>( otherRole )
			return @environment <=> otherRole.environment
		end

	end # class Role
end # module MUES

