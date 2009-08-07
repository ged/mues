#!/usr/bin/ruby -w

File::readlines( __FILE__ ).each {|line| if (line =~ /^__END__/) ... (line =~ /^__END_DATA__/) then puts line end }

__END__

It worked.

__END_DATA__

This is some stuff that shouldn't print.

