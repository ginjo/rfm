require 'spec_helper'
describe Rfm::Base do

  # Only run these if ActiveModel present.
  if Gem::Specification::find_all_by_name('activemodel').any?
    require 'active_model_lint'

    describe TestModel do
      it_should_behave_like "ActiveModel"
    end
  end

  # describe 'Test stubbing' do
  #   it "server has stubbed methods for db connections" do
  #     m = Memo.new(:memotext=>'test1').save!
  #   end
  # end

  describe '.inherited' do
    it("adds new model class to Rfm::Factory@models"){expect(Rfm::Factory.models.include?(Memo)).to be_truthy}
    it("sets model @config with :parent and other config options") do
      expect(Memo.config[:parent]).to eq('Rfm::Base')  #'parent_layout'
      expect(Memo.get_config[:layout]).to eq('testlay1')
    end
  end

  describe '.layout' do
    it("retrieves or creates layout object"){expect(Memo.layout.name).to eq('testlay1')}
    it("layout object is a Layout"){Memo.layout.is_a?(Rfm::Layout)}
  end

  describe '.find' do
    it("passes parameters & options to Layout object") do
      expect(Memo.layout).to receive(:find) do |*args|
        expect(args[0]).to eq({:field_one=>'test'})
        expect(args[1]).to eq({:max_records=>5})
      end
      Memo.find({:field_one=>'test'}, :max_records=>5)
    end
  end

  describe '#update_attributes' do
    before(:each) do
      allow_any_instance_of(Rfm::Connection).to receive(:connect).and_return(LAYOUT_XML)
      @m = Memo.new
      @m.update_attributes :memotext=>'memotext test', :memosubject=>'memosubject test', :extra=>'extra field test'
    end

    it "updates self with new data" do; #y Memo.layout.field_controls; end
    expect(@m.memotext).to eq('memotext test')
    expect(@m.memosubject).to eq('memosubject test')
    end

    it "updates @mods with new data" do
      expect(@m.instance_variable_get(:@mods)['memotext']).to eq('memotext test')
      expect(@m.instance_variable_get(:@mods)['memosubject']).to eq('memosubject test')
    end

    it "adds/updates instance_variables with keys that do not exist in field list" do
      expect(@m.instance_variable_get(:@extra)).to eq('extra field test')
      expect {@m[:extra]}.to raise_error(Rfm::ParameterError)
      expect(@m.instance_variable_get(:@mods)['extra']).to eq(nil)
    end
    
    it "accepts portal-write notation for portal fields" do
      @m.update_attributes 'fakerelationship::fakefield.0' => 'new portal record'
      expect(@m['fakerelationship::fakefield.0']).to eq('new portal record')
      expect(@m.instance_variable_get(:@mods)['fakerelationship::fakefield.0']).to eq('new portal record')
    end
  end

  # describe '.create_from_instance'

  # describe '#initialize'

  # describe '#new_record?'

  # describe '#reload'

  # describe '#update_attributes!'

  # describe '#save!'

  # describe '#save'

  # describe '#destroy'

  # describe '#save_if_not_modified'

  # describe '#callback_deadend'

  # describe '#create'

  # describe '#update'

  # describe '#merge_rfm_result'


  describe 'Functional Tests -' do

    it 'creates a new record with data' do
      subject_test = Memo.new(:memotext=>'test1')
      expect(subject_test.memotext).to eq('test1')
      expect(subject_test.class).to eq(Memo)
    end

    it 'adds more data to the record' do
      subject_test = Memo.new
      subject_test.memosubject = 'test2'
      expect(subject_test.instance_variable_get(:@mods).size).to be > 0
    end

    it "creates a model instance with empty fields, translating according to field_mapping" do
      layout = Rfm::Layout.new(:base_test)
      layout.config :field_mapping => {'memosubject' => 'subject', 'memotext'=>'text'}
      new_record = layout.modelize.new
      #puts new_record.layout.field_keys
      expect((new_record.keys & ['subject', 'text']).size).to eq(2)
    end

    # TODO: Fix these specs to work with newest Rfm.

    # it 'saves the record' do
    #   subject_test = Memo.new(:memosubject => 'test3')
    #   subject_test.server.should_receive(:connect) do |*args|
    #     args[2].should == '-new'
    #     args[3]['memosubject'].should == 'test3'
    #   end
    #   subject_test.save!
    #   subject_test[:memosubject].should == 'memotest4'  
    # end

    # it 'finds a record by id' do
    #   @Server.should_receive(:connect) do |*args|
    #     args[2].should == '-find'
    #     args[3]['-recid'].should == '12345'
    #   end
    #   resultset = Memo.find(12345)
    #   resultset[0][:memosubject].should == 'memotest4'
    # end

    # it 'uses #update_attributes! to modify data' do
    #   subject_test = Memo.new
    #   subject_test.server.should_receive(:connect) do |*args|
    #     args[2].should == '-new'
    #     args[3]['memotext'].should == 'test3'
    #   end
    #   subject_test.update_attributes!(:memotext=>'test3')
    #   subject_test[:memosubject].should == 'memotest4'    
    # end

    # it 'searches for several records and loops thru to find one' do
    #   @Server.should_receive(:connect) do |*args|
    #     args[2].should == '-find'
    #     args[3][:memotext].should == 'test5'
    #   end
    #   resultset = Memo.find(:memotext=>'test5')
    #   resultset.find{|r| r.recordnumber == '399341'}.memotext.should == 'memotest7'
    # end

    # it 'destroys a record' do
    #   @Server.should_receive(:connect) do |*args|
    #     args[2].should == '-find'
    #     args[3]['-recid'].should == '12345'
    #   end
    #   resultset = Memo.find(12345)
    #   @Server.should_receive(:connect) do |*args|
    #     args[2].should == '-delete'
    #     args[3]['-recid'].should == '149535'
    #   end
    #   rec = resultset[0].destroy
    #   rec.frozen?().should be_true
    #   rec.memotext.should == 'memotest3'
    # end
  end

end # Rfm::Base
