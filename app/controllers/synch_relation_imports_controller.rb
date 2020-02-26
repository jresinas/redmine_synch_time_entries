require 'csv'

class SynchRelationImportsController < ImportsController
  layout 'admin'
  before_filter :require_admin
  before_filter :get_data_type, :only => [:new, :create, :settings]

  def create
    @import = SynchRelationImport.new
    @import.user = User.current
    @import.file = params[:file]
    @import.set_default_settings
    @import.settings['data_type'] = params[:type]

    if @import.save
      redirect_to synch_relation_import_settings_path(@import)
    else
      render :action => 'new'
    end
  end

  def settings
    if request.post? && @import.parse_file
      redirect_to synch_relation_import_mapping_path(@import)
    end

  rescue CSV::MalformedCSVError => e
    flash.now[:error] = l(:error_invalid_csv_file_or_settings)
  rescue ArgumentError, Encoding::InvalidByteSequenceError => e
    flash.now[:error] = l(:error_invalid_file_encoding, :encoding => ERB::Util.h(@import.settings['encoding']))
  rescue SystemCallError => e
    flash.now[:error] = l(:error_can_not_read_import_file)
  end

  def mapping
    synch_relation = SynchRelation.new
    @attributes = synch_relation.safe_attribute_names
    #@custom_fields = synch_relation.editable_custom_field_values.map(&:custom_field)

    if request.post?
      respond_to do |format|
        format.html {
          if params[:previous]
            redirect_to synch_relation_import_settings_path(@import)
          else
          	if params[:delete_existing_synch_relations].present? and params[:delete_existing_synch_relations] == 'yes'
          		SynchRelation.where(data_type: get_data_type).destroy_all
          	end
            redirect_to synch_relation_import_run_path(@import)
          end
        }
        format.js # updates mapping form on project or tracker change
      end
    end
  end

   # Obtiene el tipo de elemento que se está modificando (users, projects o issues)
  def get_data_type
  	if @import.present? and @import.settings.present? and @import.settings['data_type'].present?
  		@type = @import.settings['data_type']
  	elsif params[:type].present?
		@type = params[:type]
	else
		nil
	end
  end

  def run
    if request.post?
      @current = @import.run(
        :max_items => max_items_per_request,
        :max_time => 10.seconds
      )
      respond_to do |format|
        format.html {
          if @import.finished?
            redirect_to synch_relation_import_path(@import)
          else
            redirect_to synch_relation_import_run_path(@import)
          end
        }
        format.js
      end
    end
  end

end
