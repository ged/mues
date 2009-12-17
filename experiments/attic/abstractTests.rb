
if File.directory?( "ext" )
	$stderr.puts "Adding 'lib' and 'ext' to the load path."
	$LOAD_PATH.unshift( "lib", "ext" )
elsif File.directory?( "../ext" )
	$stderr.puts "Adding '../lib' and '../ext' to the load path."
	$LOAD_PATH.unshift("../lib", "../ext")
else
	raise "Couldn't find load path"
end

require "mues"

module MUES
	class Something < MUES::Object ; implements MUES::AbstractClass
		abstract :test
		abstract_arity :testArity, 1
	end

	class SomethingElse < Something
	end

	class SomeThingy < SomethingElse
		def test
			puts "meow"
		end
	end

	class SomethingOther < Something
		def test
			puts "test"
		end
		def testArity( something )
			puts something
		end
	end
end

begin
	puts "Instantiating Something"
	s = MUES::Something::new
rescue => e
	puts "Caught #{e.type.name}: #{e.message}"
end

begin
	puts "Instantiating SomethingElse"
	s = MUES::SomethingElse::new
rescue => e
	puts "Caught #{e.type.name}: #{e.message}"
	puts "\t" + e.backtrace.join( "\n\t" )
end

begin
	puts "Instantiating SomethingOther"
	s = MUES::SomethingOther::new
rescue => e
	puts "Caught #{e.type.name}: #{e.message}"
end

begin
	puts "Instantiating SomeThingy"
	s = MUES::SomeThingy::new
rescue => e
	puts "Caught #{e.type.name}: #{e.message}"
end

begin
	puts "Virtualizing a method in a concrete class"
	module MUES
		class SomethingElse
			abstract :foo
		end
	end
rescue => e
	puts "Caught #{e.type.name}: #{e.message}"
end
