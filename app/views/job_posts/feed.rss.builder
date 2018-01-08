#encoding: UTF-8

xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "emsi services for edcast"
    xml.author "emsiservices"
    xml.description "emsi services for edcast"
    xml.link "http://emsiservices.com"
    xml.language "en"
    puts "#{@jobposts.inspect}"
    for jobpost in @jobposts
      xml.item do
        xml.title jobpost['name']
        xml.link "http://google.com"
        xml.designation jobpost['designation']
      end
    end
  end
end