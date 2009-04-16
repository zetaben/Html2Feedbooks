module HTML2FB
	class Document
	attr_accessor :title
	attr_accessor :content

	def initialize
		@content=[]
	end

	def toc
		return content
	end

	end
end

