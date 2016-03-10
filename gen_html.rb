require 'haml'
require 'yaml'
require_relative 'graph_generator'
require 'fileutils'

class HTMLGenerator
  FOLDER = "templates"
  FOOTER = File.read "#{FOLDER}/footer.html.haml"
  BODY = File.read "#{FOLDER}/body.html.haml"
  LAYOUT = File.read "#{FOLDER}/layout.html.haml"
  HEAD = File.read "#{FOLDER}/head.html.haml"

  def initialize
    @conf = YAML.load(File.read("conf.yml"))
    @generators = @conf["generators"].map{|k, g|
      generator = GraphGenerator.new(g["classes"], g["type"])
      [k, {
        top_class: g["top_class"],
        generator: generator,
        graphes: generator.classes.map{|cls, values| [cls, generator.generate_graph(cls)]}.to_h
      }]}.to_h
  end

  def gen_site! folder="html"
    FileUtils.rm_r folder if File.exist? folder
    FileUtils.mkdir folder
    FileUtils.cp_r("#{FOLDER}/css", "#{folder}/css")
    FileUtils.cp_r("#{FOLDER}/js", "#{folder}/js")
    FileUtils.mkdir "#{folder}/img"

    write_template folder, "index"

    @generators.each do |name, generator|
      FileUtils.mkdir "#{folder}/#{name}"
      FileUtils.mkdir "#{folder}/img/#{name}"

      generator[:generator].classes.each_key do |cls|
        puts "Generate #{name}: #{cls} class"

        generator[:graphes][cls].gen_all! "#{folder}/img/#{name}/#{cls}"

        File.open("#{folder}/#{name}/#{cls}.html", "w") do |f|
          f.write(render_index cls, name)
        end
      end

      File.open("#{folder}/#{name}/index.html", "w") do |f|
        f.write(render_index generator[:top_class], name)
      end

    end
  end

  private

  def write_template folder, template, dataset={}
    File.open("#{folder}/#{template}.html", "w") do |f|
      f.write(render_template template, dataset)
    end
  end

  def render haml, dataset={}
    return Haml::Engine.new(haml).render(Object.new, **dataset) 
  end

  def render_footer
    return render FOOTER, {generators: @generators,
                           location: @conf["location"]}
  end

  def render_head active_class=nil, generator=nil
    return render HEAD, {title: @conf["title"],
                         generators: @generators,
                         active_class: active_class,
                         location: @conf["location"],
                         generator: generator}
  end

  def render_body active_class, generator
    return render BODY, {active_class: @generators[generator][:generator].classes[active_class],
                         classes: @generators[generator][:generator].classes,
                         location: @conf["location"],
                         generator: generator,
                         graph: @generators[generator][:graphes][active_class]}
  end

  def render_index active_class, generator
    dataset = {footer: render_footer,
               head: render_head(active_class, generator),
               body: render_body(active_class, generator),
               title: @conf["title"],
               location: @conf["location"],
               generator: generator
    }
    return render LAYOUT, dataset
  end

  def render_template template, dataset
    dataset.merge!({
      title: @conf["title"],
      location: @conf["location"],
      generators: @generators
    })

    haml = File.read("#{FOLDER}/#{template}.html.haml")
    return render(LAYOUT, {
      footer: render_footer,
      head: render_head,
      body: render(haml, dataset),
      title: @conf["title"],
      location: @conf["location"],
      generators: @generators
    })
  end
end

HTMLGenerator.new.gen_site!

