#!/usr/bin/ruby
###########################################################################
=begin

= Config.rb

== Name

MUES::Config - Configuration file class for the MUES engine

== Synopsis

  require "mues/Config"

  config = MUES::Config.new( "mues.cfg" )

  config["serverPort"]						# -> 6565
  config["serverAddress"]					# -> "0.0.0.0"
  
=end
###########################################################################

require "mues/MUES"
require "mues/Exceptions"

module MUES

	class ConfigFormatError < SyntaxError; end

	class Config < Object

		### METHOD: initialize( sourceIoOrFileName = nil )
		def initialize( source = nil )
			unless source.nil? then
				if source.is_a?( IO )
					@mainSection = _initFromIo( source )
				elsif source.is_a?( String )
					@mainSection = _initFromFile( source )
				else
					raise TypeError "Source must be an IO or the name of a file"
				end
			else
				@mainSection = Config::Section.new( "__main__" )
			end

			super()
		end

		def []( key )
			@mainSection[ key ]
		end

		def []=( key, value )
			@mainSection[ key ] = value
		end

		def dump
			@mainSection.dump
		end

		protected

		### (PROTECTED) METHOD: _initFromIo( source )
		def _initFromIo( source )
			checkType( source, IO )

			_parseConfig( source.readlines )
		end

		### (PROTECTED) METHOD: _initFromFile( source )
		def _initFromFile( source )
			checkType( source, String )

			io = File.open( source, "r" )
			_initFromIo( io )
		end

		### (PROTECTED) METHOD: _parseConfig( contentArray )
		def _parseConfig( contentArray )
			checkType( contentArray, Array )

			### Create a new main section, and add it to the sectionBranch stack,
			### which is how we keep track of which part of the heirarchy is
			### currently open.
			mainSection = Config::Section.new( "__main__" )
			sectionBranch = [ mainSection ]
			lineCount = 0
			hereDoc = nil

			### Iterate over each line of the config
			contentArray.each do |line|
				lineCount += 1

				### Parse each line
				if hereDoc.nil? then
					case line

						### Skip comments and blank lines
					when /^\s*#/, /^\s*$/
						next

						### Section close tag -- Check to be sure we're closing the
						### currently open section, and pop it off of the branch stack
					when %r{^\s*</([^>]+)>\s*$}
						unless sectionBranch.last.name.downcase == $1.downcase then
							raise ConfigFormatError,
								"Malformed section '#{sectionBranch.last.name}' at line #{lineCount}"
						end

						sectionBranch.pop

						### Section open tag -- Create a new section and push it onto
						### the branch stack
					when %r{^\s*<([^>]+)>\s*$}
						newSection = Config::Section.new( $1 )
						sectionBranch.last[ $1 ] = newSection
						sectionBranch.push newSection

						### Here-doc (non-indented) -- Set up the here-doc indicator
						### with the value name, the end token, and a null indent
					when %r{^\s*(\w\S+)\s*<<"?(\w+)"?}
						sectionBranch.last[ $1 ] = ""
						hereDoc = [ $1, $2, "" ]

						### Here-doc (indented) -- Set up the here-doc indicator, this
						### time with an indent
					when %r{^(\s*)(\w\S+)\s*<<-"?(\w+)"?}
						sectionBranch.last[ $2 ] = ""
						hereDoc = [ $2, $3, $1 ]

						### Plain key/value pair -- Set the value in the current section
						### after stripping off quotes
					when %r{^\s*(\w\S+)\s+(\S.*)$}
						key, value = [ $1, $2 ]

						if value =~ %r{^(true|yes|on)$} then
							value = true
						elsif value =~ %r{^(false|no|off)$} then
							value = false
						else
							value.gsub!(%r{^"|"\s*$}, "")
						end

						sectionBranch.last[ key ] = value

						### Anything else is an error
					else
						raise ConfigFormatError,
							"Could not parse '#{line}' at line #{lineCount}"
					end

					### In the middle of a here-doc, look for the closing token
				else
					### If we've seen the closing token, finish up the current value
					if line =~ /^#{hereDoc[2]}#{hereDoc[1]}/
						hereDoc = nil
						next

						### Otherwise, add the current line to the previous ones after
						### stripping off any leading indent
					else
						line.sub!( "^#{hereDoc[2]}", "" )
						sectionBranch.last[ hereDoc[0] ] += line
					end
				end
			end

			return mainSection
		end



		### Configuration section class
		class Section < Object

			attr_reader :name

			### METHOD: initialize( sectionName )
			def initialize( sectionName )
				checkType( sectionName, String )
				@name = sectionName
				@values = {}
				super()
			end

			### METHOD: dump( indent = 0 ) -> aString
			def dump( indent=0 )
				dumped = ""
				indentStr = "\t" * indent

				### Collect all the config keys, Schwartzian-transform them into an
				### sorted array, and then iterate over the array.
				@values.keys.collect do |key|
					[ key, @values[key].is_a?(Config::Section) ? "~~%s" % [@values[key].name] : key ]
				end.sort do |a,b|
					a[1] <=> b[1]
				end.collect do |ary|
					ary[0]
				end.each do |key|

					### Call dump for each section, and dump any plain values into
					### their key/value pairs at the current indent
					if @values[ key ].is_a?( Config::Section )
						dumped += "\n%s<%s>\n" % [indentStr, @values[ key ].name]
						dumped += @values[ key ].dump( indent + 1 )
						dumped += "%s</%s>\n" % [indentStr, @values[ key ].name]
					elsif @values[ key ].is_a?(String) && @values[key] =~ %r{\n} then
						dumped += %Q{%s%s <<-EOF\n%s%sEOF\n} % [indentStr, key, @values[ key ].to_s, indentStr]
					else
						dumped += %Q{%s%s "%s"\n} % [indentStr, key, @values[ key ].to_s]
					end
				end

				return dumped
			end

			### METHOD: [ key ]
			def []( key )
				checkType( key, String )
				return @values[ key.downcase ]
			end

			### METHOD: [ key ] = value
			def []=( key, value )
				checkType( key, String )
				checkType( value, Numeric, String, Config::Section, TrueClass, FalseClass )

				@values[ key.downcase ] = value
			end

			### METHOD: has_key?( key )
			### METHOD: key?( key )
			### METHOD: include?( key )
			def has_key?( key )
				@values.has_key?( key.downcase )
			end
			alias :key? :has_key?
			alias :include? :has_key?

		end

	end

end

