namespace :synch do
	task :time_entries => :environment do
		result_update = []
		result_create = []

		user_relations = SynchRelation.where(data_type: 'User')
		issue_relations = SynchRelation.where(data_type: 'Issue')
		project_relations = SynchRelation.where(data_type: 'Project')
		project_relations_tree = SynchTimeEntries::Source.get_project_relations_tree(project_relations)
		if Setting.plugin_redmine_synch_time_entries['synch_mode'].present? and Setting.plugin_redmine_synch_time_entries['synch_mode'] == 'year'
			start_date = Date.new(Setting.plugin_redmine_synch_time_entries['synch_year'].to_i, 1, 1)
			end_date = Date.new(Setting.plugin_redmine_synch_time_entries['synch_year'].to_i, 12, 31)
		else
			start_date = Date.today - (Setting.plugin_redmine_synch_time_entries['offset_days'].to_i || 0).days
			end_date = Date.today
		end
		time_entries = SynchTimeEntries::Source.get_time_entries(start_date, end_date)
		time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ?", start_date, end_date)

		time_entries.each do |te|
			project_match = project_relations_tree.detect{|p| p[:id] == te[:project_id] or p[:descendants].include?(te[:project_id])}
			project_match_id = project_match.present? ? project_match[:id] : nil
			if (user_relation = user_relations.find_by(source_id: te[:user])) and ((issue_relation = issue_relations.find_by(source_id: te[:issue_id])) or (project_relation = project_relations.find_by(source_id: project_match_id)))
				# Obtenemos usuario de destino
				te[:user] = User.find(user_relation.target_id)

				# Obtenemos petición de destino (y proyecto si es relevante)
				if issue_relation.present?
					te[:issue_id] = issue_relation.target_id
					te[:project_id] = Issue.find(issue_relation.target_id).project_id
				elsif project_relation.present?
					te[:project_id] = project_relation.target_id
					subject = Setting.plugin_redmine_synch_time_entries['issue_subject']+" "+te[:spent_on].to_date.strftime("%m-%Y")
					user = Setting.plugin_redmine_synch_time_entries['issue_user']
					tracker = Setting.plugin_redmine_synch_time_entries['issue_tracker'] || 2
					issue = (project_relation.target).issues.find_or_create_by(subject: subject, tracker_id: tracker, author_id: user, start_date: te[:spent_on].to_date.at_beginning_of_month)
					te[:issue_id] = issue.id
				end		

				if (time_entry_relation = time_entries_relations.find_by(source_id: te[:id])).present?
					# Está registrada la imputación 
					if time_entry_relation.last_update < te[:updated_on].to_datetime
						# Se ha actualiza la imputación respecto a nuestro último registro => actualizamos la imputación
						result_update << time_entry_relation.time_entry.update_attributes(te)
						time_entry_relation.update_attributes({last_update: te[:updated_on], spent_on: te[:spent_on]})
					end
				else
					# No está registrada la imputación => creamos nueva imputación
					result_create << (time_entry = TimeEntry.create(te))
					SynchTimeEntryRelation.create({source_id: te[:id], target_id: time_entry.id, last_update: te[:updated_on], spent_on: te[:spent_on]})
				end
			end
		end

		deleted_time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ? AND source_id NOT IN (?)", start_date, end_date, time_entries.map{|te| te[:id]})
		deleted_time_entries_relations.each do |te_relation|
			te_relation.time_entry.present? ? te_relation.time_entry.delete : te_relation.delete
		end

	end
end