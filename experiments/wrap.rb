#!/usr/bin/ruby

### Wrap the specified +text+ to the specified +width+.
def wrap( text, width=80 )
	workingText = text.dup
	newText = ''
	
	while workingText.length > width
		i = width
		until workingText[i,1] =~ /\s/ do
			raise RuntimeError, "Text is not wrappable to the specified width." if i < 1
			i -= 1
		end 
		newText << workingText[ 0, i ] << "\n"
		workingText[ 0, i + 1 ] = ''
	end

	newText << workingText
	return newText
end

testString = <<-'EOF'
This is a really long sentence that I expect to be wrapped. Ill append some other stuff just to test it out.

So here, after much delay, and banging my head against many sharp things, and reading some passages I had bookmarked in various books, is my current state of thought about what Story is to FaerieMUD. These are painted with a broad brush, are still very much a work in progress, of course.

Apologies to those coming in in the middle of this dicussion -- feel free to ask lots of questions.
EOF

[ 80, 40, 20, 120 ].each {|width|
	(120/5).times {|i| print "---%02d" % ((i+1) * 5) }
	puts "\n" + wrap( testString, width )
}



