namespace :synch do
	task :time_entries => :environment do
		result_update = []
		result_create = []

		user_relations = SynchRelation.where(data_type: 'User')
		issue_relations = SynchRelation.where(data_type: 'Issue')
		project_relations = SynchRelation.where(data_type: 'Project')
		start_date = Date.today - (Setting.plugin_redmine_synch_time_entries['offset_days'].to_i || 0).days
		end_date = Date.today
		time_entries = SynchTimeEntries::Source.get_time_entries(start_date, end_date)
		time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ?", start_date, end_date)

		time_entries.each do |te|
			if (user_relation = user_relations.find_by(source_id: te[:user])) and ((issue_relation = issue_relations.find_by(source_id: te[:issue_id])) or (project_relation = project_relations.find_by(source_id: te[:project_id])))
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
			te_relation.target.delete
		end

		binding.pry

	end



	# namespace :synch do
	# task :time_entries => :environment do
	# 	result_update = []
	# 	result_create = []

	# 	user_relations = SynchRelation.where(data_type: 'User')
	# 	issue_relations = SynchRelation.where(data_type: 'Issue')
	# 	project_relations = SynchRelation.where(data_type: 'Project')
	# 	start_date = Date.today - 2.days
	# 	end_date = Date.today
	# 	time_entries = SynchTimeEntries::Source.get_time_entries(start_date, end_date)
	# 	time_entries_relations = SynchTimeEntryRelation.where("date >= ?", start_date)

	# 	time_entries.each do |te|
	# 		if (user_relation = user_relations.find_by(source_id: te[:user])) and ((issue_relation = issue_relations.find_by(source_id: te[:issue_id])) or (project_relation = project_relations.find_by(source_id: te[:project_id])))
	# 			# Obtenemos usuario de destino
	# 			te[:user] = User.find(user_relation.target_id)

	# 			# Obtenemos petición de destino (y proyecto si es relevante)
	# 			if issue_relation.present?
	# 				te[:issue_id] = issue_relation.target_id
	# 			elsif project_relation.present?
	# 				te[:project_id] = project_relation.target_id
	# 				issue = (project_relation.target).issues.find_or_create_by(subject: Setting.plugin_redmine_synch_time_entries['issue_subject']+" "+te[:spent_on].to_date.strftime("%m-%Y"), tracker_id: 2, author_id: 445, start_date: te[:spent_on].to_date.at_beginning_of_month)
	# 				te[:issue_id] = issue.id
	# 			end		

	# 			if (time_entry_relation = time_entries_relations.find_by(source_id: te[:id])).present?
	# 				# Está registrada la imputación => actualizamos la imputación
	# 				result_update << time_entry_relation.time_entry.update_attributes(te)
	# 				time_entry_relation.update_attribute(:date, te[:updated_on])
	# 			else
	# 				# No está registrada la imputación => creamos nueva imputación
	# 				result_create << (time_entry = TimeEntry.create(te))
	# 				SynchTimeEntryRelation.create({source_id: te[:id], target_id: time_entry.id, date: te[:updated_on]})
	# 			end
	# 		end
	# 	end

	# 	binding.pry

	# end

# 		time_entries = SynchTimeEntries::Source.get_time_entries('2018-11-14')
# 		time_entries.each do |te|
# 			if (user_relation = user_relations.find_by(source_id: te[:user])) and ((issue_relation = issue_relations.find_by(source_id: te[:issue_id])) or (project_relation = project_relations.find_by(source_id: te[:project_id])))
# 				te[:user] = User.find(user_relation.target_id)

# 				if issue_relation.present?
# 					te[:issue_id] = issue_relation.target_id
# 				elsif project_relation.present?
# 					te[:project_id] = project_relation.target_id
# 					issue = (project_relation.target).issues.find_or_create_by(subject: Setting.plugin_redmine_synch_time_entries['issue_subject']+" "+te[:spent_on].to_date.strftime("%m-%Y"), tracker_id: 2, author_id: 445, start_date: te[:spent_on].to_date.at_beginning_of_month)
# 					te[:issue_id] = issue.id
# 				end

# 				# if user.current_profile.present?
# 				# 	te[:hr_profile_id] = user.current_profile.id
# 				# end
# binding.pry
# 				result << TimeEntry.create(te)
# 			end
		



# 		end

# 		binding.pry
# 	end
end