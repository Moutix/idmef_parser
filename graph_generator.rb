require 'json'
require 'yaml'
require 'graphviz'
require 'cgi'

class IDMEFGraph
  def initialize(idmef_class, classes, link = nil, direction = 'LR', color = true)
    @class = idmef_class
    @classes = classes
    @graph = GraphViz.new @class, type: :digraph
    @graph[:rankdir] = direction
    @color = color
    @nodes = {}
    @link = link
    add_node(@class)
  end

  def gen_png! file
    @graph.output(png: file)
  end

  def gen_svg! file
    @graph.output(svg: file)
  end

  def gen_dot! file
    @graph.output(dot: file)
  end

  def gen_all! base_name
    gen_svg! "#{base_name}.svg"
    gen_png! "#{base_name}.png"
    gen_dot! "#{base_name}.dot"
  end

  def to_svg
    return @graph.output(svg: String)
  end

  def to_dot
    return @graph.output(dot: String)
  end

  private

  def darken_color(hex_color, amount=0.4)
    hex_color = hex_color.gsub('#','')
    rgb = hex_color.scan(/../).map {|color| color.hex}
    rgb[0] = (rgb[0].to_i * amount).round
    rgb[1] = (rgb[1].to_i * amount).round
    rgb[2] = (rgb[2].to_i * amount).round
    "#%02x%02x%02x" % rgb
  end

  def add_edge(node, name)
    if @nodes.has_key? name
      return @graph.add_edge(node, @nodes[name])
    else
      return @graph.add_edge(node, add_node(name))
    end
  end

  def add_node(name)
    return unless @classes.include? name

    node = @graph.add_nodes(name)
    node[:shape] = "plaintext"

    color = @color ? @classes[name]["color"] : nil

    @nodes[node.id] = node
    label = %{
      <<table BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <tr >
        <td BGCOLOR="#{color ? darken_color(color, 0.6) : "#CECECE"}" HREF="#{@link.nil? ? '#' : "#{@link}/#{name}.html"}" TITLE="#{CGI.escapeHTML(@classes[name]["description"])}">#{name}</td>
      </tr>"
    %}.gsub(/\s+/, " ").strip

    @classes[name].fetch("childs", {}).each do |key, value|
      next unless @classes.include? key
      edge = add_edge(node, key)
      edge[:dir] = "back"
      edge[:arrowtail] = "invempty"
    end

    @classes[name].fetch("aggregates", {}).each do |key, value|
      if @classes.include? key
        edge = add_edge(node, key)
        edge[:label] = value["multiplicity"]
      else
        label += graph_attr(name, value, @color ? (color ? color : value["color"]) : nil)
      end
    end

    @classes[name].fetch("attributes", {}).each do |key, value|
      label += graph_attr(name, value, color ? color : value["color"])
    end

    label += "</table>>"
    node[:label] = label
    return node
  end

  def graph_attr(name, attr, color = nil)
    return  %{<tr><td #{color ? "BGCOLOR=\"#{color}\" " : ''} HREF="#{@link.nil? ? '#' : "#{@link}/#{name}.html"}" TITLE="#{CGI.escapeHTML(attr["description"])}">[#{attr["type"]}] #{attr["name"]} (#{attr["multiplicity"]}) </td></tr>%}
  end
end

class GraphGenerator
  attr_accessor :classes

  MAPPING = {
    "json" => Proc.new {|a| JSON.parse(a)},
    "yml" => Proc.new {|a| YAML.load(a)},
  }

  def initialize folder="json", ext="json"
    @folder = folder
    @ext = ext
    @classes = parse_folder
  end

  def generate_files! idmef_class, folder="graph", link=nil, direction="LR", color=true
    graph = self.generate_graph idmef_class, link, direction, color

    Dir.mkdir(folder) unless File.exists?(folder)
    Dir.chdir(folder) do
      graph.gen_all! idmef_class
    end

  end

  def generate_graph idmef_class, link=nil, direction="LR", color=true
    return IDMEFGraph.new idmef_class, @classes, link, direction, color
  end

  def generate_all! folder="graph", link=nil, direction="LR", color=true
    @classes.each_key do |idmef_class|
      generate_files! idmef_class, folder, link, direction, color
    end
  end

  def get_class_tree(root=TOPCLASS, deepness=0)
    classes = {}
    return {} if deepness > 5

    @classes[root].fetch("childs", {}).each_key do |idmef_class|
      if @classes.include? idmef_class and idmef_class != root
        classes[idmef_class] = get_class_tree(idmef_class, deepness+1)
      end
    end

    @classes[root].fetch("aggregates", {}).each_key do |idmef_class|
      if @classes.include? idmef_class and idmef_class != root
        classes[idmef_class] = get_class_tree(idmef_class, deepness+1)
      end
    end

    return classes
  end

  private

  def parse_folder
    classes = {}
    Dir.glob("#{@folder}/*.#{@ext}").each do |json|
      h = File.open(json) do |f|
        MAPPING[@ext].call f.read
      end
      classes[h["name"]] = h
    end
    return classes
  end
end

if __FILE__ == $0
  GraphGenerator.new('idmef/yaml', "yml").generate_all! "idmef/graph"
  GraphGenerator.new('iodef/yaml', "yml").generate_all! "iodef/graph"
end
