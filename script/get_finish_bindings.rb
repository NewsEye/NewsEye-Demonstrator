require 'open-uri'
require 'json'

listfile = '/home/axel/Nextcloud/NewsEye/data/nlf_np.txt'
nps = open(listfile, 'r').read
nps.split("\n").each do |np|
  np = np[2..-1]
  daterange = np[np.rindex(' ', np.rindex(' '))..-1].strip
  id = np[np.rindex(' ', np.rindex(' ')-1)..np.rindex(' ')].strip[1...-1]
  title = np[0..np.rindex(' ', np.rindex(' ')-1)].strip
  (daterange[0...4]..daterange[5..-1]).each do |year|
    # url = "https://digi.kansalliskirjasto.fi/sanomalehti/titles/#{id}?display=CALENDAR&year=#{year}"
    # session.visit url
    # elements = session.find_all('td[ng-reflect-ng-class~="binding"] a')
    # puts "#{elements.size} issues to download"
    url = "https://digi.kansalliskirjasto.fi/rest/serial-publication/calendar/#{id}/year/#{year}"
    puts "#{title} : #{year}, #{url}"
    data = JSON.parse(open(url).read)
    bindings = []
    data['months'].each do |month|
      month['weeks'].each do |week|
        week['days'].each do |day|
          if day
            day['bindings'].each do |binding|
              bindings << binding['id']
            end
          end
        end
      end
    end
    puts "#{bindings.size} issues to download"
    open("/home/axel/Nextcloud/NewsEye/data/nlf_#{id}.txt", 'a') do |f|
      bindings.each { |e| f.write "#{e}\n" }
    end
  end
end
