require 'synch_time_entries/time_entry_query_patch'
require 'synch_time_entries/issue_patch'
require 'synch_time_entries/user_patch'
require 'synch_time_entries/project_patch'
require 'synch_time_entries/time_entry_patch'

Redmine::Plugin.register :redmine_synch_time_entries do
  name 'Redmine Synch Time Entries'
  author 'jresinas'
  description 'Allow to synch time entries from another Redmine instance'
  version '0.0.1'
  author_url 'http://www.emergya.es'

  settings :default => {}, :partial => 'settings/synch_time_entries'

  menu :admin_menu, :'synch_time_entries.label_settings', { :controller => 'synch_relations', :action => 'index' },
       :html => { :class => 'issue_statuses' },
       :caption => :'synch_time_entries.label_settings'
end