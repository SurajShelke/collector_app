# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

SourceTypeConfig.create!(
	source_type_id: "b2f91f47-b4a2-4dba-a6d1-050c6587b267",
	source_type_name: "one_drive",
	values: {
		'client_id' => "0138a21b-af37-47ee-9dad-c7f23fb5b2a6",
		'client_secret' => "lyoxNNFAU2651])nhhCA2<(",
		'ecl_client_id' => "Y96ZRvXXjA",
		'ecl_token' => "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6Ilk5NlpSdlhYakEiLCJlbWFpbCI6ImRhcnNoYW5fcGF0ZWxAcGVyc2lzdGVudC5jby5pbiJ9.bF638d7ZPiaXTSMZiEb4HgyOEhDN28zS-wXoRDtfa3U"
	}
)

SourceTypeConfig.create!(
	source_type_id: "8239476d-ec15-46cd-8297-942342d64d2f",
	source_type_name: "skill_soft",
	values: {
		'ecl_client_id' => "Y96ZRvXXjA",
		'ecl_token' => "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6Ilk5NlpSdlhYakEiLCJlbWFpbCI6ImRhcnNoYW5fcGF0ZWxAcGVyc2lzdGVudC5jby5pbiJ9.bF638d7ZPiaXTSMZiEb4HgyOEhDN28zS-wXoRDtfa3U"
	}
)