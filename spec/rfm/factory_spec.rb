require 'spec_helper'
describe Rfm::Factory::ServerFactory do  
  subject {Rfm::Factory::ServerFactory.new}
  describe '#[]' do
    it "creates or retrieves server object, given host & options" do
      server = subject['test-host', {:layout=>'test-layout-one'}]
      expect(server.host_name).to eq('test-host')
      expect(server.state[:layout]).to eq('test-layout-one')
    end
  end
end # Rfm::Factory::ServerFactory


describe Rfm::Factory do

  subject        {Rfm::Factory}
  #let(:config)   {subject.instance_variable_get :@config}
  #let(:klass)    {Class.new{extend Rfm::Config; @config={:parent=>'Rfm::Config'}}}

  it "sets @config with :parent=>'Rfm::Config' upon loading" do
    expect(subject.config).to eq({:parent=>'Rfm::Config'})
  end

  describe '.server' do
    it "returns Rfm::Server instance, given name, filters, options hash" do
      server = subject.server('test-host-one', :group1, :ssl=>'test')
      expect(server.host_name).to eq('test-host-one')
      expect(server.state[:host]).to eq('test-host-one')
      expect(server.state[:database]).to eq('db1')
      expect(server.state[:ssl]).to eq('test')
    end
  end

  describe '.db' do
    it "returns Rfm::Database instance, given name, filters, options hash" do
      database = subject.db('test-db-name', :group1, :account_name=>'my-name')
      expect(database.name).to eq('test-db-name')
      expect(database.account_name).to eq('my-name')
    end
  end

  describe '.layout' do
    it "returns Rfm::Layout instance, given name, filters, options hash" do
      layout = subject.layout('test-layout-name', :group1, :account_name=>'my-name')
      expect(layout.name).to eq('test-layout-name')
      expect(layout.db.name).to eq('db1')
      expect(layout.db.account_name).to eq('my-name')
    end
  end

end # Rfm::Factory
