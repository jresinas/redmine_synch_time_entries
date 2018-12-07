RedmineApp::Application.routes.draw do
	resources :synch_relations
	match '/synch_relations/get_source_subject/:id' => 'synch_relations#get_source_subject', :via => [:get, :post]
	match '/synch_relations/get_target_subject/:id' => 'synch_relations#get_target_subject', :via => [:get, :post]
end