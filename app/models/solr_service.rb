class SolrService

  @@connection = false

  def self.connect
    #TODO Read Solr URI from BL config yml file
    @@connection = RSolr.connect(url: Rails.configuration.newseye_services['annotations_endpoint'])
    @@connection
  end

  def self.add(params)
    connect unless @@connection
    @@connection.add(params)
  end

  def self.commit
    connect unless @@connection
    @@connection.commit
  end

  def self.delete_by_id(id)
    connect unless @@connection
    @@connection.delete_by_id(id)
  end

  def self.search_all
    connect unless @@connection
    response = @@connection.get 'select', :params => {
        q: '*:*'
    }
  end

  def self.search(target, level)
    connect unless @@connection
    response = @@connection.get 'select', :params => {
        q: "target:\"#{target}\" AND level:\"#{level}\"",
        rows: 1000000,
        wt: 'json'
    }
  end

  def self.get_by_id(id)
    connect unless @@connection
    response = @@connection.get 'select', :params => {
        q: "id:\"#{id}\"",
        rows: 1,
        wt: 'json'
    }
  end

end
