#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Exceptions'
require 'mues/os-extensions/Backend'

class ObjectStoreBackendTestCase < MUES::TestCase

	@@TestedStores = %w{Flatfile BerkeleyDB}
	@@name = 'test00'

	def __nextName
		@@name = @@name.succ
	end


	### Test the MUES::ObjectStore::Backend class
	def test_00_BaseClass
		assert_instance_of Class, MUES::ObjectStore::Backend
		assert_raises( MUES::InstantiationError ) {
			MUES::ObjectStore::Backend::new
		}
		assert_respond_to MUES::ObjectStore::Backend, :create
	end


	### Test instantiation with various arguments
	def test_01_Instantiate
		@@TestedStores.each {|storeName|
			assert_nothing_raised { MUES::ObjectStore::Backend::create( storeName, __nextName ) }
		}
	end

end # class ObjectStoreBackendTestCase

