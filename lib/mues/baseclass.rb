#!/usr/bin/ruby
# 
# This file contains the singleton class MUES::Metaclass::BaseClass, which is a
# mechanism to provide a common normal Ruby class as a superclass for all
# MUES::Metaclass::Class instances. It is basically just a metaclass wrapper
# around a regular Ruby class.
#
# It wraps the <tt>MUES::Object</tt> class by default, but this default can be
# changed by providing an alternative class to the class's constructor when it
# is first instantiated.
# 
# == Synopsis
#
#	require 'mues/Metaclasses'
#	include MUES
# 
#   myClass = Metaclass::Class::new( "MyClass", Metaclass::BaseClass.instance )
# 
# == Rcsid
#
#  $Id: baseclass.rb,v 1.2 2002/10/04 05:06:43 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'mues/Mixins'
require 'mues/Object'

require 'mues/metaclass/Constants'
require 'mues/metaclass/Class'

module MUES
	module Metaclass

		### A singleton class which acts as a mechanism to provide a common normal
		### Ruby class as a superclass for all MUES::Metaclass::Class
		### instances. It is basically just a metaclass wrapper around a regular
		### Ruby class.
		class BaseClass < Metaclass::Class

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]
			Rcsid = %q$Id: baseclass.rb,v 1.2 2002/10/04 05:06:43 deveiant Exp $

			# Make the constructor private, as this is a singleton
			private_class_method :new

			@@instance = nil
			@@rubyClass = MUES::Object

			### Allow the superclass to be set until the instance is set
			def self.rubyClass=( klass )
				raise Metaclass::Exception, "Can't redefine superclass after instantiation" unless
					@@instance.nil?
				raise ArgumentError, "Superclass must be a Class object" unless
					klass.is_a? ::Class

				# Warn against screwing with reality
				if klass.kind_of? Metaclass::Class
					$stderr.puts "You do realize that, by doing this, you may very well cause the \n" \
					"Universe to implode, right? "
				end

				@@rubyClass = klass
			end

			### Return the instance of the BaseClass object, after potentially
			### creating it.
			def self.instance
				@@instance ||= new( @@rubyClass.name, @@rubyClass )
			end

			def classObj
				@@rubyClass
			end

		end # class BaseClass

	end # module Metaclass
end # module MUES


