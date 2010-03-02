#!/usr/bin/env ruby

require 'mues/engine'

# Cucumber step definitions for MUES::Engine objects.

Given /^a running server$/ do
	@engine = MUES::Engine.new
	@engine_thread = Thread.new { @engine.start }
end

When /^provides a valid character name$/ do
	pending # express the regexp above with the code you wish you had
end

When /^provides a valid password$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^she is given a success message$/ do
	pending # express the regexp above with the code you wish you had
end
