#!/usr/bin/ruby -w

$DEBUG = true

if File.directory? "lib"
	$LOAD_PATH.unshift "lib", "ext"
elsif File.directory? "../lib"
	$LOAD_PATH.unshift "../lib", "../ext"
else
	raise "Cannot find lib and ext directories!"
end


require 'mues/mixins'

puts "Defining base class"
module Base
	class Service
		include MUES::FactoryMethods

		def self.beforeCreation( backendClass, *args )
			puts "   beforeCreation: About to instantiate a #{backendClass.inspect}."
		end

		def self.afterCreation( instance )
			puts "   afterCreation: Instance is '#{instance.inspect}'."
		end

		def self.derivativeDirs
			puts "   derivativeDirs: Setting to ['experiments', '.']"
			return ["experiments", "."]
		end
	end

	puts "Defining subclasses"
	class SubService < Service
	end

	class OtherService < Service
	end

	class SubSubService < SubService
	end
end


# Test three already-defined subtypes, one externally-loadable one, and one that
# doesn't exist (which should raise a LoadError)
%w{Sub Other SubSub External Breakage}.each do |klass|
	puts "\n---\nInstantiating '#{klass}' object:"

	begin
		obj = Base::Service::create( "#{klass}" )
	rescue LoadError => e
		if klass == 'Breakage'
			puts "Error while creating (expected): #{e.message}"
		else
			puts "Unexpected error while creating: #{e.message}"
		end			
	else
		puts "done (#{obj.inspect})"
	end
end


