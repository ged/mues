#!/usr/bin/ruby
###########################################################################
=begin

=Association.rb

== Name

Association - An association metaclass

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################


module MetaClass

	class Association < Object

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: association.rb,v 1.2 2001/05/14 12:36:59 deveiant Exp $


	end

end
