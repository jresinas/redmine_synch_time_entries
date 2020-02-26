class SynchRelationImport < Import

	#Devuelve los objetos que han sido importados
	def saved_objects
		object_ids = saved_items.pluck(:obj_id)
		objects = SynchRelation.where(:id => object_ids).order(:id).preload(:target)
	end

	def data_type
  		settings.present? and settings['data_type'].present? ? settings['data_type'] : nil
  	end

	def allowed_source_items
		minutes_cache = Setting.plugin_redmine_synch_time_entries['minutes_import_cache'].present? ? Setting.plugin_redmine_synch_time_entries['minutes_import_cache'] : 10
		if data_type == 'User'
			Rails.cache.fetch(:source_users_import, :expires_in => (minutes_cache.to_i).minutes) do
				SynchTimeEntries::Source.get_users.sort_by {|_key, value| value}.to_h
			end
		elsif data_type == 'Project'
			Rails.cache.fetch(:source_projects_import, :expires_in => (minutes_cache.to_i).minutes) do
				SynchTimeEntries::Source.get_projects_identifier.sort_by {|_key, value| value}.to_h
			end
		end
	end

	def allowed_target_users
		User.all.order(:login)
	end

	def allowed_target_projects
		Project.all.order(:identifier)
	end

	def source_item_id(source_identifier=nil)
		if data_type == 'User' and allowed_source_items.has_value?(source_identifier)
	    	allowed_source_items.key(source_identifier)
		elsif data_type == 'Project' and allowed_source_items.has_value?(source_identifier)
	    	allowed_source_items.key(source_identifier)
		else
			nil
		end
  	end

  	def user(target_user_login=nil)
		allowed_target_users.find_by_login(target_user_login)
	end

	def project(target_project_identifier=nil)
	    allowed_target_projects.find_by_identifier(target_project_identifier)
  	end

  	def target_item_id(target_identifier=nil)
  		if data_type == 'User'
  			user(target_identifier).id
  		elsif data_type == 'Project'
  			project(target_identifier).id
  		end
  	end

  	def run(options={})
    max_items = options[:max_items]
    max_time = options[:max_time]
    current = 0
    imported = 0
    resume_after = items.maximum(:position) || 0
    interrupted = false
    started_on = Time.now

    read_items do |row, position|
      if (max_items && imported >= max_items) || (max_time && Time.now >= started_on + max_time)
        interrupted = true
        break
      end
      if position > resume_after
        item = items.build
        item.position = position

        if object = build_object(row)
          begin
	          if object.save
	            item.obj_id = object.id
	          else
	            item.message = object.errors.full_messages.join("\n")
	          end
	      rescue Exception => e
	      	item.message = e.message
	      end
        end

        item.save!
        imported += 1
      end
      current = position
    end

    if imported == 0 || interrupted == false
      if total_items.nil?
        update_attribute :total_items, current
      end
      update_attribute :finished, true
      remove_file
    end

    current
  end

	private

	def build_object(row)
		synch_relation = SynchRelation.new

		source_identifier = row_value(row, 'source_identifier')
		target_identifier = row_value(row, 'target_identifier')

		attributes = {
		  'source_id' => source_item_id(source_identifier),
		  'source_name' => source_identifier,
		  'target_id' => target_item_id(target_identifier),
		  'data_type' => data_type
		}
		synch_relation.send :safe_attributes=, attributes, user

		synch_relation
	end

end
