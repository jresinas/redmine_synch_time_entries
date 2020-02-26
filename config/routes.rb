RedmineApp::Application.routes.draw do
	resources :synch_relations
	match '/synch_relations/get_source_subject/:id' => 'synch_relations#get_source_subject', :via => [:get, :post]
	match '/synch_relations/get_target_subject/:id' => 'synch_relations#get_target_subject', :via => [:get, :post]
	match '/synch_relations/null/perform_manual_synch' => 'synch_relations#perform_manual_synch', :via => [:post, :delete]
	get   '/synch_relation_imports/new', :to => 'synch_relation_imports#new', :as => 'new_synch_relation_import'
	post  '/synch_relation_imports', :to => 'synch_relation_imports#create', :as => 'synch_relation_imports'
	get   '/synch_relation_imports/:id', :to => 'synch_relation_imports#show', :as => 'synch_relation_import'
	match '/synch_relation_imports/:id/settings', :to => 'synch_relation_imports#settings', :via => [:get, :post], :as => 'synch_relation_import_settings'
	match '/synch_relation_imports/:id/mapping', :to => 'synch_relation_imports#mapping', :via => [:get, :post], :as => 'synch_relation_import_mapping'
	match '/synch_relation_imports/:id/run', :to => 'synch_relation_imports#run', :via => [:get, :post], :as => 'synch_relation_import_run'
end