#!/usr/bin/ruby -w

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require 'mues/exceptions'
require 'mues/os-extensions/backend'

class ObjectStoreBackendTestCase < MUES::TestCase

	@@TestedStores = %w{Flatfile BerkeleyDB}
	@@name = 'test00'

	def nextName
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
			assert_nothing_raised { MUES::ObjectStore::Backend::create( storeName, nextName() ) }
		}
	end

end # class ObjectStoreBackendTestCase

