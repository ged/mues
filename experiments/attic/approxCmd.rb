#!/usr/bin/ruby

require "Soundex"
include Text::Soundex

$soundexTable = {}
$commandTable = {}
commands = %w{go walk look listen say eval logout login find try taste dig jump run walk go take}

commands.each {|str|
	sval = soundex( str )
	$soundexTable[sval] ||= []
	$soundexTable[sval] << str
	$commandTable[str] = 1
}

def lookup( str )
	if $commandTable.has_key?( str )
		puts "Running command '#{str}'."
		return
	end

	sval = soundex(str)
	cmdlist = []
	if $soundexTable.has_key?( sval )
		cmdlist = $soundexTable[sval]
	else
		( sval.length - 1 .. 1 ).each {|l|
			approx = $soundexTable.keys.find {|s| s[0,l] == sval[0,l]}
			if not approx.nil?
				cmdlist = $soundexTable[approx]
				break
			end
		}
	end

	unless cmdlist.empty?
		puts "No such command '#{str}'. Possible candidates are: #{cmdlist.join(', ')}"
	else
		puts "No such command '#{str}'."
	end
end

$stdin.each {|input|
	lookup( input.chomp )
}

