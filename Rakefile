task :codegen do
  sh 'ruby protocol/codegen.rb > lib/amqp/spec.rb'
	sh 'ruby lib/amqp/spec.rb'
end

task :spec do
	require 'spec/rake/spectask'
	Spec::Rake::SpecTask.new do |t|
		t.spec_opts = ['--color']
	end
end
	