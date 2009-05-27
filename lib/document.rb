module HTML2FB

	class Section
		attr_accessor :title
		attr_accessor :content
		attr_accessor :fblevel

		def initialize
			@content=[]
		end

		def to_html
			content.collect{|e|e.to_html}.join
		end

		def decorated_title
			unless fblevel.nil?
				"[#{fblevel}] "+title
			else
				title
			end
		end

		def titles
			tit=[]
			content.each do |f|
				if f.is_a?Section
					tit.push f.decorated_title
				else
					tit.push '#text'
				end
			end

			return [decorated_title,tit]
		end

		def to_s
			return "title :#{title}  \n"+content.collect{|a|a.to_s}.join("\n\n")
		end
	end

	class Document < Section
		def toc
			#return content
			return content.collect{|a|a.titles}
		end

	end

	class Text
		attr_accessor :content

		def initialize(c='')
			@content=c
		end

		def to_html
			@content
		end

		def to_s
			@content
		end
	end
end
