#!/usr/bin/ruby -w

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'mues/config'


module MUES
	class ConfigTestCase < MUES::TestCase

		MethodTests = {
			# Method chain								# Expected value
			[ :general, :server_name ]					=> "Experimental MUD",
			[ :general, :server_admin ]					=> "MUES Admin <muesadmin@localhost>",

			[ :engine,  :debug_level ]					=> 0,
			[ :engine,  :exception_stack_size ]			=> 10,
			[ :engine,	:objectstore, :backend ]		=> "Flatfile",
			[ :engine,	:objectstore, :memorymanager]	=> "Null",
		}

		AttributeTests = {
			[ [:commandshell],			"shell-class"]	=> "MUES::CommandShell",
		}


		def test_00_NoArgInstantiation
			res = nil

			# Test no-arg instantiation (default config)
			assert_nothing_raised { res = MUES::Config::new }
			assert_instance_of MUES::Config, res

			addSetupBlock {
				@config = MUES::Config::new
			}
		end

		def test_01_FileArgInstantiation
			rval = nil
			configFile = writeDefaultConfigFile()
			debugMsg "Testing with config file '#{configFile}'"

			# Test illegal one-arg instantiation (should fail)
			assert_raises( TypeError ) { MUES::Config::new(14) }
			assert_raises( TypeError ) { MUES::Config::new(["foo"]) }

			# Test one-arg filename instantiation
			assert_nothing_raised { rval = MUES::Config::new(configFile) }
			assert_instance_of MUES::Config, rval

			# Test one-arg filehandle instantiation
			File::open( configFile, File::RDONLY ) {|ifh|
				assert_nothing_raised { rval = MUES::Config::new(ifh) }
				assert_instance_of MUES::Config, rval
			}
		ensure
			File::delete( configFile ) if passed?
		end


		def test_10_MethodChain
			MethodTests.each {|chain,expectedResult|
				debugMsg "Calling #{chain.join('.')}, expecting #{expectedResult.inspect}"

				lastRes = @config
				chain.each {|sym|
					assert_nothing_raised { lastRes = lastRes.send( sym ) }
				}
				assert_equal expectedResult, lastRes
			}
		end

		def test_20_Attributes
			AttributeTests.each {|chainAttr,expectedResult|
				debugMsg "Calling %s[%s], expecting %s" %
					[ chainAttr[0].join('.'), chainAttr[1].inspect, 
					  expectedResult.inspect ]

				lastRes = @config
				chain, attrName = *chainAttr

				chain.each {|sym|
					assert_nothing_raised { lastRes = lastRes.send( sym ) }
				}
				assert_equal expectedResult, lastRes[ attrName ]
			}
		end


		#########
		protected
		#########

		def writeDefaultConfigFile
			lib = nil
			$".grep( %r:mues/Config\.rb: ) {|path|
				$LOAD_PATH.find {|prefix|
					if File.exists?( "#{prefix}/#{path}" )
						lib = "#{prefix}/#{path}"
						break
					end
				}
			}

			debugMsg "Found mues/Config at '#{lib}'"
			raise "Can't find mues/Config" if lib.nil?
			testfile = "testconfig.%d.xml" % $$
			debugMsg "Writing config file to '#{testfile}'"

			File::open( testfile, File::WRONLY|File::CREAT, 0644 ) {|ofh|
				inDataSection = false
				File::readlines( lib ).each {|line|
					case line
					when /^__END_DATA__$/
						inDataSection = false
						next

					when /^__END__$/
						inDataSection = true
						next
					end

					next unless inDataSection
					debugMsg "Writing config line: #{line}"
					ofh.print line
				}
			}						
				
			return testfile
		end

	end

end


