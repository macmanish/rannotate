class HistoryController < ApplicationController
  session :off
  caches_page :library

  # show the file, class, module differences beteween two versions of a library
  def library  	
  	# Get the two versions of the library
  	libs = RaLibrary.find(:all, :conditions => ["name = ?", params[:name]], :order => "version ASC")
    @versions = []
    lib_ids = []    
  	for lib in libs
  	 lib_ids.push(lib.id)
     @versions.push({:container => lib, :added => {}, :changed => {}, :removed => {}})     	 
  	end
  	
  	containers = RaContainer.find(:all, :conditions => ["ra_library_id IN(?)", lib_ids])
  	  	
    # Group the containers by library id
    containers_hash = Hash.new
    containers.each do |c|
    	unless containers_hash[c.ra_library_id] then containers_hash[c.ra_library_id] = Hash.new end
    	containers_hash[c.ra_library_id][c.class.to_s + c.full_name] = c
	end 	
  	
  	# Diff the two lists and put the results in @versions
  	check_changes(@versions, 'files', containers_hash)
  	@versions.reverse!
  	
  	render :layout => 'doc'
  end

  # Show the differences for all versions of a container
  # Sets a @version variable that contains an array of all the versions
  # with their differences to the previous version
  def container
    @versions = Array.new
    @container_name = @params[:name]
    type = @params[:type]
    
    # Get all versions of this container
    container_versions = RaContainer.find(:all, :include => [:ra_comment, :ra_library], 
    	:conditions => ["full_name = ? AND type = ?", @container_name, type],
    	:order => "version ASC")    
    	
    unless(container_versions && container_versions.length > 0)
    	@error = "Could not find: " + type + " " + @container_name + " for history"
    	return
    end     
    
    # Put all the versions of the container into an array of hashtables
    container_ids = Array.new
    container_versions.each do |v|
        # each entry in the array contains a hashtable that has the container
        # as well as hashes for all of the items that were added/removed/changed between versions
    	@versions.push({:container => v, :added => {}, :changed => {}, :removed => {}})
    	# collect up the ids of all the containers
    	container_ids.push(v.id)
   	end
    
    # Get all of the methods for all versions of this container    
    methods = RaMethod.find(:all, :conditions => ["ra_container_id IN (?)", container_ids], :order => "name ASC")
    
    # Group the methods by container id in a hashtable
    methods_hash = Hash.new
    methods.each do |method|
    	if(method.visibility != RaContainer::VIS_PRIVATE)
    		unless methods_hash[method.ra_container_id] then methods_hash[method.ra_container_id] = Hash.new end
	    	methods_hash[method.ra_container_id][method.class.to_s + method.name] = method
    	end
	end
	
	# Group the code_objects by container id
	code_objects = RaCodeObject.find(:all, :conditions => ["ra_container_id IN (?)", container_ids], :order => "name ASC")
	code_objects_hash = Hash.new
	code_objects.each do |obj|
   		unless code_objects_hash[obj.ra_container_id] then code_objects_hash[obj.ra_container_id] = Hash.new end
   		# note that we index the second level of the has table using the object name
   		# and object class, we have to do this because several different objects could have the same name (I think) 	
    	code_objects_hash[obj.ra_container_id][obj.class.to_s + obj.name] = obj
	end
	
	check_changes(@versions, :methods, methods_hash)
	check_changes(@versions, :code_objects, code_objects_hash)
#	check_changes(@versions, :in_files, in_files_hash)
  	  	
  	@versions.reverse!
  end
  
protected

	def check_changes(versions, type, type_hash)
		# For each version check all of the methods against the previous version
		# to see if they have changed or if they were added or removed
		for i in 1...versions.length		
		
		    # get the id of each version and it's previous version
			current_ver = versions[i][:container].id
			pre_ver = versions[i-1][:container].id
			
			# if there is no entry in the type_hash for these ids then do not continue
			# this could happen if for example all of the methods are removed between versions
			unless type_hash[current_ver] == nil || type_hash[pre_ver] == nil
			
			    # for each of the entries in the current version check to see if it
			    # has been added or removed since the previous version
    			type_hash[current_ver].values.each do |obj|
    			    obj.respond_to?("full_name")? obj_name = obj.full_name : obj_name = obj.name
    			    
    				old_obj = type_hash[pre_ver][obj.class.to_s + obj_name]
    				type_string = obj.class.type_string	    			
		    		if (old_obj == nil)
		    		    if(versions[i][:added][type_string] == nil) then versions[i][:added][type_string] = [] end
    					versions[i][:added][type_string].push(obj)
    				else
    					change = compare_object(obj, old_obj)		    		        					
    					if(change)
    					  if(versions[i][:changed][type_string] == nil) then versions[i][:changed][type_string] = [] end
    					   versions[i][:changed][type_string].push(change)
    					end    					   
		    		end    		    		
    				# remove the method from the hash because it is already processed
    				type_hash[pre_ver].delete(obj.class.to_s + obj_name)
	    		end
		    	# all the items left over are methods that were removed between versions
    			type_hash[pre_ver].values.each do |obj|
        			type_string = obj.class.type_string	 
		    		if(versions[i][:removed][type_string] == nil) then versions[i][:removed][type_string] = [] end     			
    				versions[i][:removed][type_string].push(obj)	
    			end
		    end
	    end    	
    end        
    
    def compare_object(new, old)    	
    	result = nil
    	case new.class.to_s
    		when 'RaMethod'    		
    			if(new.parameters != old.parameters)
    				result = new.name + new.parameters + " --> " + old.name + old.parameters
    			end
    		when 'RaAlias'    			
    		when 'RaAttribute'
    		when 'RaConstant'
    		when 'RaRequire'
    		when 'RaInclude'
    	end
    	return result
    end
    
end
