#!/usr/bin/ruby

if $0 =~ /^experiments/
	require 'utils.rb'
else
	require '../utils.rb'
end

include UtilityFunctions

require 'strscan'

class WrappedLineArray
	def initialize( width=80 )
		@width = width
		@lines = ['']
	end

	attr_accessor :lines

	def append( chars )
		if chars.length + @lines.last.length > @width
			@lines.push( '' )
			chars.strip!
		end

		@lines[-1] += chars
	end

end


### Wrap the specified +text+ to the specified +width+.
def wrap( text, width=80 )
	lines = text.split( /\n/ )
	wrappedLines = []
	
	lines.each {|line|
		debugMsg( "Scanning line '#{line}'" )
		wrappedLines.push WrappedLineArray::new( width )
		scanner = StringScanner::new( line, true )

		while scanner.rest?
			appendText = scanner.scan( /\A\s*\S+/ ) || scanner.getch
			wrappedLines.last.append( appendText )
		end
	}
			
	return wrappedLines.collect {|wla| wla.lines.join("\n")}.join("\n")
end

testString = <<-'EOF'
This is a really long sentence that I expect to be wrapped. I'll append some other stuff just to test it out.

So here, after much delay, and banging my head against many sharp things, and reading some passages I had bookmarked in various books, is my current state of thought about what Story is to FaerieMUD. These are painted with a broad brush, are still very much a work in progress, of course.

Apologies to those coming in in the middle of this dicussion -- feel free to ask lots of questions.
EOF

[ 80, 40, 20, 120 ].each {|width|
	header "Wrapping to #{width} characters."
	(120/5).times {|i| print "|--%02d" % ((i+1) * 5) }
	puts "\n" + wrap( testString, width ) + "\n\n"
}



