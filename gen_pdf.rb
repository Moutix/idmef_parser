require 'prawn'

class IDMEFPDF
    def initialize(class_name, graph, pdf_name)
        Prawn::Document.generate(pdf_name) do
            # Header is just the class name
            stroke_horizontal_rule
            class_name = class_name.split('/')[-1]
            pad(10) { font_size(25) { text class_name, align: :center } }
            stroke_horizontal_rule
            move_down 10
            # Insert image
            image graph, position: :center, vposition: :center, width: 600
        end
    end
end
