require 'haml'
require_relative 'graph_generator'
require 'fileutils'

class HTMLGenerator
  FOLDER = "templates"
  FOOTER = File.read "#{FOLDER}/footer.html.haml"
  BODY = File.read "#{FOLDER}/body.html.haml"
  LAYOUT = File.read "#{FOLDER}/index.html.haml"
  HEAD = File.read "#{FOLDER}/head.html.haml"

  TITLE = "IDMEF"
  TOPCLASS = "IDMEF-Message"

  def initialize
    @generator = GraphGenerator.new
  end

  def gen_site! folder="html"
    FileUtils.rm_r folder
    FileUtils.mkdir folder
    FileUtils.cp_r("#{FOLDER}/css", "#{folder}/css")
    FileUtils.cp_r("#{FOLDER}/js", "#{folder}/js")
    @generator.classes.each_key do |idmef_class|
      @generator.generate_graph! idmef_class, "#{folder}/img"
      File.open("#{folder}/#{idmef_class}.html", "w") do |f|
        f.write(render_index idmef_class)
      end
      File.open("#{folder}/index.html", "w") do |f|
        f.write(render_index TOPCLASS)
      end
    end
  end

  private

  def render haml, dataset={}
    return Haml::Engine.new(haml).render(Object.new, **dataset) 
  end

  def render_footer
    return render FOOTER, {classes: @generator.classes}
  end

  def render_head idmef_class
    return render HEAD, {title: TITLE, classes: @generator.classes, idmef_class: idmef_class}
  end

  def render_body idmef_class
    return render BODY, {idmef_class: @generator.classes[idmef_class], classes: @generator.classes}
  end

  def render_index idmef_class, name=nil
    name ||= idmef_class

    dataset = {footer: render_footer,
               head: render_head(idmef_class),
               body: render_body(idmef_class),
               title: TITLE
    }
    return render LAYOUT, dataset
  end
end

HTMLGenerator.new.gen_site!

