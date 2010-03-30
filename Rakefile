require 'rake/gempackagetask'
gemspec = eval(File.read('Html2Feedbooks.gemspec'))

Rake::GemPackageTask.new(gemspec) do |p|
	p.gem_spec = gemspec
	p.need_tar = false
	p.need_zip = false
end
