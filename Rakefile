task :default => [:genrdoc]

task :genrdoc do
  sh %{rm -R doc}
  sh %{rdoc --inline-source --main init.rb}
end