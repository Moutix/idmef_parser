require 'json'
require 'yaml'

RFC = "rfc4765.txt"

class RfcReader
  attr_accessor :classes, :tree_classes

  def initialize(rfc)
    @rfc = IO.readlines(rfc)
    @classes = {}
    @tree = {}
    parse
    @tree_classes = Marshal.load(Marshal.dump(@classes))
    classes_to_tree
  end

  def to_s
    @tree
  end

  def to_json
    JSON.pretty_generate(@tree)
  end

  def to_file folder='idmef', ext='json'
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
    File.open("idmef.#{ext}", "w") do |f|
      case ext
      when "json"
        f.write(JSON.pretty_generate(@tree))
      when "yml"
        f.write(YAML.dump(@tree))
      end
    end
  end

  private

  def classes_to_tree
    @tree["Alert"] = itterate_class(@tree_classes["Alert"])
    @tree["Heartbeat"] = itterate_class(@tree_classes["Heartbeat"])
  end

  def itterate_class(class_object)
    class_object["aggregates"].each do |name, aggregate|
      if @tree_classes[name]
        if name == class_object["name"] || class_object["name"] == "Linkage"
          aggregate["type"] = name
        else
          child = itterate_class(@tree_classes[name])
          aggregate["type"] = name
          aggregate["aggregates"] = child["aggregates"]
          aggregate["attributes"] = child["attributes"]
          aggregate["class_description"] = child["description"]
        end
      end
    end
    return class_object
  end

  def parse
    current_class = nil
    current_attr = {}
    state = "start"
    section = 0
    enums = []

    @rfc.each do |line|
      if line =~ /^(\d+)\..+$/
        section = $1.to_i
      end

      if section == 4
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
            @classes[current_class]["description"] += ($1 + " ")
            next
          end
        end

        detect_attribute = detect_attr(line)
        if detect_attribute == "aggr"
          state = "aggregate"
          next
        elsif detect_attribute == "attr"
          state = "attribute"
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
          elsif current_attr["multiplicity"].nil? && line =~ /^\s+(Exactly|Zero|Optional|One)\s?(?:or)?\s?(one|more)?\.\s+(?:(\S+)\.)?\s*(.+)$/
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
            if current_attr["description"]
              @classes[current_class]["attributes"][current_attr["name"]] = current_attr
              current_attr = {}
            end
            next
          elsif current_attr["name"].nil? && line =~ /^\s+([\w-]+)$/ 
            current_attr["name"] = $1
            next
          elsif current_attr["name"] && current_attr["multiplicity"].nil? && line =~ /\s+(Optional|Required)?\.?\s+(?:(\S+)\.)?\s*(.+)$/
            current_attr["multiplicity"] = $1
            current_attr["type"] = $2
            current_attr["description"] = $3
            next
          elsif current_attr["name"] && current_attr["description"] && line =~ /^\s+(.+)$/
            current_attr["description"] += " " + $1
            next
          end
        end
      end

      if section == 10
        if line =~ /^\s+IDMEF\sClass\sName\:\s+(\w+)$/
          enums.push({"class" => $1, "values" => []})
          next
        end
        if line =~ /^\s+IDMEF\sAttribute\sName\:\s+(\w+)$/
          enums.last()["attr"] = $1
          if enums.last()["class"] == "UserId" && enums.last()["attr"] == "category"
            enums.last()["attr"] = "type"
          end
          next
        end
        if line =~ /^\s+\|\s+(\d+)?\s+\|\s+(\S+)?\s+\|\s+(.+?)\s+\|$/
          rank = $1
          keyword = $2
          description = $3
          if rank
            enums.last()["values"].push({"rank" => rank, "keyword" => keyword, "description" => description})
          elsif description
            enums.last()["values"].last()["description"] += " " + description
          end
        end
      end
    end

    enums.each do |enum|
      if @classes[enum["class"]]["aggregates"].keys.include?(enum[:attr])
        @classes[enum["class"]]["aggregates"][enum["attr"]]["type"] = "ENUM"
        @classes[enum["class"]]["aggregates"][enum["attr"]]["values"] = enum["values"]
      end
      if @classes[enum["class"]]["attributes"].keys.include?(enum["attr"])
        @classes[enum["class"]]["attributes"][enum["attr"]]["type"] = "ENUM"
        @classes[enum["class"]]["attributes"][enum["attr"]]["values"] = enum["values"]
      end
    end
  end

  def detect_class(line)
    if line =~ /^([0-9 \.]+)\s+The\s(.+)\sClass$/
      return $2
    end
  end

  def detect_attr(line)
    if line =~ /\s+The\saggregate\sclass(?:es)?\s.+(are|is):$/
      return "aggr"
    elsif line =~ /\s+.+\shas\s\w+\sattribute(?:s)?:/
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
    if _end == "more"
      str += "..*"
    elsif _start != "Exactly"
      str += "..1"
    end
    return str
  end
end

rfc = RfcReader.new(RFC)
rfc.to_file "idmef/json", "json"
rfc.to_file "idmef/yaml", "yml"
