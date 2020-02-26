class SynchRelation < ActiveRecord::Base
	include Redmine::SafeAttributes
	belongs_to :target, polymorphic: true, :foreign_type => :data_type

	safe_attributes 'source_id', 'source_name', 'target_id', 'data_type'

	# Determina, para cada tipo de elemento, el campo que se va a mostrar en la configuración para identificarlo
	def target_name
		case data_type
		when 'Issue'
			return target.subject
		when 'Project'
			return target.identifier
		when 'User'
			return target.login
		end
	end

	def new
	end

	def safe_attributes=(attrs, user=User.current)
    	if attrs
      		attrs = super(attrs)
    	end
    	attrs
  	end

end