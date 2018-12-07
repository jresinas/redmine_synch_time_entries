class SynchRelationsController < ApplicationController
	layout 'admin'
	before_filter :require_admin
	before_filter :get_type, :only => [:new, :edit]
    before_filter :get_source, :only => [:new, :edit]
	before_filter :get_target, :only => [:new, :edit]
    before_filter :get_relation, :only => [:edit, :destroy, :update]

	def index
	end

	def new
		@relation = SynchRelation.new
	end

	def edit

	end

    def destroy
        if @relation.destroy
            flash[:notice] = l(:"synch_time_entries.text_delete_notice_success")
            redirect_to synch_relations_path
        else
            flash[:error] = l(:"synch_time_entries.text_delete_notice_fail")
            redirect_to action: 'new', :type => @relation.data_type
        end
    end

	def create
		relation = SynchRelation.new synch_relation_params

        if relation.save
            flash[:notice] = l(:"synch_time_entries.text_create_notice")
            if params[:continue]
                redirect_to action: 'new', :type => params[:synch_relation][:data_type]
            else
                redirect_to synch_relations_path
            end
        else
            flash[:error] = relation.errors.full_messages.join('<br>').html_safe
            redirect_to action: 'new', :type => params[:synch_relation][:data_type]
        end
	end

    def update
        if @relation.update_attributes synch_relation_params  
            flash[:notice] = l(:"synch_time_entries.text_update_notice")
            redirect_to synch_relations_path
        else
            flash[:error] = @relation.errors.full_messages.join('<br>').html_safe
            redirect_to action: 'edit', :id => params[:synch_relation][:id], :type => params[:synch_relation][:data_type]
        end
    end

    # Muestra el asunto de la petición del origen con el id solicitado
    def get_source_subject
        if params[:id]
            issue = SynchTimeEntries::Source.get_issue(params[:id])
            
            render :text => issue['issue']['subject'] if issue.present?
        end
    end

    # Muestra el asunto de la petición del destino con el id solicitado
    def get_target_subject
        if params[:id]
            issue = Issue.find(params[:id])
            
            render :text => issue.subject if issue.present?
        end
    end

	private
        def synch_relation_params
            params.require(:synch_relation).permit(:source_id, :source_name, :target_id, :data_type)
        end

        def get_relation
            @relation = SynchRelation.find(params[:id]) if params[:id].present?
        end

        # Obtiene el tipo de elemento que se está modificando (users, projects o issues)
        def get_type
			@type = params[:type].present? ? params[:type] : nil
        end

        # Obtiene los datos del destino necesarios (para usuarios y proyectos)
        def get_target
            case @type
            when 'User'
                @target = User.all.order(:login)
                @name_field = 'login'
            when 'Project'
                @target = Project.all.order(:name)
                @name_field = 'name'
            end
        end 

        # Obtiene los datos del origen necesarios (para usuarios y proyectos)
        def get_source
            case @type
            when 'User'
                get_source_users
            when 'Project'
                get_source_projects
            end
        end

        # Obtiene todos los usuarios del origen y los cachea durante los minutos establecidos en la configuración
        def get_source_users
        	minutes_cache = Setting.plugin_redmine_synch_time_entries['minutes_cache'].present? ? Setting.plugin_redmine_synch_time_entries['minutes_cache'] : 10
        	@source = Rails.cache.fetch(:source_users, :expires_in => (minutes_cache.to_i).minutes) do
			    SynchTimeEntries::Source.get_users
			end
        end

        # Obtiene todos los proyectos del origen y los cachea durante los minutos establecidos en la configuración
        def get_source_projects
        	minutes_cache = Setting.plugin_redmine_synch_time_entries['minutes_cache'].present? ? Setting.plugin_redmine_synch_time_entries['minutes_cache'] : 10
        	@source = Rails.cache.fetch(:source_projects, :expires_in => (minutes_cache.to_i).minutes) do
			    SynchTimeEntries::Source.get_projects
			end
        end
end