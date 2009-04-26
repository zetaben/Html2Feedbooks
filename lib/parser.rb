require 'hpricot'
require 'lib/document.rb'

module HTML2FB
	class Parser

		def initialize(conf)
			@conf=conf
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

			parse_text(pdoc,doc)	

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
#					puts "between "+cl.inspect
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

		def parse_text(doc,ret)
			ti  = doc.search('//'+@conf['select']['expr'])
			tit = ti.zip ti[1..-1]+[nil]

			tit.each do |a|
				s=Section.new
				tmp=doc.between(a.first.xpath,a.last.nil? ? nil : a.last.xpath).to_html
				tmp.sub!(a.first.to_original_html,'')
				s.content =[Text.new(tmp)]
				s.title = a.first.inner_text.to_s
				ret.content.push s
				
			end

			if @conf['select']['select']
				conf=@conf['select']
				parse_rec(ret,conf)
			end
		end

		protected

		def parse_rec(el,conf) 
			return if conf.nil?
			if el.is_a?Section
				el.content.each do |l|
					if l.is_a?Section
						parse_rec(l,conf['select'])
					else
						doc=Hpricot(l.content)
						ti  = doc.search('//'+conf['expr'])
						return if ti.size ==0
						tit = ti.zip ti[1..-1]+[nil]

						tit.each do |a|
							s=Section.new
							tmp=doc.between(a.first.xpath,a.last.nil? ? nil : a.last.xpath).to_html
							s.content = [Text.new(tmp)]
							s.title = a.first.inner_text.to_s
							el.content.push s
							l.content.sub!(tmp,'')
							l.content.sub!(a.first.to_original_html,'')
						end

					end
				end
			end
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
