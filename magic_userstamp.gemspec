
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "userstamp"
  s.version     = "0.1.1"
  s.authors     = ["k2o"]
  s.email       = ["isonos@gmail.com"]
  s.homepage    = "https://github.com/k2o/magic_userstamp"
  s.summary     = "Add audting to your ActiveRecord models"
  s.description = %q{This Rails plugin extends ActiveRecord::Base to add automatic updating of created_by and updated_by attributes of your models in much the same way that the ActiveRecord::Timestamp module updates created_(at/on) and updated_(at/on) attributes.}

  s.rubyforge_project = "userstamp"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
