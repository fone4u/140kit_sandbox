class GeoMap < AnalysisMetadata
  
  def self.run(analysis_metadata_id)
    @analysis_metadata = AnalysisMetadata.first(:id => analysis_metadata_id)
    curation = @analysis_metadata.curation
    conditional = Analysis.curation_conditional(curation)
    location_overview = Graph.first_or_create(:title => "location_overview", :tyle => "table", :analysis_metadata_id => @analysis_metadata.id, :curation_id => curation.id)
    graph_points = []
    tweet_count = Tweet.count(conditional)
    graph_points << {:label => "total_tweets", :value => tweet_count, :curation_id => curation.id, :graph_id => location_overview.id, :analysis_metadata_id => @analysis_metadata_id}
    geo_count = Geo.count(conditional)
    graph_points << {:label => "total_geos", :value => geo_count, :curation_id => curation.id, :graph_id => location_overview.id, :analysis_metadata_id => @analysis_metadata_id}
    coordinate_count = Coordinate.count(conditional)
    graph_points << {:label => "total_coordinates", :value => coordinate_count, :curation_id => curation.id, :graph_id => location_overview.id, :analysis_metadata_id => @analysis_metadata_id}
    graph_points << {:label => "proportion_geos", :value => geo_count/tweet_count.to_f, :curation_id => curation.id, :graph_id => location_overview.id, :analysis_metadata_id => @analysis_metadata_id}
    graph_points << {:label => "proportion_coordinates", :value => coordinate_count/tweet_count.to_f, :curation_id => curation.id, :graph_id => location_overview.id, :analysis_metadata_id => @analysis_metadata_id}
    country_map = Graph.first_or_create(:title => "country_map", :tyle => "map", :analysis_metadata_id => @analysis_metadata.id, :curation_id => curation.id)
    city_map = Graph.first_or_create(:title => "city_map", :tyle => "map", :analysis_metadata_id => @analysis_metadata.id, :curation_id => curation.id)
    offset = 0
    limit = 1000
    geos = DataMapper.repository.adapter.select("select count(*) as country_count, country from #{Analysis.conditions_to_mysql_query(conditional)} geos group by country limit #{limit} offset #{offset}")
    while !geos.empty?
      geos.each do |geo|
        graph_points << {:label => geo.country, :value => geo.country_count, :curation_id => curation.id, :graph_id => country_map.id, :analysis_metadata_id => @analysis_metadata_id}
      end
      offset += limit
      geos = DataMapper.repository.adapter.select("select count(*) as country_count, country from #{Analysis.conditions_to_mysql_query(conditional)} geos group by country limit #{limit} offset #{offset}")
    end
    GraphPoint.save_all(graph_points)
    graph_points = []
    geos = DataMapper.repository.adapter.select("select count(*) as full_name_count, full_name from geos #{Analysis.conditions_to_mysql_query(conditional)} group by full_name limit #{limit} offset #{offset}")
    while !geos.empty?
      geos.each do |geo|
        graph_points << {:label => geo.full_name, :value => geo.full_name_count, :curation_id => curation.id, :graph_id => country_map.id, :analysis_metadata_id => @analysis_metadata_id}
      end
      GraphPoint.save_all(graph_points)
      graph_points = []
      offset += limit
      geos = DataMapper.repository.adapter.select("select count(*) as full_name_count, full_name from geos #{Analysis.conditions_to_mysql_query(conditional)} group by full_name limit #{limit} offset #{offset}")
    end
  end
end