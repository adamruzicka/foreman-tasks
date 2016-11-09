module ForemanTasks
  module ExternalTaskHelper

    def section_title(title, icon_class = nil)
      content_tag(:div, :class => "col-md-12") do
        content_tag(:h4) do
          content_tag(:i, '&nbsp'.html_safe, :class => icon_class) + title
        end
      end
    end
  end
end
