#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'metaclasses'

class (>>>testsubject<<<)TestCase < MUES::TestCase

	### Test instantiation with various arguments
	def test_Instantiate
		(>>>POINT<<<)
	end

end # class (>>>testsubject<<<)TestCase

