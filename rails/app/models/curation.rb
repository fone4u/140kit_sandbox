class Curation < ActiveRecord::Base
  belongs_to :researcher
  has_and_belongs_to_many :datasets, :join_table => "curation_datasets"
  has_many :analysis_metadatas
  has_many :graphs
  
  def self.max_time
    return 1.week
  end
  
  def self.default_time_series
    return 5.minutes
  end
  
  def self.default_step
    return 10.minutes
  end
  
  def current_status
    case self.status
    when "tsv_storing"
      return "Collecting"
    when "tsv_stored"
      return "Finishing collection"
    when "needs_import"
      return "Ready for analysis"
    when "imported"
      return "Analyzing"
    when "needs_drop"
      return "Finished analysis"
    when "dropped"
      return "Archived"
    else
      return "Unknown"
    end
  end
  
  def current_options
    #this is bad design, I know. It's just the first thing I thought of that could do this - problem is I'm not sure you can access a specific object from within model?
    case self.status
    when "tsv_storing"
      return "<a href='/datasets/#{self.id}/analyze'>Set Analytics</a>"
    when "tsv_stored"
      return "<a href='/datasets/#{self.id}/analyze'>Set Analytics</a> | <a href='/datasets/#{self.id}/import'>Bring it live</a>"
    when "needs_import"
      return "Sit tight..."
    when "imported"
      return "<a href='/datasets/#{self.id}/analyze'>Set Analytics</a> | <a href='/datasets/#{self.id}/archive'>Archive</a>"
    when "needs_drop"
      return "Sit tight..."
    when "dropped"
      return "<a href='/datasets/#{self.id}/analyze'>Set Analytics</a> | <a href='/datasets/#{self.id}/import'>Restore</a>"
    else
      return "Sit tight..."
    end
  end
  
end
