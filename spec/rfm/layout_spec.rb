require 'spec_helper'
describe Rfm::Layout do
  let(:server)   {(Rfm::Server).allocate}
  let(:database) {(Rfm::Database).allocate}
  #let(:data)     {File.read("spec/data/resultset.xml")}
  #let(:meta)     {File.read("spec/data/layout.xml")}
  let(:name)     {'test_layout'}
  let(:layout)   {Rfm::Layout.new(name, database)}
  before(:each) do
    allow(server).to receive(:state).and_return({})
    allow(database).to receive(:server).and_return(server)
    #data.stub!(:body).and_return(RESULTSET_XML)
    #meta.stub!(:body).and_return(LAYOUT_XML)
  end

  describe "#initialze" do
    it "should set configuration" do
      expect(layout.config[:layout]).to eq(name)
      expect(layout.config[:parent]).to eq(database)
      expect(layout.instance_variable_get(:@loaded)).to eq(false)
    end
  end # initialize

  describe "#get_records" do
    before(:each) do
      allow(Rfm::Connection).to receive(:new).and_return(Rfm::Connection.allocate)
      allow_any_instance_of(Rfm::Connection).to receive(:parse).and_return(Rfm::Resultset.allocate)
      allow_any_instance_of(Rfm::Layout).to receive(:capture_resultset_meta)
    end

    it "calls Connection.new with action, params, and options" do
      expect(Rfm::Connection).to receive(:new) { |*args|
        expect(args[0]).to eq("-find")
        expect(args[1]).to eq({"-db" => nil, "-lay" => name, :prms=>'test'})
        expect(args[2]).to eq({:opts=>'test'})
      }.and_return(Rfm::Connection.allocate)
      expect(layout).to receive(:capture_resultset_meta)

      layout.send :get_records, "-find", {:prms=>'test'}, {:opts=>'test'}
    end


    it "calls connection.parse with parameters" do
      expect_any_instance_of(Rfm::Connection).to receive(:parse) do |instance, *args|
        expect(args[0]).to eq(:fmresultset)
        expect(args[1].class).to eq(Rfm::Resultset)
      end
      layout.send(:get_records, '-find', {:prms=>'tst'}, {:opts=>'tst', :template=>:fmresultset})
    end

    it "returns instance of Resultset" do
      expect(layout.send(:get_records, '-find', {:prms=>'tst'}, {:opts=>'tst'}).class).to eq(Rfm::Resultset)
    end

    it "translates field names, given field-translation map" do
      layout.config :field_mapping => {'userName' => 'login'}

      expect(Rfm::Connection).to receive(:new) { |*args|
        expect(args[1].has_key?('login')).to be_falsey
        expect(args[1].has_key?('username')).to be_truthy
        expect(args[1]['username']).to eq('bill')
      }.and_return(Rfm::Connection.allocate)
      expect(layout.field_mapping['userName']).to eq('login')

      layout.send(:get_records, '-find', {'login'=>'bill'})
    end

    it "builds repeating-field query params from repeating-field array" do      
      expect(Rfm::Connection).to receive(:new) { |*args|
        expect(args[1].has_key?('repeating')).to be_falsey
        expect(args[1].has_key?('repeating(1)')).to be_truthy
        expect(args[1].has_key?('repeating(3)')).to be_truthy
        expect(args[1]['repeating(3)']).to eq('bill')
      }.and_return(Rfm::Connection.allocate)

      layout.send(:get_records, '-edit', {'repeating'=>['mike','amy','bill']})
    end

  end #get_records

  describe "#load_layout" do
    it "loads layout meta with field_controls" do
      # This is now handled in spec_helper
      #Rfm::Connection.any_instance.stub(:connect).and_return LAYOUT_XML
      layout.send(:load_layout)
      expect(layout.field_controls.has_key?('stayid')).to be_truthy
    end

    it "loads layout meta with value_lists" do
      # This is now handled in spec_helper
      #Rfm::Connection.any_instance.stub(:connect).and_return LAYOUT_XML
      layout.send(:load_layout)
      #puts layout.to_yaml
      expect(layout.value_lists.has_key?('employee unique id')).to be_truthy
    end
  end

  describe "#any" do
    it "returns resultset containing instance of Rfm::Record" do
      # This is now handled in spec_helper
      #Rfm::Connection.any_instance.stub(:connect).and_return(RESULTSET_XML)
      expect(layout.send(:any)[0].is_a?(Rfm::Record)).to be_truthy
    end
  end

  describe "#find" do

    context "when passed FMP internal record id" do
      it "sends -find action & -recid & record id to #get_records" do
        expect(layout).to receive(:get_records) do |action, query, options|
          expect(action).to eq('-find')
          expect(query['-recid']).to eq('54321')
        end
        layout.find(54321)      
      end
    end

    context "when passed plain hash" do
      it "sends -find action & plain hash to #get_records" do
        expect(layout).to receive(:get_records) do |action, query, options|
          expect(action).to eq('-find')
          expect(query[:memotext]).to eq('val1')
        end
        layout.find(:memotext=>'val1', :memosubject=>'val2')      
      end    
    end    

    context "when passed plain hash with multiple value options for at least one field" do
      it "sends -findquery action & compound find criteria to #get_records" do
        expect(layout).to receive(:get_records) do |action, query, options|
          expect(action).to eq('-findquery')
          expect(['(q0,q2);(q1,q2)','(q0,q1);(q0,q2)'].include?(query['-query'])).to be_truthy
        end
        layout.find(:memotext=>['one','two'], :memosubject=>'three')
      end
    end

    context "when passed array of hashes" do
      it "sends -findquery action & compound find criteria to #get_records" do
        expect(layout).to receive(:get_records) do |action, query, options|
          expect(action).to eq('-findquery')
          expect(['(q0,q2);(q1,q2);!(q3)','(q0,q1);(q0,q2);!(q3)'].include?(query['-query'])).to be_truthy
        end
        layout.find([{:memotext=>['one','two'], :memosubject=>'three'}, {:omit=>true, :memotext=>'test'}])
      end
    end
  end

  describe "#modelize" do
    before(:each){layout.modelize}

    it "creates model subclassed from Rfm::Base" do
      expect(layout.models[0]).to eq(Rfm::TestLayout)
      expect(layout.models[0].ancestors.include?(Rfm::Base)).to be_truthy
    end

    it "stores model in layout@model as constant based on layout name" do
      expect(layout.models[0]).to eq(Rfm::TestLayout)
    end

    it "sets model@layout with layout object" do
      expect(layout.models[0].layout).to eq(layout)
    end
  end


end # Rfm::Resultset
