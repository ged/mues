#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'metaclasses'

class (>>>testsubject<<<)TestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_Instantiate
		(>>>POINT<<<)
	end

end # class (>>>testsubject<<<)TestCase

