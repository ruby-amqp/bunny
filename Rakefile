task :codegen do
  sh 'ruby ext/codegen.rb > lib/bunny/protocol/spec.rb'
	sh 'ruby lib/bunny/protocol/spec.rb'
end

task :spec do
	require 'spec/rake/spectask'
	Spec::Rake::SpecTask.new do |t|
		t.spec_opts = ['--color']
	end
end