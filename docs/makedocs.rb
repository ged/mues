#!/usr/bin/ruby
#
#	MUES Documentation Generation Script
#	$Id: makedocs.rb,v 1.2 2001/12/06 13:38:25 red Exp $
#
#	Copyright (c) 2001, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

if $0 =~ /docs#{File::Separator}.*$/
	baseDir = $0.gsub( /docs#{File::Separator}.*$/, '' )
	$: << baseDir
else
	$: << '..'
end

require "ftools"
require "find"
require "delegate"

require "utils"
include UtilityFunctions

$extendedHtml = false
begin
	require "rd/rd2html-ext-lib"
	$extendedHtml = true
rescue LoadError => e
	puts "rd/rd2html-ext-lib unavailable, will not use extended HTML"
end

class Generator < SimpleDelegator

	class HtmlDelegate
		def initialize( docsDir )
			@docsDir = docsDir
			@targetDir = File.join( docsDir, "html" )
			@generator = findProgram( 'rd2' ) or
				raise RuntimeError, "You don't seem to have the rd2 program"
			$stderr.puts( "Using extended HTML library" ) if $extendedHtml
			@prepIsDone = false
		end

		def doPrep
			File.makedirs( @targetDir, File.join(@targetDir, "stylesheets") )
			File.copy( File.join(@docsDir, "stylesheets", "rd.css"),
					   File.join(@targetDir, "stylesheets", "rd.css"),
					   true )

			@prepIsDone = true
		end

		# /usr/bin/rd -r html --with-css=/stylesheets/rd.css --html-lang=en \
		#         -ohtml/MUES::Namespace \
		#         --html-title=MUES::Namespace \
		#         mues/Namespace.rb
		def generateDocs( srcFile, outputName )
			doPrep unless @prepIsDone
			if $extendedHtml
				system( @generator,
						'-r', "rd/rd2html-ext-lib",
						'--with-css=stylesheets/rd.css', '--html-lang=en',
					    '--ref-extension', '--headline-secno',
					    '--enable-br', '--native-inline', '--head-element',
						"-o%s%s%s" % [ @targetDir, File::Separator, outputName ],
						"--html-title=%s" % outputName,
						srcFile ) or raise StandardError, "Failed rd2html-ext: #{$?}"
			else
				system( @generator,
						'-r', "rd/rd2html-lib",
						'--with-css=stylesheets/rd.css', '--html-lang=en',
						"-o%s%s%s" % [ @targetDir, File::Separator, outputName ],
						"--html-title=%s" % outputName,
						srcFile ) or raise StandardError, "Failed rd2html: #{$?}"
			end
		end
	end

	class ManDelegate
		def initialize( docsDir )
			@docsDir = docsDir
			@targetDir = File.join( docsDir, "man" )
			@generator = findProgram( 'rd2' ) or
				raise RuntimeError, "You don't seem to have the rd2 program"
		end

		def generateDocs( srcFile, outputName )
			File.makedirs( @targetDir )
			system( @generator,
				    "-r", "rd/rd2man-lib",
				    "-o%s%s%s" % [ @targetDir, File::Separator, outputName ],
				    srcFile ) or raise StandardError, "Failed rd2man: #{$?}"
		end
	end

	protected
	def initialize( targetDir="docs", type="html" )
		@targetDir = targetDir
		raise TypeError, "No such documentation type '#{type}'" unless
			Generator.const_defined? "#{type.capitalize}Delegate".intern
		delegateClass = Generator.const_get "#{type.capitalize}Delegate".intern
		@delegate = delegateClass.new( targetDir )
		super( @delegate )
	end
	
end

if $0 == __FILE__
	docsdir = File.dirname( File.expand_path($0) )
	libdir = docsdir.sub( /docs/, "lib" )

	header "Making documenatation in #{docsdir} from files in #{libdir}."

	generators = [
		Generator.new( docsdir, "html" ),
		Generator.new( docsdir, "man" )
	]

	Dir[ "#{libdir}#{File::Separator}*" ].each {|subdir|
		namespace = case subdir
					when /mues/
						'MUES'
					when /tableadapter/
						'TableAdapter'
					when /metaclass/
						'Metaclass'
					else
						subdir.sub( "#{libdir}#{File::Separator}", '' )
					end

		Find.find( subdir ) {|f|
			if FileTest.file?( f ) and f =~ /\.rb$/
				outputName = f.sub( /.*#{File::Separator}/, '' )
				outputName.sub!( /\.rb$/, '' )
				outputName = namespace + "::" + outputName

				for g in generators
					g.generateDocs( f, outputName )
				end
			end
		}
	}
end

