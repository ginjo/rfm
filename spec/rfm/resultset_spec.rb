require 'spec_helper'
describe Rfm::Resultset do
  # These mocks were breaking the #initialize spec, but only when I added the Layout#modelize spec !?!?
  #   let(:server) {mock(Rfm::Server)}
  #   let(:layout) {mock(Rfm::Layout)}
  let(:server) {Rfm::Server.allocate}
  let(:layout) {Rfm::Layout.allocate}
  let(:data)   {File.read("spec/data/resultset.xml")}
  let(:bad_data) {File.read("spec/data/resultset_with_bad_data.xml")}
  subject      {Rfm::Resultset.new(data, layout, :server_object=>server)}
  before(:each) do
    allow(server).to receive(:state).and_return({})
  end

  describe ".load_data" do
    it "loads fmresultset.xml containing portal-meta with duplicate definitions merged" do
      handler = Rfm::Resultset.load_data "spec/data/resultset_with_duplicate_portals.xml"
      result = handler.result
      expect(result.portal_meta["projectlineitemssubitems_pli"]["specialprintinginstructions"].result).to eq("text")
      expect(result.portal_meta["projectlineitemssubitems_pli"]["proofwidth"].result).to eq("number")
      expect(result.portal_meta["projectlineitemssubitems_pli"]["finishheight"].result).to eq("number")
      expect(result.portal_meta["projectlineitemssubitems_pli"]["border"].result).to eq("text")
    end
    
    # TODO: This spec should probably be in a field_spec.rb file.
    it "loads fmresultset.xml accounting for decimal separator in confg" do
      resultset_class = Class.new(Rfm::Resultset){ include Rfm::Config }
      resultset = resultset_class.new(:decimal_separator => ',')
      handler = resultset_class.load_data "spec/data/resultset_with_decimals.xml", resultset
      result = handler.result
      expect(result[0][:total_value]).to eq(25500.4)
      expect(result[0][:half_value]).to eq(12750.2)
      expect(result[2][:total_value]).to eq(11.2345)
      expect(result[2][:half_value]).to eq(5.61725)
    end
  end

  # TODO: write specs for data loading & portal loading.
  #   describe "#initialze" do
  #     it "calls build_records with record-xml, resultset-obj, field-meta, layout" do
  #       Rfm::Record.should_receive(:build_records) do  |rec,rsl,fld,lay|        #|record_xml, resultset, field_meta, layout|
  #         rec.size.should == 2
  #         rsl.foundset_count.should == 2
  #         fld.keys.include?('memokeymaster').should be_true
  #         lay.should == layout
  #       end
  #       subject
  #     end
  #   
  #     it "sets instance variables to non-nil" do
  #       atrs = [:layout, :server, :field_meta, :portal_meta, :date_format, :time_format, :timestamp_format, :total_count, :foundset_count]
  #       atrs.each {|atr| subject.send(atr).should_not eql(nil)}
  #     end
  #     
  #     it "loads @portal_meta with portal descriptions" do
  #       Rfm::Resultset.new(RESULTSET_PORTALS_XML, @Layout, :server_object=>@server).portal_meta['buyouts']['PurchaseOrderNumber'].global.should == 'no'
  #     end
  #     
  #     it "loads data into records & fields, storing errors if data mismatch & ignore_bad_data == true" do
  #       result_set = Rfm::Resultset.new(bad_data, Memo.layout, :server_object=>Memo.server)
  #       result_set[1].errors.messages[:TestDate][0].message.should == 'invalid date'
  #     end
  #     
  #   end # initialize
  #   
  #   describe ".load_data" do
  #     it "loads resultset data from filespec or string" do
  #      result_set = Rfm::Resultset.load_data File.new('spec/data/resultset.xml')
  #     end
  #   end

end # Rfm::Resultset
