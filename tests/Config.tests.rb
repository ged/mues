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

require 'mues/config'


class MUES::ConfigTestCase < MUES::TestCase

	# Testing config values
	TestConfig = {
		:general => {
			:serverName			=> "Experimental MUD",
			:serverDescription	=> "An experimental MUES server",
			:serverAdmin		=> "MUES ADMIN <muesadmin@localhost>",
			:rootDir			=> ".",
			:includePath		=> ["lib"],
		},

		:engine => {
			:tickLength			=> 1.0,
			:exceptionStackSize	=> 10,
			:debugLevel			=> 0,
			:eventQueue			=> {
				:minWorkers => 5,
				:maxWorkers => 50,
				:threshold  => 2,
				:safeLevel 	=> 2,
			},
			:privilegedEventQueue => {
				:minWorkers => 2,
				:maxWorkers => 5,
				:threshold  => 1.5,
				:safeLevel 	=> 1,
			},
			:objectStore => {
				:name			=> 'engine',
				:backend		=> 'BerkeleyDB',
				:memorymanager	=> 'Null',
				:visitor		=> nil,
				:argHash		=> {},
			},

			:listeners => {
				'shell' => {
					:kind	=> 'telnet',
					:params	=> {
						:bindPort		=> 4848,
						:bindAddress	=> '0.0.0.0',
						:useWrapper		=> false,
						:questionnaire	=> {
							:name => 'login',
							:params => {
								:userPrompt => 'Username: ',
								:passPrompt => 'Password: ',
							}
						},
						:banner => <<-'...END'.gsub(/\t+/, ''),
							--- #{general.serverName} ---------------
							#{general.serverDescription}
							Contact: #{general.serverAdmin}
						...END
					},
				},
			},
		},

		:environments => {
			:envPath	=> ["server/environments"],
			:autoload	=> {
				'null' => {
					:kind => 'Null',
					:description => "A testing environment without any surroundings.",
					:params => {},
				},
			}
		},

		:commandShell => {
			:commandPath => [],
			:shellClass => nil,
			:tableClass	=> nil,
			:parserClass => nil,
			:params => {
				:reloadInterval => 50,
				:defaultPrompt => 'mues> ',
				:commandPrefix => '/',
			},
		},

		:logging => {
			'MUES'			=> {
				:level => :notice,
				:outputters => ""
			},
			'MUES::Engine'	=> {
				:level => :info,
				:outputters => {"file" => "server/log/server.log"},
			}
		},
	}
	TestConfig.freeze

	# The name of the testing configuration file
	TestConfigFilename = File::join( File::dirname(__FILE__), "testconfig.conf" )

	### Compare +expected+ config value to +actual+.
	def assert_config_equal( expected, actual, msg=nil )
		case expected
		when MUES::Config::ConfigStruct
			assert_instance_of MUES::Config::ConfigStruct, actual, msg
			expected.each {|key,val|
				rval = nil
				assert_nothing_raised { rval = actual.__send__(key) }
				assert_config_equal val, rval, "#{msg}: #{key} member"
			}

		when Hash
			assert_hash_equal expected, actual

		else
			assert_equal expected, actual, msg
		end
	rescue Test::Unit::AssertionFailedError => err
		bt = err.backtrace
		debugMsg "Unaltered backtrace is:\n  ", bt.join("\n  ")
		cutframe = bt.reverse.find {|frame|
			/assert_config_equal/ =~ frame
		}
		debugMsg "Found frame #{cutframe}"
		firstIdx = bt.rindex( cutframe ) || 0
		#firstIdx += 1
		
		$stderr.puts "Backtrace (frame #{firstIdx}): "
		bt.each_with_index do |frame,i|
			if i < firstIdx
				debugMsg "  %s (elided)" % frame
			elsif i == firstIdx
				debugMsg "--- cutframe ------\n", frame, "\n--------------------"
			else
				debugMsg "  %s" % frame
			end
		end

		Kernel::raise( err, err.message, bt[firstIdx..-1] )
	end

	def setup
		File::delete( TestConfigFilename ) if
			File::exists?( TestConfigFilename )
	end
	alias_method :set_up, :setup

	def teardown
		File::delete( TestConfigFilename ) if
			File::exists?( TestConfigFilename )
	end
	alias_method :tear_down, :teardown



	#################################################################
	###	T E S T S
	#################################################################

	### Classes test
	def test_00_Classes
		printTestHeader "MUES::Config: Classes"

		assert_instance_of Class, MUES::Config
		assert_instance_of Class, MUES::Config::ConfigStruct
		assert_instance_of Class, MUES::Config::Loader
	end


	### Test the ConfigStruct class
	def test_05_ConfigStruct
		printTestHeader "MUES::Config: ConfigStruct class"
		struct = rval = nil

		assert_nothing_raised {
			struct = MUES::Config::ConfigStruct::new( TestConfig )
		}
		assert_instance_of MUES::Config::ConfigStruct, struct

		# :TODO: This whole block should really be factored into something that
		# can traverse the whole TestConfig recursively to test more then 2-deep
		# methods.
		TestConfig.each {|key, val|

			# Response predicate
			assert_nothing_raised { rval = struct.respond_to?(key) }
			assert_equal true, rval, "respond_to?( #{key.inspect} )"
			assert_nothing_raised { rval = struct.respond_to?("#{key}=") }
			assert_equal true, rval, "respond_to?( #{key.inspect}= )"
			assert_nothing_raised { rval = struct.respond_to?("#{key}?") }
			assert_equal true, rval, "respond_to?( #{key.inspect}? )"

			# Get
			assert_nothing_raised { rval = struct.send(key) }
			assert_config_equal val, rval, "#{key}"
			
			# Predicate
			assert_nothing_raised { rval = struct.send("#{key}?") }
			if val
				assert_equal true, rval
			else
				assert_equal false, rval
			end

			# Set (and test get again to make sure it actually set a correct value)
			assert_nothing_raised { struct.send("#{key}=", val) }
			assert_nothing_raised { rval = struct.send(key) }
			assert_config_equal val, rval, "#{key} after #{key}="
		}
	end


	### Test ConfigStruct hashification
	def test_06_ConfigStructToHash
		printTestHeader "MUES::Config: Hashification of ConfigStructs"
		struct = rval = nil

		struct = MUES::Config::ConfigStruct::new( TestConfig )
		
		# Call all member methods to convert subhashes to ConfigStructs
		TestConfig.each {|key,val| struct.send(key) }

		assert_nothing_raised { rval = struct.to_h }
		assert_instance_of Hash, rval
		assert_hash_equal TestConfig, rval
	end

	
	#### Test instantiation of the Config class
	def test_10_InstantiationWithoutArgs
		printTestHeader "MUES::Config: Instantiation without arguments"
		rval = config = nil

		assert_nothing_raised { config = MUES::Config::new }
		assert_instance_of MUES::Config, config

		MUES::Config::Defaults.each {|key,val|
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}

		# Test for delegated methods
		[:to_h, :members, :member?].each {|sym|
			assert_respond_to config, sym
		}
	end


	### Test instantiation of the Config class with configuration values.
	def test_11_InstantiationWithArgs
		printTestHeader "MUES::Config: Instantiation with arguments"
		rval = config = nil

		assert_nothing_raised {
			config = MUES::Config::new( TestConfig )
		}
		assert_instance_of MUES::Config, config

		# The configuration values should be the test config merged with the
		# defaults for the config class.
		(TestConfig.keys|MUES::Config::Defaults.keys).each {|key|
			val = TestConfig[key] || MUES::Config::Defaults[key]
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}
	end


	### Test the abstract Config::Loader class.
	def test_30_Loader
		printTestHeader "MUES::Config: Loader base class"

# Removed until I figure out the weird doubling bug with AbstractClass [MG]
#		assert_raises( MUES::InstantiationError ) {
#			MUES::Config::Loader::new
#		}

		assert_respond_to MUES::Config::Loader, :create
	end


	### Test the ::create method of Loader with the YAML Loader class.
	def test_31_CreateYamlLoader
		printTestHeader "MUES::Config: YAML loader"
		loader = rval = nil

		assert_nothing_raised {
			loader = MUES::Config::Loader::create( 'yaml' )
		}
		assert_kind_of MUES::Config::Loader, loader

		assert_nothing_raised {
			loader = MUES::Config::Loader::create( 'YAML' )
		}
		assert_kind_of MUES::Config::Loader, loader

		assert_nothing_raised {
			loader = MUES::Config::Loader::create( 'Yaml' )
		}
		assert_kind_of MUES::Config::Loader, loader
	end


	### Write config
	def test_40_ConfigWriteRead
		printTestHeader "MUES::Config: #write and #read"
		
		config = MUES::Config::new( TestConfig )
		assert_nothing_raised {
			config.write( TestConfigFilename )
		}

		otherConfig = MUES::Config::load( TestConfigFilename )

		assert_config_equal config.struct, otherConfig.struct
	end


	### Changed methods
	def test_50_changed
		printTestHeader "MUES::Config: #changed? and .item.modified?"
		rval = nil

		config = MUES::Config::new( TestConfig )
		assert_nothing_raised {
			rval = config.changed?
		}
		assert_equal false, rval

		
	end

end


