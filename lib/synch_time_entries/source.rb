require "net/http"
require "uri"
LIMIT = 50

module SynchTimeEntries
	class Source
		# Obtiene todos los usuarios del origen
		def self.get_users(offset = 0)
			users = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('users'), 'get', {:offset => offset})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					users += res[:body]['users'].map{|u| [u['id'], u['login']]}
				end
			end

			users.to_h
		end

		# Obtiene todos los usuarios bloqueados del origen
		def self.get_locked_users(offset = 0)
			users = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('users'), 'get', {:offset => offset, :status => 3})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					users += res[:body]['users'].map{|u| [u['id'], u['login']]}
				end
			end

			users.to_h
		end

		# Obtiene la petición con identificador id del origen
		def self.get_issue(id)
			res = redmine_request(get_endpoint('issues', id), 'get')

			if res[:result]
				return res[:body]
			end

			return nil
		end

		# Obtiene todas las peticiones del origen
		def self.get_issues(offset = 0, params = {})
			issues = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('issues'), 'get', {:offset => offset})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					issues += res[:body]['issues'].map{|u| [u['id'], u['subject']]}
				end
			end

			issues.to_h
		end

		# Obtiene todos los proyectos del origen
		def self.get_projects(offset = 0)
			projects = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('projects'), 'get', {:offset => offset})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					projects += res[:body]['projects'].map{|u| [u['id'], u['name']]}
				end
			end

			projects.to_h
		end

		# Obtiene todos los proyectos del origen por identificador
		def self.get_projects_identifier(offset = 0)
			projects = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('projects'), 'get', {:offset => offset})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					projects += res[:body]['projects'].map{|u| [u['id'], u['identifier']]}
				end
			end

			projects.to_h
		end

		# Obtiene las imputaciones imputadas con fehca entre start_date y end_date
		def self.get_time_entries(start_date = nil, end_date = nil, offset = 0)
			start_date = start_date || Date.today
			end_date = end_date || Date.today
			time_entries = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('time_entries'), 'get', {:offset => offset, :spent_on => "><#{start_date}|#{end_date}"})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					time_entries += res[:body]['time_entries'].map{|te| {:id => te['id'], :issue_id => (te['issue'].present? ? te['issue']['id'] : nil), :project_id => te['project']['id'], :user => te['user']['id'], :spent_on => te['spent_on'], :activity_id => te['activity']['id'], :comments => te['comments'], :hours => te['hours'], :updated_on => te['updated_on']}}
				end
			end

			time_entries
		end

		# Obtiene las imputaciones imputadas de un proyecto/petición con fecha entre start_date y end_date
		def self.get_project_issue_time_entries(pr_is_id, data_type, start_date = nil, end_date = nil, offset = 0)
			start_date = start_date || Date.today
			end_date = end_date || Date.today
			time_entries = []
			total = 1
			while (offset < total)
				if data_type == 'Project'
					res = redmine_request(get_endpoint('time_entries'), 'get', {:offset => offset, :project_id => pr_is_id, :spent_on => "><#{start_date}|#{end_date}"})
				elsif data_type == 'Issue'
					res = redmine_request(get_endpoint('time_entries'), 'get', {:offset => offset, :issue_id => pr_is_id, :spent_on => "><#{start_date}|#{end_date}"})
				else
					res = nil
				end
						

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					time_entries += res[:body]['time_entries'].map{|te| {:id => te['id'], :issue_id => (te['issue'].present? ? te['issue']['id'] : nil), :project_id => te['project']['id'], :user => te['user']['id'], :spent_on => te['spent_on'], :activity_id => te['activity']['id'], :comments => te['comments'], :hours => te['hours'], :updated_on => te['updated_on']}}
				end
			end

			time_entries
		end

		def self.get_endpoint(action, id = nil)
			if Setting.plugin_redmine_synch_time_entries['protocol'].present? and Setting.plugin_redmine_synch_time_entries['domain'].present? #and Setting.plugin_redmine_synch_time_entries['key'].present?
				protocol = Setting.plugin_redmine_synch_time_entries['protocol']
				domain = Setting.plugin_redmine_synch_time_entries['domain'].gsub(/\/$/, '')
				path = action+(id.present? ? '/'+id : '')+'.json'

				return protocol+"://"+domain+'/'+path
			else
				return nil
			end
		end

		def self.redmine_request(url, method, parameters = {})
			begin
				parameters[:limit] = LIMIT
				if url.present?
				    uri = URI.parse(url)

				    case method
				       when 'get'
				       	req = Net::HTTP::Get.new(url+"?"+parameters.to_query)
				       # when 'post'
				       # 	req = Net::HTTP::Post.new(url)
				       # 	req.set_form_data(parameters)
				       # when 'put'
				       # 	req = Net::HTTP::Put.new(url)
				       # 	req.set_form_data(parameters)
				       # when 'delete'
				       # 	req = Net::HTTP::Delete.new(url+"?"+parameters.to_query)
				    end

				    if Setting.plugin_redmine_synch_time_entries['key'].present?
				    	req.basic_auth Setting.plugin_redmine_synch_time_entries['key'], ''
					end

				    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
				      	http.request(req)
				    end

				    code = res.code
				    result = (res.code.to_i >= 200 and res.code.to_i < 300) or (res.code.to_i == 304)
				    body = res.body.present? ? JSON.parse(res.body.force_encoding('UTF-8')) : {}
				else
					code = 404
					result = false
					body = {}
				end
			rescue
				code = 503
				result = false
				body = {}
			end

		    {:code => code, :result => result, :body => body}
		end

		# Obtiene todos los proyectos del origen en un árbol
		def self.generate_project_tree(offset = 0)
			projects = []
			total = 1
			while (offset < total)
				res = redmine_request(get_endpoint('projects'), 'get', {:offset => offset})

				if res[:result]
					total = res[:body]['total_count']
					offset += res[:body]['limit']
					projects += res[:body]['projects'].map{|u| {id: u['id'], name: u['name'], parent_id: u['parent'].present? ? u['parent']['id'] : nil}}
				end
			end

			tree = {}

			projects.each do |project|
				current = tree.fetch(project[:id]) { |key| tree[key] = {} }
  				parent = tree.fetch(project[:parent_id]) { |key| tree[key] = {} }
  				siblings = parent.fetch(:children) { |key| parent[key] = [] }

  				current[:parent] = project[:parent_id]
  				siblings.push(project[:id])
			end

			tree
		end

		def self.get_project_relations_tree(project_relations, offset = 0)
			tree = generate_project_tree(offset)

			project_relations_tree = []

			project_relations.map do |k|
				project_relations_tree.push({id: k.source_id, descendants: get_tree_descendants(tree, tree[k.source_id].present? ? tree[k.source_id][:children] : [])})
			end

			project_relations_tree
		end

		def self.get_tree_descendants(tree, children, descendants = [])
			if children.present?
				descendants |= children
				descendants |= (children.map{ |c| get_tree_descendants(tree, tree[c][:children], descendants)}).flatten
			else
				descendants
			end
			#children.present? ? children |= (children.map{ |c| get_tree_descendants(tree, tree[c][:children])}).flatten : children
		end
	end
end
