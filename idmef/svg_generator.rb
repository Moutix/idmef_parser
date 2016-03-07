require 'json'
require 'yaml'
require 'graphviz'
require 'cgi'

class SVGGenerator
  def initialize folder="idmef", ext="json"
    @classes = parse_folder(folder, ext)
  end

  def generate_svg!(idmef_class, folder="graph")
    Dir.mkdir(folder) unless File.exists?(folder)
    Dir.chdir(folder) do
      graph = GraphViz.new(idmef_class, type: :digraph)
      graph[:rankdir] = "LR"
      svg_generator graph, {}, idmef_class

      graph.output(png: "#{idmef_class}.png")
      graph.output(svg: "#{idmef_class}.svg")
      graph.output(dot: "#{idmef_class}.dot")
    end
  end

  def generate_all!(folder="graph")
    @classes.each_key do |idmef_class|
      generate_svg!(idmef_class, folder)
    end
  end

  private

  def svg_generator(graph, nodes, idmef_class)
    return unless @classes.include? idmef_class

    node = graph.add_nodes(idmef_class)
    nodes[node.id] = node
    label = %{
      <<table BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <tr >
        <td BGCOLOR="#CECECE" HREF="#" TITLE="#{CGI.escapeHTML(@classes[idmef_class]["description"])}">#{idmef_class}</td>
      </tr>"
    %}.gsub(/\s+/, " ").strip

    node[:shape] = "plaintext"

    @classes[idmef_class].fetch("childs", {}).each do |key, value|
      next unless @classes.include? key
      if nodes.has_key?(key)
        edge = graph.add_edge(node, nodes[key])
      else
        edge = graph.add_edge(node, svg_generator(graph, nodes, key))
      end
      edge[:dir] = "back"
      edge[:arrowtail] = "invempty"
    end

    @classes[idmef_class].fetch("aggregates", {}).each do |key, value|
      if @classes.include? key
        if nodes.has_key?(key)
          edge = graph.add_edge(node, nodes[key])
        else
          edge = graph.add_edge(node, svg_generator(graph, nodes, key))
        end
        edge[:label] = value["multiplicity"]
      else
        label += graph_attr(value)
      end
    end
    @classes[idmef_class].fetch("attributes", {}).each do |key, value|
      label += graph_attr(value)
    end

    node[:label] = "#{label}</table>>"
    return node
  end

  def graph_attr(attr)
    return  %{<tr><td HREF="#" TITLE="#{CGI.escapeHTML(attr["description"])}">[#{attr["type"]}] #{attr["name"]} (#{attr["multiplicity"]}) </td></tr>%}
  end

  def parse_folder folder, ext="json"
    classes = {}
    Dir.glob("#{folder}/*.#{ext}").each do |json|
      h = File.open(json) do |f| 
        case ext
        when "json"
          JSON.parse(f.read)
        when "yml"
          YAML.load(f.read)
        else
          return
        end
      end
      classes[h["name"]] = h
    end
    classes
  end
end

SVGGenerator.new('yaml', "yml").generate_all! "graph"
