require 'open-uri'
require 'tempfile'

module HTML2FB
	class Downloader
		def self.valid_url?(entry)
			uri=URI.parse(entry)
			Kernel.open(uri.to_s,'r')
			return uri
		end

		def self.download(uri)
			print "Downloading   "
			puts uri.to_s
			#tmp=Tempfile.new(uri.gsub(/[^a-z0-9]/,'_'))
			#tmp.open('w'){|a|
			#	uri.open('r'){|b|
			#		a.write b
			#	}
			#}
			Kernel.open(uri.to_s,'r').read
		end
	end
end
