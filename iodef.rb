require 'json'
require 'yaml'

RFC = "rfc5070.txt"

class RfcReader
  attr_accessor :classes, :tree_classes

  def initialize(rfc)
    @rfc = IO.readlines(rfc)
    @classes = {}
    @tree = {}
    parse
  end

  def to_s
    @tree
  end

  def to_json
    JSON.pretty_generate(@tree)
  end

  def to_file folder='iodef', ext='json'
    Dir.mkdir(folder) unless File.exists?(folder)
    Dir.chdir(folder) do
      @classes.each do |name, classe|
        File.open("#{name}.#{ext}", "w") do |f|
          case ext
          when "json"
            f.write(JSON.pretty_generate(classe))
          when "yml"
            f.write(YAML.dump(classe))
          end
        end
      end
    end
  end

  private

  def parse
    current_class = nil
    current_attr = {}
    state = "start"
    section = 0
    blankline = false

    @rfc.each do |line|
      if line =~ /^(\d+)\..+$/
        if state == "attribute" && current_attr && current_attr["name"]
          @classes[current_class]["attributes"][current_attr["name"]] = current_attr
          current_attr = {}
        end
        section = $1.to_i
      end

      if section == 3
        if (idmef_class = detect_class(line))
          current_class = idmef_class
          @classes[idmef_class] = {"name" => idmef_class, "description" => "", "aggregates" => {}, "attributes" => {}}
          state = "description"
          next
        elsif current_class == nil
          next
        end

        if state == "description" ## State: Class description
          if line =~ /^\s*$/
            if @classes[current_class]["description"] != ""
              state = "schema"
              next
            else
              next
            end
          else
            line =~ /^\s+(.+)$/
            @classes[current_class]["description"] += ($1 + " ") if $1
            next
          end
        end

        detect_attribute = detect_attr(line)
        if detect_attribute == "aggr"
          state = "aggregate"
          next
        elsif detect_attribute == "attr"
          state = "attribute"
          current_attr = nil
          next
        end


        if state == "aggregate" ## State: Aggregate Class
          if line =~ /^\s*$/
            if current_attr["description"]
              @classes[current_class]["aggregates"][current_attr["name"]] = current_attr
              current_attr = {}
            end
            next
          elsif current_attr["name"].nil? && line =~ /^\s+([\w-]+)$/ 
            current_attr["name"] = $1
            next
          elsif current_attr["multiplicity"].nil? && line =~ /^\s+(Exactly|Zero|Optional|One)\s?(?:or)?\s?([oO]ne|[mM]ore|[Mm]any)?\.\s+(?:(\S+)\.)?\s*(.+)$/
            current_attr["multiplicity"] = str_to_multiplicity($1, $2)
            current_attr["type"] = $3
            current_attr["description"] = $4
            next
          elsif current_attr["description"] && line =~ /^\s+(.+)$/
            current_attr["description"] += " " + $1
            next
          end
        end

        if state == "attribute" ## State: Aggregate Class
          if line =~ /^\s*$/
            blankline = true
            next
          end
          if line =~ /^\s+([\w-]+)$/ ## It's the name of a new attr
            @classes[current_class]["attributes"][current_attr["name"]] = current_attr if current_attr
            current_attr = {"name" => $1}
            blankline = false
            next
          elsif current_attr["name"] && line =~ /\s+(\d+)\.\s+(\S+)\.\s+(.+)$/ ## It's an enumeration
            current_attr["values"] = [] unless current_attr["values"]
            current_attr["values"] << {"rank" => $1, "keyword" => $2, "description" => $3}
            blankline = false
            next
         elsif current_attr["name"] && current_attr["multiplicity"].nil? && line =~ /\s+(Optional|Required)?\.?\s+(?:(\S+)\.)?\s*(.+)$/
            current_attr["multiplicity"] = $1
            current_attr["type"] = $2
            current_attr["description"] = $3
            blankline = false
            next
          elsif current_attr["name"] && current_attr["description"] && line =~ /^\s+(.+)$/ && !blankline
            if current_attr["values"]
              current_attr["values"].last["description"] += " " + $1
            else
              current_attr["description"] += " " + $1
            end
            blankline = false
            next
          end
        end
      end
    end
  end

  def detect_class(line)
    if line =~ /^([0-9\.]+)\s+(.+)\sClass$/
      return $2
    end
  end

  def detect_attr(line)
    if line =~ /^.+aggregate(?:s)?\s+class(?:es)?.+$/
      return "aggr"
    elsif line =~ /^\s+The\s+class\s+that\s+constitutes\s+\w+\s(?:are|is):$/
      return "aggr"
    elsif line =~ /\s+.+\shas\s\w+\sattribute(?:s)?:/
      return "attr"
    elsif line =~ /\w+\s+attribute(?:s)?:/
      return "attr"
    end
  end

  def str_to_multiplicity(_start, _end)
    str = ""
    if _start == "One" or _start == "Exactly"
      str += "1"
    else
      str += "0"
    end
    if ["More", "more", "many", "Many"].include?(_end)
      str += "..*"
    elsif _start != "Exactly"
      str += "..1"
    end
    return str
  end
end

rfc = RfcReader.new(RFC)
rfc.to_file "iodef/json", "json"
rfc.to_file "iodef/yaml", "yml"
