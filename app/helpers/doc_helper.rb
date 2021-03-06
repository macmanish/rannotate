require 'rdoc/markup/simple_markup'
require 'rdoc/markup/simple_markup/to_html'

module DocHelper

  # Display the parameters for calling a method
  def display_method_parameters(method)      
    if(method.call_seq != nil && method.call_seq.length > 0)
      method.call_seq.split("\n")
      return
    end
    
    if(method.block_parameters)    
    end
    
    return
  end
   
  # return the number of notes in a certain category, or 0 if there are none
  def get_count(note_count, category)
    note_count[category] ? note_count[category] : 0
  end

	# markup the source code using the syntax helper
  def markup_source_code(code)
    begin
      syntax = Syntax::Convertors::HTML.for_syntax "ruby"
	    return syntax.convert(code)   	  
    rescue
      return "<pre>" + code + "</pre>"
    end        
  end

	# show a link to display the source code for a method
    def show_source_link(method_id, source_id)      
      # construct a javascript function that either hides the source div if it's showing already,
      # or gets the source via an Ajax call and shows it
      element = "method_source_#{method_id}"
      function = "Element.visible('#{element}') ? Element.hide('#{element}') : " +
                  remote_function(
                    :update => 'method_source_' + method_id.to_s, 
                    :url => { :action => 'source_code', :source_id=>source_id },
                    :complete => "Element.show('#{element}')")
      
      html = link_to_function("Source", function)
  	  return html
    end

    # Write out javascript to show or hide a section
    def show_or_hide(section)
      return "Element.visible('#{section}') ? Element.hide('#{section}') : Element.show('#{section}')"
    end

	# show the number of notes in a category for a container and show a link to display the notes
    def show_notes_link(container_name, note_group, ref_id = nil, ref_type = nil)
      # in the doc_controller we count up the notes, so output them here
      if(@note_count[note_group])
        count = @note_count[note_group].to_i
        
        # construct a javascript function that either hides the notes div if it's showing already,
        # or gets the notes via an Ajax call and shows it
        element = "notes_" + note_group
        element_add = element + "_add"
        function = "Element.visible('#{element}') ? Element.hide('#{element}') : " +
                  remote_function(
                    :update => 'notes_' + note_group, 
                    :url => { :action => 'notes', :container_name=>container_name, :note_group=>note_group },
                    :complete => "Element.show('#{element}'); Element.show('#{element_add}');")
      
        html = "<b>" + link_to_function(pluralize(count, "note"), function) + "</b>"
      else
        if(ref_id == nil)
          html = get_add_note_link(@ra_container.id, note_group)
        else
          html = get_add_note_link(ref_id, ref_type)  
        end
      end
            
      return html    
    end
    
    # Check to see if we should be displaying a set of notes on load of the page
    def check_display(name)
      if(@expand == name)
        return "";
      else
        return "display: none;"
      end
    end    
    
    # Display the notes on load of the page if ncessary
    def check_show_notes(name, note_group, container_name)
      if(@expand == name)
         return render_notes(container_name, note_group)  
      end
      return ""
    end
    
    # Get a link to add notes
    def get_add_note_link(id, type)
        return link_to('Add New Note', {:controller => 'notes', :action => 'new', :type=>type, :id=>id })
    end

	# render the notes for the class
    def render_notes(container_name, note_group)
      render_component(:controller => 'notes', :action=>'list', 
        :params=> {:no_layout => true, :container_name=>container_name, :note_group=>note_group }
      ) 		    
    end

		# Markup the rdoc comments for display
    def markup_rdoc(str, remove_para=false)
      return '' unless str

      unless defined? @markup # only define the markup object once
        @markup = SM::SimpleMarkup.new
        
        # class names, variable names, file names, or instance variables        
        @markup.add_special(/(\#\w+[!?=]?
                             | \b([A-Z]\w+::\w+)
                             )/x, :CROSSREF)

# TODO: Some of these crossreferences are very expensive
# for some of them we need to do searches for each match to see if it exists
# with page links this is not so bad, but with other things it could be epxensive
# at doc generation time we should use a hashtable to speed this up
#                             \b([A-Z]\w*(::\w+)*[.\#]\w+)  #    A::B.meth
#                             | \b\w+([_\/\.]+\w+)+[!?=]?  #    meth_name

        # external hyperlinks
        # @markup.add_special(/((link\.)\S+\w)/, :HYPERLINK)
        @markup.add_special(/((link:|https?:|mailto:|ftp:|www\.)\S+\w)/, :HYPERLINK)

        # and links of the form  <text>[<url>]
        @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\.\S+?\])/, :TIDYLINK)
      end

      unless defined? @html_formatter
        @html_formatter = Hyperlinker.new(self)
      end

     # Remove leading comment markers if all blank lines have them
     if str =~ /^(?>\s*)[^\#]/
        content = str
     else
        content = str.gsub(/^\s*#+/, '')
        content.gsub!(/^ /, '')
     end

      res = @markup.convert(content, @html_formatter)
      if remove_para
        res.sub!(/^<p>/, '')
        res.sub!(/<\/p>$/, '')
      end
      res
    end  

	# Subclass of the SM::ToHtml class that helps to create hyperlinks out of links
	# in the documentation
    class Hyperlinker < SM::ToHtml
	
    def initialize(dochelper)
      @dochelper = dochelper
      super()
    end

	# We're invoked when any text matches the CROSSREF pattern
	# (defined in MarkUp). If we fine the corresponding reference,
  # generate a hyperlink.
  def handle_special_CROSSREF(special)  	    	  
    name = special.text  	  
    if name[0,1] == '#'
      name = name[1..-1]
    end

 	  if /([A-Z].*)[.\#](.*)/ =~ name
	    ref = @dochelper.link_to(name, {:controller => 'doc', :action => 'search', :name => $1, :exact => 1})
	  else
  	  ref = @dochelper.link_to(name, {:controller => 'doc', :action => 'search', :name => name, :exact => 1})
	  end
	  ref
	end

	  # And we're invoked with a potential external hyperlink mailto:
	  # just gets inserted. http: links are checked to see if they
	  # reference an image. If so, that image gets inserted using an
	  # <img> tag. Otherwise a conventional <a href> is used.  We also
	  # support a special type of hyperlink, link:, which is a reference
	  # to a local file whose path is relative to the --op directory.
	  def handle_special_HYPERLINK(special)
	    url = special.text
	    gen_url(url, url)
	  end

	  # Here's a hypedlink where the label is different to the URL
	  #  <label>[url]       
	  def handle_special_TIDYLINK(special)
  	  text = special.text
      unless text =~ /\{(.*?)\}\[(.*?)\]/ or text =~ /(\S+)\[(.*?)\]/ 
        return text
      end
      label = $1
      url   = $2
      
      gen_url(url, label)
    end

    # Generate a hyperlink for url, labeled with text. Handle the
    # special cases for img: and link: described under handle_special_HYPEDLINK
    def gen_url(url, text)
      if url =~ /([A-Za-z]+):(.*)/
        type = $1
        url = path = $2
      else
        type = "http"
        path = url
        url  = "http://#{url}"
      end

      if (type == "http" || type == "link") && url =~ /\.(gif|png|jpg|jpeg|bmp)$/
      	"<img src=\"#{url}\">"
      elsif (type == 'link' && !(type =~ /http:/))
        if(path[0,7] == "classes")
          url = url[8,url.length - 8]        
          url.sub!(/\.html.*/, '')        
          url.gsub!(/\//, '::')
          return @dochelper.link_to(url, {:controller => 'doc', :action => 'search', :name => url, :exact => 1})           
        elsif(path[0,5] == "files")
          url.sub!(/\.html/, '')
          url.sub!(/files\//, '')
          return @dochelper.link_to(url, {:controller => 'doc', :action => 'search', :name => url, :exact => 1})       
        else
         return "<a href="#">#{path}</a>"
        end
      else
        "<a href=\"#{url}\" target=\"_blank\">#{text.sub(%r{^#{type}:/*}, '')}</a>"
      end
    end

  end # end of HyperlinkHtml class

end # end of DocHelper module