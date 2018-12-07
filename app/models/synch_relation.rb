class SynchRelation < ActiveRecord::Base
	belongs_to :target, polymorphic: true, :foreign_type => :data_type

	# Determina, para cada tipo de elemento, el campo que se va a mostrar en la configuración para identificarlo
	def target_name
		case data_type
		when 'Issue'
			return target.subject
		when 'Project'
			return target.name
		when 'User'
			return target.login
		end
	end

	def new
	end

end