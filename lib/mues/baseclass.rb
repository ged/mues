#!/usr/bin/ruby
# 
# This file contains a singleton class called Metaclass::BaseClass, which is a
# mechanism to provide a common normal Ruby class as a superclass for all
# Metaclass::Class instances. It is basically just a metaclass wrapper around a
# regular Ruby class.
#
# It wraps the <tt>Object</tt> class by default, but this default can be changed
# by providing an alternative class to the class's constructor when it is first
# instantiated.
# 
# == Synopsis
# 
#   myClass = Metaclass::Class::new( "MyClass", Metaclass::BaseClass.instance )
# 
# == Author
# 
# Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2002 The FaerieMUD Consortium. All rights reserved.
# 
# This module is free software. You may use, modify, and/or redistribute this
# software under the terms of the Perl Artistic License. (See
# http://language.perl.com/misc/Artistic.html)
# 
# == Version
#
#  $Id: baseclass.rb,v 1.1 2002/04/09 06:50:23 deveiant Exp $
# 

require 'metaclass/Constants'
require 'metaclass/Class'

### The base Ruby class metaclass
module Metaclass
	class BaseClass < Metaclass::Class

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: baseclass.rb,v 1.1 2002/04/09 06:50:23 deveiant Exp $

		# Make the constructor private, as this is a singleton
		private_class_method :new

		@@instance = nil
		@@rubyClass = ::Object

		### Allow the superclass to be set until the instance is set
		def BaseClass.rubyClass=( klass )
			raise Metaclass::Exception, "Can't redefine superclass after instantiation" unless
				@@instance.nil?
			raise ArgumentError, "Superclass must be a Class object" unless
				klass.is_a? ::Class

			# Warn against screwing with reality
			if klass.kind_of? Metaclass::Class
				$stderr.puts
				"You do realize that, by doing this, you may very well cause the \n" +
					"Universe to implode, right?" #"
			end

			@@rubyClass = klass
		end

		### Return the instance of the BaseClass object, after potentially
		### creating it.
		def BaseClass.instance
			@@instance ||= new( @@rubyClass.name, @@rubyClass )
		end

		def classObj
			@@rubyClass
		end

	end # class BaseClass
end # module Metaclass
