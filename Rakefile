task :codegen do
  sh 'ruby protocol/codegen.rb > lib/engineroom/spec.rb'
	sh 'ruby lib/engineroom/spec.rb'
end

task :spec do
	require 'spec/rake/spectask'
	Spec::Rake::SpecTask.new do |t|
		t.spec_opts = ['--color']
	end
end