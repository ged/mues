#!/usr/bin/ruby
#
# A tester script for questionnaires.
#
# == Synopsis
#
#   $ runQuestionnaire.rb <questionnaire-name>
#
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

BEGIN {
	basedir = File::expand_path(__FILE__)
	3.times do
		basedir = File::dirname( basedir )
	end

	if Dir::getwd != basedir
		Dir::chdir( basedir )
	end

	require "#{basedir}/utils.rb"
	include UtilityFunctions

	$LOAD_PATH.unshift "#{basedir}/lib", "#{basedir}/ext"
}
	
require 'io/reactor'
require 'mues/ioeventstream'
require 'mues/ioeventfilters'
require 'mues/reactorproxy'

header "Questionnaire Runner ($Revision$)"
qname = ARGV.shift or abort( "Usage: #$0 <questionnaire>" )

ios = MUES::IOEventStream::new
reactor = IO::Reactor::new
rp = MUES::ReactorProxy::new( reactor, $stdin )
cf = MUES::ConsoleOutputFilter::new( rp, nil )

qn = MUES::Questionnaire::load( qname ) {|qnaire|
	$stderr.puts "Questionnaire finished, answers are:\n" +
		qnaire.answers.inspect
}

begin
	ios << cf << qn
	until qn.finished? || reactor.empty?
		reactor.poll( 0.5 )
	end
ensure
	rp.unregister
	ios.shutdown
end


