Rails.application.config.middleware.use OmniAuth::Builder do
  provider :microsoft_v2_auth,
           ENV['CLIENT_ID'] || "0138a21b-af37-47ee-9dad-c7f23fb5b2a6",
					 ENV['CLIENT_SECRET'] || "lyoxNNFAU2651])nhhCA2<(",
           scope: ENV['OAUTH_SCOPE'] || "offline_access openid email profile https://graph.microsoft.com/User.Read https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/Files.Read.All https://graph.microsoft.com/Files.ReadWrite.All",
           redirect_uri: ENV['redirect_uri'] || 'http://localhost:3000/auth/microsoft_v2_auth/callback'
end