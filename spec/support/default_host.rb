RSpec.configure do |config|
  config.before(:each, type: :request) do
    if respond_to?(:host!)
      host! '127.0.0.1'
    end
  end
end
