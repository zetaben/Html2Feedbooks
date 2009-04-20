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
			#			pdoc.search('//h3').each do |e|
			#				doc.content.push(e.inner_text)
			#			end

			doc.content=parse_text(pdoc.search('/html/body//'),pdoc,@conf)	

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

		def parse_text(doc,root,conf=@conf)
			return [doc,nil] if conf['select'].nil?
			ret=[]
			#puts conf['select'].inspect
			points=root.search('//'+conf['select']['expr'])
			#puts points.inspect
			if points.size > 0 
				p2=points.zip(points[1..-1]+[nil])
				p2.each do |d,e|
			#		puts d,e
					el=root.between(d.xpath,(e ? e.xpath : nil) ) 
					uu=doc-el
			#		puts el
					u,p = parse_text(el,root,conf['select'])
					ret.push([uu+u,[p]])
				end	
			end
			ret
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
		#puts i,j
		unless j.nil?
			prec=self.at(i).preceding
			Hpricot::Elements[*self.at(j).preceding.find_all{|el| !prec.include?el}]
		else
			self.at(i).following
		end
	end
end


class Hpricot::Elements
	def between(i,j)
		Hpricot::Elements[*self.collect{|a| a.between(i,j)}]
	end

	def -(a)
		Hpricot::Elements[*self.find_all{|el| !a.include?el}]
	end
end
