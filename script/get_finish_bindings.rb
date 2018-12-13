require 'watir'
require 'headless'

headless = Headless.new
headless.start

browser = Watir::Browser.new :firefox

browser.goto 'https://digi.kansalliskirjasto.fi/sanomalehti/titles/0785-398X?display=CALENDAR&year=1825'
elements = browser.elements(css: 'td[ng-reflect-ng-class="binding"]').each {|e| puts e.xpath('//a')}
puts elements

browser.close
headless.destroy