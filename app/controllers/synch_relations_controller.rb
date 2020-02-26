class SynchRelationsController < ApplicationController
	layout 'admin'
	before_filter :require_admin
	before_filter :get_type, :only => [:new, :edit]
    before_filter :get_source, :only => [:new, :edit]
	before_filter :get_target, :only => [:new, :edit]
    before_filter :get_relation, :only => [:edit, :destroy, :update]

    include SynchRelationsHelper

	def index
        respond_to do |format|
            format.html
            format.csv { send_data(synch_relations_to_csv(SynchRelation.where(data_type: get_type)), :type=>'text/csv; header=present', :filename => 'synch_' + get_type.downcase + 's_relations.csv') }
        end
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

    # Borra las imputaciones sincronizados de los últimos meses
    def clear_synch(offset_months = 3)
        start_date = Date.today - offset_months.months
        end_date = Date.today
        deleted_time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ?", start_date, end_date)
        deleted_time_entries_relations.each do |te_relation|
            if te_relation.time_entry.present?
                te_relation.time_entry.delete
            end
            te_relation.delete
        end
    end

    # Realiza la sincronización manual de las imputaciones de horas del origen con las del destino
    def perform_manual_synch
        offset_months = params[:number_of_months_ago].present? ? params[:number_of_months_ago].to_i : 3
        if params[:clear_synch].present?
            begin
                clear_synch(offset_months)
                flash[:notice] = l(:notice_successful_delete)
            rescue
                flash[:error] = l(:notice_unable_delete_time_entry)
            end
        else
            begin
                result_update = []
                result_create = []

                user_relations = SynchRelation.where(data_type: 'User')
                issue_relations = SynchRelation.where(data_type: 'Issue')
                project_relations = SynchRelation.where(data_type: 'Project')
                project_relations_tree = SynchTimeEntries::Source.get_project_relations_tree(project_relations)
                start_date = Date.today - offset_months.months
                end_date = Date.today
                time_entries = []
                issue_relations.each do |ir|
                    time_entries += SynchTimeEntries::Source.get_project_issue_time_entries(ir.source_id, ir.data_type, start_date, end_date)
                end
                project_relations_tree.each do |pr|
                    time_entries += SynchTimeEntries::Source.get_project_issue_time_entries(pr[:id], 'Project', start_date, end_date)
                    pr[:descendants].each do |id|
                        time_entries += SynchTimeEntries::Source.get_project_issue_time_entries(id, 'Project', start_date, end_date)
                    end
                end
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
                            SynchTimeEntryRelation.create({source_id: te[:id], target_id: time_entry.id, last_update: te[:updated_on], spent_on: te[:spent_on]}) if time_entry.id.present?
                        end
                    end
                end

                deleted_time_entries_relations = SynchTimeEntryRelation.where("spent_on BETWEEN ? AND ? AND source_id NOT IN (?)", start_date, end_date, time_entries.map{|te| te[:id]})
                deleted_time_entries_relations.each do |te_relation|
                    te_relation.time_entry.present? ? te_relation.time_entry.delete : te_relation.delete
                end
                flash[:notice] = l(:'synch_time_entries.notice_successful_synch')
            rescue
                flash[:error] = l(:'synch_time_entries.error_synch_failed')
            end
        end
        redirect_to synch_relations_path
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
                @target = Project.all.order(:identifier)
                @name_field = 'identifier'
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
			    SynchTimeEntries::Source.get_projects_identifier
			end
        end
end