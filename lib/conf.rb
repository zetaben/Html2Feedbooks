
module HTML2FB
	class Conf
		def initialize(file)
			['','./',"#{File.dirname(__FILE__)}/","#{File.dirname(__FILE__)}/../confs/"].each do |p|
				f=p+file
				begin
					if File.readable?(f) && File.exists?(f)
						@conf=File.open(f,'r'){|txt| YAML::load(txt)}
						return 
					end
				rescue Exception => e 
					STDERR.puts('unreadable conf : '+f+"\n"+e)
				end
			end
		end

		def [](x)
			@conf[x]
		end
	end
end
