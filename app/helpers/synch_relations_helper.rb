module SynchRelationsHelper
	def synch_relations_to_csv(synch_relations)
		Redmine::Export::CSV.generate do |csv|
			columns = [
				'source',
				'target'
			]

			csv << columns.map{|column| l('field_' + column)}

			synch_relations.each do |sr|
				target_name = ''
				if sr.data_type == 'User'
					user = User.find(sr.target_id)
					target_name = user.login if user.present?
#				elsif sr.data_type == 'Issue'
#					issue = Issue.find(sr.target_id)
#					target_name = issue.id if issue.present?
				elsif sr.data_type == 'Project'
					project = Project.find(sr.target_id)
					target_name = project.identifier if project.present?
				end
				csv << columns.map do |column|
					if column == 'source'
#						if sr.data_type == 'Issue'
#							sr.source_id
#						else
							sr.source_name
#						end
					elsif column == 'target'
						target_name
					else
						''
					end
				end
			end
		end
	end
end