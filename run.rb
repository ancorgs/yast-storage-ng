files = Dir["**/test/**/*_{spec,test}.rb"]
exec("rspec '#{files.join("' '")}'") unless files.empty?
