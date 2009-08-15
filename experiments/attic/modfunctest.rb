#!/usr/bin/ruby -w

# This is a little script to test the feasability of generalizing the attribute
# and operator accessors/generators out of Metaclass::Class into a mixin.

class Attribute

	module Methods

		def initialize( *args )
			@attributes = []
			super( *args )
		end

		attr_reader :attributes, :operations

		def hasAttribute?( attribute )
			@attributes.include? attribute
		end

		def addAttributes( *attribs )
			@attributes |= attribs
		end

		def delAttributes( *attribs )
			@attributes -= attribs
		end
	end

end


class Metaclass
	include Attribute::Methods

	def initialize
		super()
	end
end


def message( fmt, *args )
	$stderr.puts sprintf( fmt, *args )
end

message 'Instantiating a Metclass and an Attribute'
mc = Metaclass::new
attrib = Attribute::new

message 'Attempting to add attribute to the metaclass'
mc.addAttributes( attrib )

message 'Testing to see if the metaclass has the attribute: %s',
	mc.hasAttribute?( attrib )

message 'Removing the attribute'
mc.delAttributes( attrib )



	
