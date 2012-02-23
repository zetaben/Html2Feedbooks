require 'nokogiri'
require 'Html2Feedbooks/document'
require 'progressbar'
#require 'ruby-prof'
#require 'term/ansicolor'
#include Term::ANSIColor

module HTML2FB
	class Parser

		def initialize(conf)
			@conf=conf
		end

		def parse(txt)
			puts "Parsing HTML"
			pdoc=Nokogiri::HTML(txt)
			if @conf['conv']
				mc=pdoc/'meta[@http-equiv="Content-Type"]'
				if mc.size>0
					charset=mc.first.attributes['content'].to_s.split(';').find do |s|
						s.strip[0,7]=='charset'
					end
					unless charset.nil?
						tc=charset.split('=').last.strip
					end

					unless tc.nil? 
						puts "Trying to convert source encoding from #{tc} to utf-8"
						require 'iconv'
						pdoc=Nokogiri::HTML(Iconv.conv('utf-8',tc.downcase,txt))

					end

				end
			end
			doc=Document.new
			puts "Removing garbage elements"
			remove_objs(pdoc)
			ti=pdoc.at('title')
			doc.title= ti.text.strip unless ti.nil?
			#			pdoc.search('//h3').each do |e|
			#				doc.content.push(e.inner_text)
			#			end

			puts "Building TOC"
			parse_text(pdoc,doc)	

			#			puts green(bold(doc.pretty_inspect))

			return doc
		end
		protected

		def remove_objs(doc)
			if @conf['remove'] then
				@conf['remove']['class'].each do |cl|
					doc.search('.'+cl).remove
				end unless @conf['remove']['class'].nil?
				@conf['remove']['expr'].each do |cl|
					doc.search(cl).remove rescue doc.xpath(cl).remove
				end unless @conf['remove']['expr'].nil?
				@conf['remove']['before'].each do |cl|
					x=doc.at(cl) rescue doc.at_xpath(cl)
					if x
						x.preceding.remove
						x.parent.children.delete(x)
					end
				end unless @conf['remove']['before'].nil?
				@conf['remove']['between'].each do |cl|
					#					puts "between "+cl.inspect
					t=doc.between(cl.first,cl.last)
					t.remove unless t.nil?
				end unless @conf['remove']['between'].nil?
				@conf['remove']['after'].each do |cl|
					x=doc.at(cl) rescue doc.at_xpath(cl)
					if x
						x.following.remove
						x.parent.children.delete(x)
					end
				end unless @conf['remove']['after'].nil?
			end
			#			File.open('/tmp/test.html','w'){|f| f.write doc.to_html}
		end

		def parse_text(doc,ret)
			#			RubyProf.start


			aut=build_autom(@conf['select'],ret)

			pbar = ProgressBar.new("Parsing", doc.search('//*').size)
			doc.traverse do |el|
				aut.feed(el)
				pbar.inc
			end
			aut.finish(doc)
			pbar.finish
=begin
			 result = RubyProf.stop
			  printer = RubyProf::FlatPrinter.new(result)
			  printer.print(STDOUT, 0)
			  printer.print(File.new('/versatile/prof','w'),0)
			    printer = RubyProf::GraphHtmlPrinter.new(result)
			      printer.print(File.new('/versatile/profgraph.html','w'), :min_percent=>0)
			    printer = RubyProf::CallTreePrinter.new(result)
			      printer.print(File.new('/versatile/profgraph.tree','w'), :min_percent=>0)
=end
		end

		protected

		def build_autom(conf_tab,doc)
			mach=StateMachine.new
			build_rec(mach,conf_tab)
			mach.reset(doc)
			mach
		end

		def build_rec(mach,conf_tab)
			return if conf_tab.size < 1
			exprs=conf_tab.collect{|e| e.reject{|k,v| k=='select'} }
			mach.add_level(exprs)
			build_rec(mach,conf_tab.collect{|e| e['select'] }.flatten.reject{|a|a.nil?})
		end
	end

	class StateMachine

		def initialize
			@levels=[]
			@current_level=0
			@starts=[]
			@done=[]
			@max_level=0
			@content=nil
		end

		def add_level(tab)
			tab=[tab] unless tab.is_a?Array
			@levels.push tab
			@current_level+=1
		end

		def reset(doc)
			@current_level=0
			@max_level=@levels.size
			@starts[0]=doc
			@content='body'
		end

		def inspect
			@levels.inspect+"\n"+@current_level.to_s+"\n\n"+@done.inspect
		end

		def create_fbsection(title,fblevel)
			s=Section.new
			s.fblevel=fblevel
			s.title = title
			s
		end

		def create_textNode(txt)
			Text.new(txt)
		end

		def finish(doc)
			unless @content.nil?
				#	t=create_textNode(doc.root.search(@content...doc.children.last.xpath))
				t=create_textNode(doc.at(@content).following.to_html)
				@starts[@current_level].content.push(t)
			end
			(1..@max_level).to_a.reverse.each do |l|
				close_section(l)
			end
			@starts[0]
		end

		def open_section(obj,lvl,el)
			if @content=='body'
				tmp=el.preceding[0..-1]
			else
				tmp=el.root.between(@content,(el.path),true)[1..-1]
			end
			if tmp.blank? #search can'find between siblins
				tmp=el.root.deep_between(@content,(el.path))
			end
			unless tmp.blank?
				tmph=tmp.to_html
				unless tmph.blank?
					t=create_textNode(tmph)
					@starts[@current_level].content.push(t)
				end
			end
			(lvl..@max_level).to_a.reverse.each do |l|
				close_section(l)
			end
			@starts[lvl]=create_fbsection(el.root.at_xpath(obj[:xpath]).text,obj[:fblevel])
			@content=obj[:xpath]
			@current_level=lvl
		end

		def close_section(lvl)
			return if @starts[lvl].nil?
			llvl=lvl-1
			llvl=llvl-1 until !@starts[llvl].nil?
			@starts[llvl].content.push @starts[lvl]
			@starts[lvl]=nil
		end

		def feed(el)
			return if el.text?
			@done=[[]*@levels.size]

			@levels.each_with_index do  |lvl,i|
				lvl.each do |expr|
					#puts i.to_s+" "+el.inspect if el.in_search?(expr['expr'])
					if el.in_search?(expr['expr'])


						open_section({:xpath => el.path, :fblevel => expr['fblevel']},i+1,el)
						break
					end
				end
			end

		end
	end
end

class  Nokogiri::XML::NodeSet
	alias :blank? :empty?
end

class String
	def blank?
		self !~ /\S/
	end
end

class NilClass
	def blank?
		true
	end
end



class Nokogiri::XML::Node

	def in_search?(expr)
		if expr !~ /[^a-z0-9]/
			return self.name.downcase()==expr.downcase()	
		end

		se_in=self.root
		se_in=self.parent if self.respond_to?(:parent)
		if expr[0..1]=='/'
			se_in=self.root
		end
		set=se_in.search(expr) rescue se_in.xpath(expr)
		set.each do |el|
			return true if el==self
		end
		#		puts self.name+" "+expr
		return false
	end

	def root
		self.document.root
	end

	def node_position
		return @node_position if @node_position
		@node_position=parent.children.index(self)
	end

	def between(a,b,excl=false)

		#from nokogiri
		offset=(excl ? -1 : 0)
		ary = []
		ele1=at(a) rescue at_xpath(a)
		ele2=at(b) rescue at_xpath(b)
		
		if ele1 and ele2
			# let's quickly take care of siblings
			if ele1.parent == ele2.parent
				
				ary = ele1.parent.children[ele1.node_position..(ele2.node_position+offset)]
			else
				# find common parent
				ele1_p=ele1.ancestors
				ele2_p=ele2.ancestors
				common_parent = ele1_p.zip(ele2_p).select { |p1, p2| p1 == p2 }.flatten.first

				child = nil
				if ele1 == common_parent
					child = ele2
				elsif ele2 == common_parent
					child = ele1
				end

				if child
					ary = common_parent.children[0..(child.node_position+offset)]
				end
			end
		end

		return Nokogiri::XML::NodeSet.new(ele1.document,ary)
	end



	def deep_between(i,j)
		unless j.nil? || self.at_xpath(j).nil?
			tm=self.at_xpath(i)
			prec=tm.deep_preceding
			r=Nokogiri::XML::NodeSet.new(tm.document,[*self.at(j).deep_preceding.find_all{|el| !(prec.include?el || el==tm)}])
		else
			r=self.at(i).deep_following unless self.at(i).nil?
		end
		Nokogiri::XML::NodeSet.new(self.document,[*select_end(r,i)])
	end

	def select_end(tab,expr)

		s=[]
		f=false
		idx=-1
		i=0
		tab.each do |e|
			nxp=expr.gsub(e.path,'.')
			set=e.search(nxp) rescue e.xpath(nxp)
			if set.size > 0
				idx=i
				#if e.search(i).size > 0
				if e.children.find{|ee| ee.path==expr }
					e.children.each do |ee|
						s << ee if f
						f=true if ee.path==expr
					end
				else
					s=select_end(e.children,expr)
				end
				break
			else
				i+=1
			end
			break if idx>0
		end
		return s+tab[(idx+1)..-1]
	end

	def preceding
		self.parent.children[0...node_position]
	end
	
	def following
		self.parent.children[node_position+1..-1]
	end

	def deep_preceding()
		ret=Nokogiri::XML::NodeSet.new(self.document,[])
		ret+=parent.deep_preceding if respond_to?(:parent)  && !parent.is_a?(Nokogiri::XML::Document)
		ret+=preceding
		ret
	end
	def deep_following()
		ret=following
		ret+=parent.deep_following if respond_to?(:parent)  && !parent.is_a?(Nokogiri::XML::Document)
		ret
	end

end
