class CurationsController < ApplicationController
  before_filter :login_required, except: [:index, :researcher, :show, :search]
  def index
    if current_user && current_user.admin?
      @curations = Curation.paginate(:page => params[:page], :per_page => 20, :order => "id desc")
    else
      @curations = Curation.where("privatized = 0 and status != 'hidden'").paginate(:page => params[:page], :per_page => 20, :order => "id desc")
    end
    @page_title = "Datasets"
  end
  
  def search
    @curations = []
    if params[:hidden]
      @curations = Curation.where(:status => "hidden", :researcher_id => params[:researcher_id]).paginate(:page => params[:page], :per_page => 20, :order => "id desc")
    elsif params[:analytic_id]
      @analytical_offering = AnalyticalOffering.find(params[:analytic_id])
      @curations = Curation.where(:privatized => false, :id => AnalysisMetadata.where(:analytical_offering_id => params[:analytic_id]).collect(&:curation_id)).paginate(:page => params[:page], :per_page => 20, :order => "id desc")
      @criteria = "Uses Analytic: #{@analytical_offering.title}"
    elsif params[:tag_id]
      @tag = Tag.find(params[:tag_id])
      @curations = Curation.where(:privatized => false, :id => @tag.curations.collect(&:id)).paginate(:page => params[:page], :per_page => 20, :order => "id desc")
      @criteria = "Tagged with: #{@tag.value}"
    end
    @page_title = "Search"
  end
  
  def researcher
    @researcher = Researcher.find_by_user_name(params[:user_name])
    @curations = @researcher.curations
    @page_title = "#{@researcher.user_name}'s Datasets"
  end
  
  def show
    @curation = Curation.find_by_id(params[:id])
    @curation.touch if !["needs_drop", "dropped"].include?(@curation.status)
    @tags = @curation.tags
    @tag = Tag.new
    @page_title = "#{@curation.researcher.user_name}'s #{@curation.name} Dataset"
  end

  def new
    @curation = Curation.new
    @researcher = Researcher.find(current_user.id)
    @page_title = "New Dataset"
  end

  def create
    success = ""
    if !curation_is_same?
      @curation = Curation.new
      @datasets = []
      @curation.created_at = Time.now
      @curation.updated_at = @curation.created_at
      @curation.privatized = !params[:privatized].nil?
      @curation.status = "tsv_storing"
      @curation.single_dataset = false
      empty = params[:name].empty? || params[:name].nil?
      name = empty ? (params[:params]||params[:terms]||params[:users]) : params[:name]
      @curation.name = name || params[:params]
      @curation.researcher_id = session[:researcher_id]
      if params[:stream_type] =~ /^locations?/i
        d = Dataset.new
        d.scrape_type = "locations"
        coords = params[:params].split(",").collect(&:to_f)
        north = coords[1] > coords[3] ? coords[1] : coords[3]
        south = coords[1] > coords[3] ? coords[3] : coords[1]
        east = coords[0] > coords[2] ? coords[0] : coords[2]
        west = coords[0] > coords[2] ? coords[2] : coords[0]
        d.params = "#{west},#{south},#{east},#{north},#{params[:end_time]}"
        d.status = "tsv_storing"
        d.instance_id = nil
        d.created_at = Time.now
        d.updated_at = Time.now
        d.save!
        @datasets << d
      elsif params[:stream_type] =~ /^terms?/i
        params[:terms].split(",").each do |term|
          d = Dataset.new
          d.scrape_type = "track"
          d.params = "#{term},#{params[:end_time]}"
          d.status = "tsv_storing"
          d.instance_id = nil
          d.created_at = Time.now
          d.updated_at = Time.now
          d.save!
          @datasets << d
        end
      elsif params[:stream_type] =~ /^users?/i
        params[:users].split(",").each do |user|
          d = Dataset.new
          d.scrape_type = "follow"
          d.params = "#{Twit.client.user(user).id},#{user},#{params[:end_time]}"
          d.status = "tsv_storing"
          d.instance_id = nil
          d.created_at = Time.now
          d.updated_at = Time.now
          d.save!
          @datasets << d          
        end
      end
      @curation.save!
      @datasets.collect{|d| d.curations << @curation}
      success = "Dataset successfully created. We're collecting your tweets!"
    else
      @datasets = @curation.datasets
      success = "Sorry, You can't actually add a new dataset until your identical one is finished streaming."
    end
    redirect_to dataset_url(@curation), flash: { success:  success}
  end

  def alter
    #this could probably be done in a much better way.
    @curation = Curation.find(params[:id])
    dataset = @curation.datasets.first
    params[:name] = @curation.datasets.collect{|x| x.params.split(",").first}.join(",")
    case params[:stream_type]
    when "location"
      params[:end_time] = dataset.params.split(",").last.to_i
    when "track"
      params[:end_time] = dataset.params.split(",").last.to_i
    end
    @curation.datasets.collect{|d| d.destroy}
    @curation.destroy
  end
  
  def verify
    @researcher = Researcher.find(session[:researcher_id])
    @curation = Curation.find(params[:id])
    @curation.created_at = Time.now.utc
    @curation.updated_at = @curation.created_at
    @curation.save!
    @curation.datasets.update_all(:created_at => Time.now.utc, :updated_at => Time.now.utc, :instance_id => nil)
    redirect_to researcher_url(@researcher), :notice => "We're running your streams!"
  end
  
  def import
    @curation = Curation.find(params[:id])
    @curation.status = "needs_import"
    @curation.save!
    redirect_to dataset_path(@curation), :notice => "We're Importing the data now!"
  end
  
  def analyze
    @curation = Curation.find(params[:id])
    @researcher = Researcher.find(session[:researcher_id])
    @applied_analytical_offerings = AnalyticalOffering.already_applied(@curation)
    @analysis_metadatas = @curation.analysis_metadatas.paginate(:page => params[:analysis_page], :per_page => 10)
    @analytical_offerings = AnalyticalOffering.available_to_researcher(@researcher)-@applied_analytical_offerings
  end
    
  def archive
    @curation = Curation.find(params[:id])
    @curation.status = "needs_drop"
    @curation.datasets.update_all(:status => "needs_drop")
    @curation.save!
    redirect_to dataset_path(@curation), :notice => "Data has been sent off for a deep freeze."
  end
  
  def new_term
    respond_to do |format|
      format.js# { render :template => 'curations/form', :layout => false, :stream_type => 'terms' }
    end
  end
  def new_location
    respond_to do |format|
      format.js# { render :template => 'curations/form', :layout => false, :stream_type => 'location' }
    end
  end
  def destroy
    @curation = Curation.find(params[:id])
    if @curation && current_user && (@curation.researcher_id == current_user.id || current_user.admin?)
      @curation.datasets.each do |dataset|
        dataset.destroy
      end
      @curation.destroy
      redirect_to dashboard_path(current_user), :success => "All good!"
    elsif @curation.nil?
      redirect_to datasets_path, :notice => "Hrm... You tried to delete a curation we couldn't find. Weirdness."
    else
      redirect_to datasets_path, :notice => "Hrm... You tried to delete a curation but don't have the permission to delete it."
    end
  end
  
  def validate_users
    users = params[:screen_names].split(",")
    cleaned_users = []
    users.each do |user|
      begin
        client = Twit.client
        cleaned_users << client.user(user).screen_name
      rescue
        next
      end
    end
    @researcher = Researcher.find(current_user.id)
    maximum = Setting.find_by_name_and_var_type("maximum_user_search", @researcher.role).actual_value-1
    render :text => cleaned_users[0..maximum].join(",")
  end
  

  private

  def curation_is_same?
    @curation = Curation.find_by_name_and_researcher_id_and_status(params[:name], session[:researcher_id], "tsv_storing")
    result = @curation && 
             @curation.datasets.collect{|d| d.params.split(",").first}.sort == params[:name].split(",").sort && 
             @curation.datasets.first.params.split(",").last.to_i == params[:end_time].to_i
    return result
  end
  
end
