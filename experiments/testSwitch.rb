#!/usr/bin/ruby


class OtherClass < Object; end

class OriginalClass < Object

	def switch
		self = OtherClass.new
	end

end



