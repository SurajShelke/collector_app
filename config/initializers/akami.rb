module Akami
  class WSSE
    def to_xml
      if signature? and signature.have_document?
        Gyoku.xml wsse_signature.merge!(hash)
      elsif username_token? && timestamp?
        sec = wsse_username_token.merge!(wsu_timestamp) {
          |key, v1, v2| v1.merge!(v2) {
            |key, v1, v2| v1.merge!(v2)
          }
        }
        sec['wsse:Security'].merge! :order! =>['wsu:Timestamp','wsse:UsernameToken']
        Gyoku.xml sec
      elsif username_token?
        Gyoku.xml wsse_username_token.merge!(hash)
      elsif timestamp?
        Gyoku.xml wsu_timestamp.merge!(hash)
      else
        ""
      end
    end
  end
end