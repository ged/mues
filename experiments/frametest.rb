#!/usr/bin/ruby

require "irb/frame"

module FrameTest

	class CallingClass < Object
		def testObject( obj )
			obj.test
		end
	end


	class TestClass < Object
		def test
			frame = IRB::Frame.top( 1 )
			sender = eval "self", frame
			puts "Sender is a #{sender.class.name} object"
		end
	end
end


tester = FrameTest::TestClass.new
callobj = FrameTest::CallingClass.new

thr = Thread.new {
	callobj.testObject( tester )
}


thr.join
