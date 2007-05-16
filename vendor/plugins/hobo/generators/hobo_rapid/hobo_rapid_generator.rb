require 'find'

class HoboRapidGenerator < Hobo::Generator

  default_options :import_tags => false

  def manifest
    if options[:command] == :create
      import_tags if options[:import_tags]
    end
    
    record do |m|
      m.file "hobo_rapid.js", "public/javascripts/hobo_rapid.js"
      m.file "themes/default/default_mapping.rb", "app/views/hobolib/default_mapping.rb"
      create_all(m, "themes/default/public", "public/hobothemes/default")
      create_all(m, "themes/default/views", "app/views/hobolib/themes/default")
    end
  end
  
  def import_tags
    path = File.join(RAILS_ROOT, "app/views/hobolib/application.dryml")

    tag = "<taglib src=\"plugins/hobo/tags/rapid\"/>\n\n<set_theme name=\"default\"/>\n"
      
    src = File.read(path)
    return if src.include?(tag)

    # first try putting it before the first tag
    done = src.sub!(/<(?!!)/, tag + "\n<")
    
    # otherwise append it
    src << tag unless done
    
    File.open(path, 'w') {|f| f.write(src) }
  end


  protected
    def banner
      "Usage: #{$0} generate [--import-tags]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--import-tags",
             "Modify hobolib/application.dryml to import hobo-rapid and theme tags ") do |v|
        options[:import_tags] = true
      end
    end
end
