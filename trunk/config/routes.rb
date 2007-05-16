ActionController::Routing::Routes.draw do |map|

  map.search  'search', :controller => 'front', :action => 'search'
  map.homepage '', :controller => 'front', :action => 'index'
  map.login   'login',  :controller => 'front', :action => 'login'
  map.logout  'logout',  :controller => 'front', :action => 'logout'
  map.signup  'signup', :controller => 'front', :action => 'signup'

  Hobo.add_routes(map)

  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
