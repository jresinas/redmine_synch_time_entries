namespace :synch do
	task :project_time_entries, [:project_id, :offset_days] => :environment do |t, args|
		result_update = []
		result_create = []

		if args.project_id.present?
			project_relation = SynchRelation.find_by(data_type: 'Project', source_id: args.project_id)
			if project_relation.present?
				user_relations = SynchRelation.where(data_type: 'User')
				project_relations_tree = SynchTimeEntries::Source.get_project_relations_tree([project_relation]).first
				start_date = Date.today - (args.offset_days.to_i || Setting.plugin_redmine_synch_time_entries['offset_days'].to_i || 0).days
				end_date = Date.today
				time_entries = SynchTimeEntries::Source.get_project_time_entries(project_relation[:source_id], start_date, end_date)
				project_relations_tree[:descendants].each do |id|
					time_entries += SynchTimeEntries::Source.get_project_time_entries(id, start_date, end_date)
				end
				time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ?", start_date, end_date)

				time_entries.each do |te|
					if (user_relation = user_relations.find_by(source_id: te[:user]))
						# Obtenemos usuario de destino
						te[:user] = User.find(user_relation.target_id)
						# Obtenemos proyecto de destino
						te[:project_id] = project_relation.target_id
						subject = Setting.plugin_redmine_synch_time_entries['issue_subject']+" "+te[:spent_on].to_date.strftime("%m-%Y")
						user = Setting.plugin_redmine_synch_time_entries['issue_user']
						tracker = Setting.plugin_redmine_synch_time_entries['issue_tracker'] || 2
						issue = (project_relation.target).issues.find_or_create_by(subject: subject, tracker_id: tracker, author_id: user, start_date: te[:spent_on].to_date.at_beginning_of_month)
						te[:issue_id] = issue.id		

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
			end
		else
			puts "ERROR: la tarea debe tener al menos un argumento"
		end

	end
end