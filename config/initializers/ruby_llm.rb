RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] if ENV["ANTHROPIC_API_KEY"].present?
  config.gemini_api_key = ENV["GEMINI_API_KEY"] if ENV["GEMINI_API_KEY"].present?
  config.deepseek_api_key = ENV["DEEPSEEK_API_KEY"] if ENV["DEEPSEEK_API_KEY"].present?

  config.bedrock_api_key = ENV["AWS_ACCESS_KEY_ID"] if ENV["AWS_ACCESS_KEY_ID"].present?
  config.bedrock_secret_key = ENV["AWS_SECRET_ACCESS_KEY"] if ENV["AWS_SECRET_ACCESS_KEY"].present?
  config.bedrock_region = ENV["AWS_REGION"] if ENV["AWS_REGION"].present?
  config.bedrock_session_token = ENV["AWS_SESSION_TOKEN"] if ENV["AWS_SESSION_TOKEN"].present?
end
