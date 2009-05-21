require 'hpricot'
require 'document.rb'

module HTML2FB
	class Parser

		def initialize(conf)
			@conf=conf
		end

		def extract_text(n)
			t=''
			n.traverse_all_element do |e|
				t+=e.content.to_s if e.is_a?(Hpricot::Text)
			end
			t
		end

		def parse(txt)
			puts "Parsing HTML"
			pdoc=Hpricot(txt)
			doc=Document.new
			puts "Removing garbage elements"
			remove_objs(pdoc)
			ti=pdoc.at('title')
			doc.title= extract_text(ti).strip unless ti.nil?
			#			pdoc.search('//h3').each do |e|
			#				doc.content.push(e.inner_text)
			#			end

			puts "Building TOC"
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
					if x
					x.preceding.remove
					x.parent.children.delete(x)
					end
				end unless @conf['remove']['before'].nil?
				@conf['remove']['between'].each do |cl|
#					puts "between "+cl.inspect
					doc.between(cl.first,cl.last).remove
				end unless @conf['remove']['between'].nil?
				@conf['remove']['after'].each do |cl|
					x=doc.at(cl)
					if x
					x.following.remove
					x.parent.children.delete(x)
					end
				end unless @conf['remove']['after'].nil?
			end
#			File.open('/tmp/test.html','w'){|f| f.write doc.to_html}
		end

		def parse_text(doc,ret)
			ti  = doc.search('//'+@conf['select']['expr'])
			tit = ti.zip ti[1..-1]+[nil]

			tit.each do |a|
				s=Section.new
				tmp=doc.between(a.first.xpath,a.last.nil? ? nil : a.last.xpath).to_html
				tmp.sub!(a.first.to_original_html,'')
				s.content =[Text.new(tmp)]
				#buggy with entities
				s.title = extract_text(a.first)
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
							s.title = extract_text(a.first)
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
		unless j.nil? || self.at(j).nil?
			prec=self.at(i).deep_preceding
			Hpricot::Elements[*self.at(j).deep_preceding.find_all{|el| !prec.include?el}]
		else
			self.at(i).deep_following unless self.at(i).nil?
		end
	end

	def deep_preceding()
	ret=Hpricot::Elements[]
	ret+=parent.deep_preceding if respond_to?(:parent) && !parent.is_a?(Hpricot::Doc )
	ret+=preceding
	Hpricot::Elements[*ret]
	end
	def deep_following()
	ret=following
	ret+=parent.deep_following if respond_to?(:parent) && !parent.is_a?(Hpricot::Doc )
	Hpricot::Elements[*ret]
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
