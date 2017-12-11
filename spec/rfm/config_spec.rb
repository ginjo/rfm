require 'spec_helper'
describe Rfm::Config do

  subject        {Rfm::Config}
  let(:config)   {subject.instance_variable_get :@config}
  let(:klass)    {Class.new{extend Rfm::Config}}

  describe "#config" do
    before(:each){klass.config :group1, :layout=>'lay1'}

    it "sets @config with arguments & options" do
      expect(klass.instance_variable_get(:@config)).to eq({:use=>:group1, :layout=>'lay1'})
    end

    it "returns @config" do
      expect(klass.config).to eq(klass.instance_variable_get(:@config))
    end

    it "passes strings to block if block given" do
      string_test = []
      klass.config('string1', 'string2', :group1, :group2, :layout=>'lay5'){|params| string_test = params[:strings]}
      expect(string_test).to eq(['string1', 'string2'])
    end
  end

  describe "#get_config" do

    context "with no arguments" do
      it "returns upstream config" do
        expect(klass.get_config).to eq({:host=>'host1', :strings=>[], :ignore_bad_data => true, :using=>[], :parents=>["file", "RFM_CONFIG"], :objects=>[]})
      end
    end

    context "with preset filters but no arguments" do
      it "returns upstream config, merged with filtered groups" do
        klass.config :group1
        expect(klass.get_config).to eq({:host=>'host1', :strings=>[], :database=>'db1', :using=>[:group1], :ignore_bad_data => true, :parents=>["file", "RFM_CONFIG"], :objects=>[]})
      end
    end

    context "with array of symbols and hash of options" do
      it "returns upstream config, merged with filtered groups, merged with options, merged with preset filters" do
        klass.config :group1
        expect(klass.get_config(:group2, :ssl=>true)).to eq({:host=>'host1', :strings=>[], :database=>'db2', :ssl=>true, :using=>[:group1, :group2], :ignore_bad_data => true, :parents=>["file", "RFM_CONFIG"], :objects=>[]})
      end

      it "returns config including :strings parameter, if passed array of strings as first n arguments" do
        klass.config :group1
        expect(klass.get_config('test-string-one', 'test-string-two', :group2, :ssl=>true)[:strings][1]).to eq('test-string-two')
      end

    end
  end

end # Rfm::Config
