#!/usr/bin/env ruby

require 'logger'

# A collection of mixin modules used throughout MUES.
module MUES

	### A collection of utilities for working with Hashes.
	module HashUtilities

		# Recursive hash-merge function
		HashMergeFunction = Proc.new {|key, oldval, newval|
			#debugMsg "Merging '%s': %s -> %s" %
			#	[ key.inspect, oldval.inspect, newval.inspect ]
			case oldval
			when Hash
				case newval
				when Hash
					#debugMsg "Hash/Hash merge"
					oldval.merge( newval, &HashMergeFunction )
				else
					newval
				end

			when Array
				case newval
				when Array
					#debugMsg "Array/Array union"
					oldval | newval
				else
					newval
				end

			else
				newval
			end
		}

		###############
		module_function
		###############

		### Return a version of the given +hash+ with its keys transformed
		### into Strings from whatever they were before.
		def stringify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s ] = stringify_keys( val )
				else
					newhash[ key.to_s ] = val
				end
			end

			return newhash
		end


		### Return a duplicate of the given +hash+ with its identifier-like keys
		### transformed into symbols from whatever they were before.
		def symbolify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				keysym = key.to_s.dup.untaint.to_sym

				if val.is_a?( Hash )
					newhash[ keysym ] = symbolify_keys( val )
				else
					newhash[ keysym ] = val
				end
			end

			return newhash
		end
		alias_method :internify_keys, :symbolify_keys

	end


	### A collection of utilities for working with Arrays.
	module ArrayUtilities

		###############
		module_function
		###############

		### Return a version of the given +array+ with any Symbols contained in it turned into
		### Strings.
		def stringify_array( array )
			return array.collect do |item|
				case item
				when Symbol
					item.to_s
				when Array
					stringify_array( item )
				else
					item
				end
			end
		end


		### Return a version of the given +array+ with any Strings contained in it turned into
		### Symbols.
		def symbolify_array( array )
			return array.collect do |item|
				case item
				when String
					item.to_sym
				when Array
					symbolify_array( item )
				else
					item
				end
			end
		end

	end


	### A collection of HTML utility functions
	module HTMLUtilities

		###############
		module_function
		###############

		# The name of the Thread-local variable to keep the serialized-object
		# cache in (i.e., Thread[ THREAD_DUMP_KEY ] = {}). The cache is keyed by
		# object_id
		THREAD_DUMP_KEY = :__to_html_cache__

		# The HTML fragment to wrap around Hash objects
		HASH_HTML_CONTAINER = %{<div class="hash-members">%s</div>}

		# The HTML fragment to use for pairs of a Hash
		HASH_PAIR_HTML = %{<div class="hash-pair %s">\n} +
			%{<div class="key">%s</div>\n} +
			%{<div class="value">%s</div>\n} +
			%{</div>\n}

		# The HTML fragment to wrap around Array objects
		ARRAY_HTML_CONTAINER = %{<ol class="array-members"><li>%s</li></ol>}

		# The HTML fragment to wrap around immediate objects
		IMMEDIATE_OBJECT_HTML_CONTAINER = %{<div class="immediate-object">%s</div>}

		# The HTML fragment to wrap around objects other than Arrays and Hashes.
		OBJECT_HTML_CONTAINER = %{<div id="object-%d" class="object %s">%s</div>}

		# The HTML fragment to use for instance variables inside of object DIVs.
		IVAR_HTML_FRAGMENT = %Q{
		  <div class="%s">
			<div class="name">%s</div>
			<div class="value">%s</div>
		  </div>
		}

		### Escape special characters in the given +string+ for display in an
		### HTML inspection interface. This escapes common invisible characters
		### like tabs and carriage-returns in additional to the regular HTML
		### escapes.
		def escape_html( string )
			return "nil" if string.nil?
			string = string.inspect unless string.is_a?( String )
			string.
				gsub(/&/, '&amp;').
				gsub(/</, '&lt;').
				gsub(/>/, '&gt;').
				gsub(/\n/, '&#8629;').
				gsub(/\t/, '&#8594;')
		end


		### Return an HTML fragment describing the specified +object+.
		def make_html_for_object( object )
			return object.html_inspect if 
				object.respond_to?( :html_inspect ) && ! object.is_a?( HtmlInspectableObject )
			object_html = []

			case object
			when Hash
				object_html << "\n<!-- Hash -->\n"
				if object.empty?
					object_html << '{}'
				else
					object_html << HASH_HTML_CONTAINER % [
						object.collect {|k,v|
							pairclass = v.instance_variables.empty? ? 
								"simple-hash-pair" :
								"complex-hash-pair"
							HASH_PAIR_HTML % [
								pairclass,
								make_html_for_object(k),
								make_html_for_object(v),
							  ]
						}
					]
				end

			when Array
				object_html << "\n<!-- Array -->\n"
				if object.empty?
					object_html << '[]'
				else
					object_html << ARRAY_HTML_CONTAINER % [
						object.collect {|o| make_html_for_object(o) }.join('</li><li>')
					]
				end

			else
				if object.instance_variables.empty?
					return IMMEDIATE_OBJECT_HTML_CONTAINER % 
						[ HTMLUtilities.escape_html(object.inspect) ]
				else
					object_html << make_object_html_wrapper( object )
				end
			end

			return object_html.join("\n")
		end


		### Wrap up the various parts of a complex object in an HTML fragment. If the
		### object has already been wrapped, returns a link to the previous rendering
		### instead.
		def make_object_html_wrapper( object )

			# If the object has been rendered already, just return a link to the previous
			# HTML fragment
			Thread.current[ THREAD_DUMP_KEY ] ||= {}
			if Thread.current[ THREAD_DUMP_KEY ].key?( object.object_id )
				return %Q{<a href="#object-%d" class="cache-link" title="jump to previous details">%s</a>} % [
					object.object_id,
					%{&rarr; %s #%d} % [ object.class.name, object.object_id ]
				]
			else
				Thread.current[ THREAD_DUMP_KEY ][ object.object_id ] = true
			end

			# Assemble the innards as an array of parts
			parts = [
				%{<div class="object-header">},
				%{<span class="object-class">#{object.class.name}</span>},
				%{<span class="object-id">##{object.object_id}</span>},
				%{</div>},
				%{<div class="object-body">},
			]

			object.instance_variables.sort.each do |ivar|
				value = object.instance_variable_get( ivar )
				html = make_html_for_object( value )
				classes = %w[instance-variable]
				if value.instance_variables.empty? && !value.respond_to?( :values_at )
					classes << 'simple'
				else
					classes << 'complex'
				end
				parts << IVAR_HTML_FRAGMENT % [ classes.join(' '), ivar, html ]
			end

			parts << %{</div>}

			# Make HTML class names out of the object's namespaces
			namespaces = object.class.name.downcase.split(/::/)
			classes = []
			namespaces.each_index do |i|
				classes << namespaces[0..i].join('-') + '-object'
			end

			# Glue the whole thing together and return it
			return OBJECT_HTML_CONTAINER % [
				object.object_id,
				classes.join(" "),
				parts.join("\n")
			]
		end

	end # module HTMLUtilities


	### Add a #html_inspect method to the including object that is capable of dumping its
	### state as an HTML fragment.
	###
	###   class MyObject
	###       include HtmlInspectableObject
	###   end
	###
	###   irb> MyObject.new.html_inspect
	###      ==> "<span class=\"immediate-object\">#&lt;MyObject:0x56e780&gt;</span>"
	module HtmlInspectableObject
		include MUES::HTMLUtilities

		### Return the receiver as an HTML fragment.
		def html_inspect
			if self.instance_variables.empty?
				return make_html_for_object( self )
			else
				return make_object_html_wrapper( self )
			end
		end

	end # HtmlInspectableObject


	# A mixin that adds a #log method to including classes that calls
	# MUES::Logger with the class of the receiving object.
	#
	# == Usage
	# 
	#	require "mues/mixins"
	#
	#	class MyClass
	#	  include MUES::Loggable
	#	  
	#	  def some_method
	#	    self.log.debug "A debugging message"
	#	  end
	#	end
	# 
	### Add logging to a MUES class. Including classes get #log and #log_debug methods.
	module Loggable

		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		  }

		### A logging proxy class that wraps calls to the logger into calls that include
		### the name of the calling class.
		class ClassNameProxy # :nodoc:

			### Create a new proxy for the given +klass+.
			def initialize( klass, force_debug=false )
				@classname   = klass.name
				@force_debug = force_debug
			end

			### Delegate calls the global logger with the class name as the 'progname' 
			### argument.
			def method_missing( sym, msg=nil, &block )
				return super unless LEVEL.key?( sym )
				sym = :debug if @force_debug
				MUES.logger.add( LEVEL[sym], msg, @classname, &block )
			end
		end # ClassNameProxy

		#########
		protected
		#########

		### Copy constructor -- clear the original's log proxy.
		def initialize_copy( original )
			@log_proxy = @log_debug_proxy = nil
			super
		end

		### Return the proxied logger.
		def log
			@log_proxy ||= ClassNameProxy.new( self.class )
		end

		### Return a proxied "debug" logger that ignores other level specification.
		def log_debug
			@log_debug_proxy ||= ClassNameProxy.new( self.class, true )
		end

	end # module Loggable


	### A collection of ANSI color utility functions
	module ANSIColorUtilities

		# Set some ANSI escape code constants (Shamelessly stolen from Perl's
		# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
		ANSI_ATTRIBUTES = {
			'clear'      => 0,
			'reset'      => 0,
			'bold'       => 1,
			'dark'       => 2,
			'underline'  => 4,
			'underscore' => 4,
			'blink'      => 5,
			'reverse'    => 7,
			'concealed'  => 8,

			'black'      => 30,   'on_black'   => 40,
			'red'        => 31,   'on_red'     => 41,
			'green'      => 32,   'on_green'   => 42,
			'yellow'     => 33,   'on_yellow'  => 43,
			'blue'       => 34,   'on_blue'    => 44,
			'magenta'    => 35,   'on_magenta' => 45,
			'cyan'       => 36,   'on_cyan'    => 46,
			'white'      => 37,   'on_white'   => 47
		}

		###############
		module_function
		###############

		### Create a string that contains the ANSI codes specified and return it
		def ansi_code( *attributes )
			attributes.flatten!
			attributes.collect! {|at| at.to_s }
			return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
			attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

			if attributes.empty?
				return ''
			else
				return "\e[%sm" % attributes
			end
		end


		### Colorize the given +string+ with the specified +attributes+ and return it, handling 
		### line-endings, color reset, etc.
		def colorize( *args )
			string = ''

			if block_given?
				string = yield
			else
				string = args.shift
			end

			ending = string[/(\s)$/] || ''
			string = string.rstrip

			return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
		end

	end # module ANSIColorUtilities

end # module MUES


