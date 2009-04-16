require 'hpricot'
require 'lib/document.rb'

module HTML2FB
	class Parser

		def initialize
			@conf=File.open('lib/conf.yaml'){|f| YAML::load(f)}
		end

		def parse(txt)
			pdoc=Hpricot(txt)
			doc=Document.new
			remove_objs(pdoc)
			ti=pdoc.at('title')
			doc.title= ti.inner_text.strip unless ti.nil?
			pdoc.search('//h3').each do |e|
				doc.content.push(e.inner_text)
			end
			return doc
		end
	protected

	def remove_objs(doc)
		if @conf['remove'] then
			@conf['remove']['class'].each do |cl|
				doc.search('.'+cl).remove
			end unless @conf['remove']['class'].nil?
			@conf['remove']['expr'].each do |cl|
				doc.search(cl).remove
			end unless @conf['remove']['expr'].nil?
			@conf['remove']['before'].each do |cl|
				x=doc.at(cl)
				x.preceding.remove
				x.parent.children.delete(x)
			end unless @conf['remove']['before'].nil?
			@conf['remove']['between'].each do |cl|
				puts "between "+cl.inspect
				doc.between(cl.first,cl.last).remove
			end unless @conf['remove']['between'].nil?
			@conf['remove']['after'].each do |cl|
				x=doc.at(cl)
				x.following.remove
				x.parent.children.delete(x)
			end unless @conf['remove']['after'].nil?
		end
		File.open('/tmp/test.html','w'){|f| f.write doc.to_html}
	end

	end

end


class String
	def blank?
		self==""
	end
end

class NilClass
	def blank?
		true
	end
end

module Hpricot::Traverse
	def between(i,j)
=begin		to=self.at(j).xpath
		from=self.at(i).xpath
		nodes=Hpricot::Elements[]
		puts to
		puts from
		puts 
		ok=false
		self.at('/html').traverse_element do |el|
			break if el.xpath == to
			nodes << el if ok
			puts el.xpath if ok
			ok=true if el.xpath==from
		end
		nodes
=end
		prec=self.at(i).preceding
		Hpricot::Elements[*self.at(j).preceding.find_all{|el| !prec.include?el}]
	end
end
