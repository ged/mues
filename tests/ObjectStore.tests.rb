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

require 'mues/objectstore'

class ObjectStoreTestCase < MUES::TestCase

	TestOSConfig = {
		:name		=> 'teststore',
		:backend	=> 'Flatfile',
		:memmgr		=> 'Null',
	}

	### Test instantiation with various arguments
	def test_Instantiate
		os = nil
		
		# Instantiation via new() should fail
		assert_raises( NoMethodError ) { MUES::ObjectStore::new }
		assert_raises( TypeError ) { MUES::ObjectStore::create(1) }

		# However, instantiation via create() should work
		assert_nothing_raised {
			os = MUES::ObjectStore::create(TestOSConfig)
		}
	end

end # class ObjectStoreTestCase

