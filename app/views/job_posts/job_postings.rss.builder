#encoding: UTF-8

xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "emsi services showing jobs related to #{@q}"
    xml.author "emsiservices"
    xml.description "emsi services showing jobs related to #{@q} for duration #{@start} to #{@end}"
    xml.link "http://emsiservices.com"
    xml.language "en"
    for jobpost in @jobposts
      xml.item do
        xml.cityname jobpost['city_name']
        xml.body jobpost['body']
        xml.company_name jobpost['company_name']
        xml.onet jobpost['onet']
        xml.raw_title jobpost['raw_title']
        xml.title jobpost['title_name']
        xml.link "http://google.com"
        xml.yearmonth jobpost['yearmonth']
      end
    end
  end
end