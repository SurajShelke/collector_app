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

SourceTypeConfig.create!(
  source_type_id: "6b3d4393-fe52-43f9-898d-f4894f3bf7ed",
  source_type_name: "safari_books_online_public",
  values: {
    'ecl_client_id' => "Ej4bAsuYiw",
    'ecl_token' => "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6IkVqNGJBc3VZaXciLCJlbWFpbCI6Im5pbGVzaF9uYXZhbGVAcGVyc2lzdGVudC5jby5pbiJ9.t2Tm0-jlF21kBiNpsRmDbpLUQmp8K5qoWviJqbz0bvg"
  }
)

SourceTypeConfig.create!(
  source_type_id: 'cd5cc64d-46a6-4987-8851-a5905c71faf4',
  source_type_name: 'success_factor',
  values: {
    'ecl_client_id' => 'Y96ZRvXXjA',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6Ilk5NlpSdlhYakEiLCJlbWFpbCI6ImRhcnNoYW5fcGF0ZWxAcGVyc2lzdGVudC5jby5pbiJ9.bF638d7ZPiaXTSMZiEb4HgyOEhDN28zS-wXoRDtfa3U',
    'host_url' => 'https://tata-stage.plateau.com',
    'user_id' => 'edcast',
    'company_id' => 'tata',
    'company_name' => 'TATACommQA',
    'client_id' => 'tata',
    'client_secret' => '5f6841c490227dcb438fdc80c5227b5850881a0575ac52c0b88c679e40337d97'
  }
)

SourceTypeConfig.create!(
  source_type_id: 'a9a55b7e-3d1a-4908-a509-065bf1b2844b',
  source_type_name: 'bright_cove',
  values: {
    'ecl_client_id' => 'mF335fGMbw',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6Im1GMzM1ZkdNYnciLCJlbWFpbCI6InZpbmF5X2d1cHRhMUBwZXJzaXN0ZW50LmNvLmluIn0.xyjdJqKPaTwHTu_RlHTeWFhzI4YBO9h0tmVs0kp6fdE',
    'client_id' => '970cf4a1-5152-4d8f-8bd1-bd65b342e136',
    'client_secret' => 'fA_XW9de2N801Lx4Fg2jXxO6W54YvwZE8t1x4TC4v24QV06LdZne9GdkzX2z68MNbJaqsqxv9h_C93ykRUTDcQ',
    'account_id' => '5762013514001'
  }
)

SourceTypeConfig.create!(
  source_type_name: 'edutube',
  source_type_id: 'a08b4e04-e11e-4286-91c2-5b115e9c8e8a',
  values: {
    'ecl_client_id' => 'Ah16kvsMyw',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6IkFoMTZrdnNNeXciLCJlbWFpbCI6InlvZ2VuZHJhQGVkY2FzdC5jb20ifQ.Fm838Eh05y6i8zqkJDLLJJx9w05O9SCE3KudVzfQdsU',
    'client_id' => 'eduTubeedcast',
    'client_secret' => 'eduTubeedcast!23',
    'host' => 'https://edutubestg.emc.com',
    'API_Key' => 'FA0ED0DD-1A7C-4603-B6C3-3A0987C6E050'
  }
)

SourceTypeConfig.create!(
  source_type_name: 'intuition',
  source_type_id: '2a2c63ea-ad8c-4242-9b74-bffc927b7d41',
  values: {
    'ecl_client_id' => 'Y96ZRvXXjA',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6Ilk5NlpSdlhYakEiLCJlbWFpbCI6ImRhcnNoYW5fcGF0ZWxAcGVyc2lzdGVudC5jby5pbiJ9.bF638d7ZPiaXTSMZiEb4HgyOEhDN28zS-wXoRDtfa3U',
    'organisationCode' => 'edcast',
    'password' => '1ntuition!123',
    'userName' => 'johnotoole',
    'host' => 'https://api.intuition.com'
  }
)

SourceTypeConfig.create!(
  source_type_name: 'hbr_ascend',
  source_type_id: '73045cb4-d99b-4ef4-9cfa-44a594c85d6e',
  values: {
    'ecl_client_id' => 'Ah16kvsMyw',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6IkFoMTZrdnNNeXciLCJlbWFpbCI6InlvZ2VuZHJhQGVkY2FzdC5jb20ifQ.Fm838Eh05y6i8zqkJDLLJJx9w05O9SCE3KudVzfQdsU'
  }
)

SourceTypeConfig.create!(
  source_type_name: 'mettl',
  source_type_id: '73045cb4-d99b-4ef4-9cfa-44a594c85d6e',
  values: {
    'ecl_client_id' => 'Ah16kvsMyw',
    'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6IkFoMTZrdnNNeXciLCJlbWFpbCI6InlvZ2VuZHJhQGVkY2FzdC5jb20ifQ.Fm838Eh05y6i8zqkJDLLJJx9w05O9SCE3KudVzfQdsU'
  }
)