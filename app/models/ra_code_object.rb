class RaCodeObject < ActiveRecord::Base
  belongs_to :ra_container
  
  TYPE_REQUIRE = 'RaRequire'
  TYPE_INCLUDE = 'RaInclude'
  TYPE_CONSTANT = 'RaConstant'
  TYPE_ATTRIBUTE = 'RaAttribute'
  
  def container_name
    @attributes['container_name']
  end  

  def container_type
    @attributes['container_type']
  end  
  
  def container?
  	false
  end
  
end
