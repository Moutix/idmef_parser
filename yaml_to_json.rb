require 'json'
require 'yaml'

class YamlToJson
  def initialize json="json", yaml="yaml"
    @json = json
    @yaml = yaml
  end

  def convert_to_json
    Dir.glob("#{@yaml}/*.yml").each do |yaml|
      File.open(yaml) do |f|
        File.open("#{@json}/#{File.basename(f.path, ".*")}.json", "w") do |fw|
          fw.write(JSON.pretty_generate(YAML.load(f.read)))
        end
      end
    end
  end

  def convert_to_yaml
    Dir.glob("#{@json}/*.json").each do |json|
      File.open(json) do |f|
        File.open("#{@yaml}/#{File.basename(f.path, ".*")}.yml", "w") do |fw|
          fw.write(YAML.dump(JSON.load(f.read)))
        end
      end
    end
  end
end

YamlToJson.new("idmef/json", "idmef/yaml").convert_to_json
YamlToJson.new("iodef/json", "iodef/yaml").convert_to_json
