module DatasetsHelper

  def classify_searches searches
    docs = []
    srchs = []
    searches.each do |search|
      if search.include? '/catalog/'
        docs.append search
      elsif search.include? '/catalog?'
        srchs.append search
      end
    end
    return {docs: docs, searches: srchs}
  end

end
