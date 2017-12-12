require 'rubygems'
require 'rake'
require './lib/rfm'

task :default => :spec

#require 'spec/rake/spectask'
#require 'rspec'
require 'rspec/core/rake_task'

# Manual
# desc "Manually run rspec 2 - works but ugly"
# task :spec do
#   puts exec("rspec -O spec/spec.opts") #RUBYOPTS=W0  # silence ruby warnings.
# end

RSpec::Core::RakeTask.new(:spec) do |task|
  # Optionally pass env var SPEC_OPTS='--whatever' to pass opts to rspec thru rake.
  task.rspec_opts = '-O spec/spec.opts'
end

desc "run specs with all parser backends"
task :spec_multi do
  require 'benchmark'
  require 'yaml'
  Benchmark.bm do |b|
    [:ox, :libxml, :nokogiri, :rexml].each do |parser|
      ENV['parser'] = parser.to_s
      b.report("RSPEC with #{parser.to_s.upcase}\n") do
        begin
          Rake::Task["spec"].execute
        rescue Exception
          puts "ERROR in rspec with #{parser.to_s.upcase}: #{$!}"
        end
      end
    end
  end
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = Rfm::VERSION
  rdoc.main = 'README.md'
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Rfm #{version}"
  rdoc.rdoc_files.include('lib/**/*.rb', 'README.md', 'CHANGELOG.md', 'VERSION', 'LICENSE')
end

require 'yard'
require 'rdoc'
YARD::Rake::YardocTask.new do |t|
  # See http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
  # See 'yardoc --help'
  t.files   = ['lib/**/*.rb', 'README.md', 'LICENSE', 'VERSION', 'CHANGELOG.md']   # optional
  t.options = ['-oydoc', '--no-cache', '-mrdoc', '--no-private'] # optional
end

desc "Print the version of Rfm"
task :version do
  puts Rfm::VERSION
end

desc "Print info about Rfm"
task :info do
  puts Rfm.info
end

desc "Benchmark loading & parsing XML data into Rfm classes"
task :benchmark do
  require 'benchmark'
  require 'yaml'
  #load "spec/data/sax_models.rb"
  @records = File.read 'spec/data/resultset_large.xml'
  #@template = 'lib/rfm/utilities/sax/fmresultset.yml'
  @template = 'fmresultset.yml'
  @base_class = Rfm::Resultset
  @layout = 'spec/data/layout.xml'
  Benchmark.bm do |b|
    [:rexml, :nokogiri, :libxml, :ox].each do |backend|
      b.report("#{backend}\n") do
        5.times do
          Rfm::SaxParser.parse(@records, @template, @base_class.new, backend)
        end
      end
    end
  end
end

desc "Profile the sax parser"
task :profile_sax do
  # This turns on tail-call-optimization. Was needed in past for ruby 1.9, maybe not now.
  # See http://ephoz.posterous.com/ruby-and-recursion-whats-up-in-19
  #   if RUBY_VERSION[/1.9/]
  #     RubyVM::InstructionSequence.compile_option = {
  #       :tailcall_optimization => true,
  #       :trace_instruction => false
  #     }
  #   end
  require 'ruby-prof'
  # Profile the code
  @data = 'spec/data/resultset_large.xml'
  min = ENV['min']
  min_percent= min ? min.to_i : 1
  result = RubyProf.profile do
    # The parser will choose the best available backend.
    @rr = Rfm::SaxParser.parse(@data, 'fmresultset.yml', Rfm::Resultset.new).result
    #Rfm::SaxParser.parse(@data, 'lib/rfm/utilities/sax/fmresultset.yml', Rfm::Resultset.new)
  end

  # Print a flat profile to text
  flat_printer = RubyProf::FlatPrinter.new(result)
  flat_printer.print(STDOUT, {:min_percent=>0})
  # Print a graph profile to text. See https://github.com/ruby-prof/ruby-prof/blob/master/examples/graph.txt
  graph_printer = RubyProf::GraphPrinter.new(result)
  graph_printer.print(STDOUT, {:min_percent=>min_percent})
  graph_html_printer = RubyProf::GraphHtmlPrinter.new(result)
  File.open('ruby-prof-graph.html', 'w') do |f|
    graph_html_printer.print(f, {:min_percent=>min_percent})
  end
  # Print call_tree to html
  tree_printer = RubyProf::CallStackPrinter.new(result)
  File.open('ruby-prof-stack.html', 'w') do |f|
    tree_printer.print(f, {:min_percent=>min_percent})
  end
  
  puts @rr.class
  puts @rr.size
  puts @rr[5].to_yaml
end

desc "Run test data thru the sax parser"
task :sample do
  @records = 'spec/data/resultset_large.xml'
  r= Rfm::SaxParser.parse(@records, 'lib/rfm/utilities/sax/fmresultset.yml', Rfm::Resultset.new).result
  puts r.to_yaml
  puts r.field_meta.to_yaml
end  

desc "pre-commit, build gem, tag with version, push to git, push to rubygems.org"
task :release do
  gem_name = 'ginjo-rfm'
  shell = <<-EEOOFF
    current_branch=`git rev-parse --abbrev-ref HEAD`
    if [ $current_branch != 'master' ]; then
      echo "Aborting: You are not on the master branch."
      exit 1
    fi
    echo "--- Pre-committing ---"
      git add .; git commit -m'Releasing version #{Rfm::VERSION}'
    echo "--- Building gem ---" &&
      mkdir -p pkg &&
      output=`gem build #{gem_name}.gemspec` &&
      gemfile=`echo "$output" | awk '{ field = $NF }; END{ print field }'` &&
      echo $gemfile &&
      mv -f $gemfile pkg/ &&
    echo "--- Tagging with git ---" &&
      git tag -m'Releasing version #{Rfm::VERSION}' v#{Rfm::VERSION} &&
    echo "--- Pushing to git origin ---" &&
      git push origin master &&
      git push origin --tags &&
    echo "--- Pushing to rubygems.org ---" &&
      gem push pkg/$gemfile
  EEOOFF
  puts "-----  Shell script to release gem  -----"
  puts shell
  puts "-----  End shell script  -----"
  print exec(shell)
end


