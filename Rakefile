require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "objectpool"
    gem.summary = %Q{Magical thread pool implementation}
    gem.description = %Q{Little bit different and magical implementation of thread pool pattern in ruby.}
    gem.email = "kriss.kowalik@gmail.com"
    gem.homepage = "http://github.com/kriss/objectpool"
    gem.authors = ["Kriss Kowalik"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "yard", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    version   = File.exist?('VERSION') ? File.read('VERSION') : ""
    title     = "Leech #{version}"
    t.files   = ['lib/**/*.rb', 'README*']
    t.options = ['--title', title, '--markup', 'markdown']
  end
rescue LoadError
  task :yard do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end

desc "Benchmarking reports"
task :benchmark do 
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
  require 'rubygems'
  require 'objectpool'
  require 'benchmark'
  
  class BenchObject
    pool_methods :test
    
    def test(arg)
      sleep 0.01
    end
  end
  
  p5 = BenchObject.to_pool(5)
  p10 = BenchObject.to_pool(10)
  p20 = BenchObject.to_pool(20)
  p35 = BenchObject.to_pool(35)
  
  op5, op10, op20, op35 = nil, nil, nil, nil
  
  puts "-- Preparation time -------------------------------------"
  Benchmark.bm(7) do |x|
    x.report("5 workers ") { op5  = p5.new  }
    x.report("10 workers") { op10 = p10.new }
    x.report("20 workers") { op20 = p20.new }
    x.report("35 workers") { op35 = p35.new }
  end
  
  n = 5000
  
  puts "-- Execution time (5000 calls) --------------------------"
  Benchmark.bm(7) do |x|
    x.report("5 workers ") { n.times {|n| op5.test(n).async  };}
    x.report("10 workers") { n.times {|n| op10.test(n).async };}
    x.report("20 workers") { n.times {|n| op20.test(n).async };}
    x.report("35 workers") { n.times {|n| op35.test(n).async };}
  end
  n = 50000
end 
