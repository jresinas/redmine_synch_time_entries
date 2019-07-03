RedmineApp::Application.routes.draw do
	resources :synch_relations
	match '/synch_relations/get_source_subject/:id' => 'synch_relations#get_source_subject', :via => [:get, :post]
	match '/synch_relations/get_target_subject/:id' => 'synch_relations#get_target_subject', :via => [:get, :post]
	match '/synch_relations/null/perform_manual_synch' => 'synch_relations#perform_manual_synch', :via => [:post, :delete]
end