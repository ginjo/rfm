require 'spec_helper'
describe Rfm::Record do
  let(:resultset) {Rfm::Resultset.allocate}
  let(:record) {Rfm::Record.allocate}
  let(:layout) {Rfm::Layout.allocate}
  subject {record}

  before(:each) do
    record.instance_variable_set(:@portals, Rfm::CaseInsensitiveHash.new)
  end

  describe ".new" do

    context "when model exists" do
      it "creates an instance of model" do
        rs = Rfm::Resultset.new @Layout, @Layout
        #puts rs.layout
        #puts rs.layout.model
        expect(Rfm::Record.new(rs).class).to eq(Memo)
      end
    end

    context "when no model exists" do
      it "creates an instance of Rfm::Record" do
        Rfm::Record.new.class == Rfm::Record
      end
    end
  end

  describe "#[]" do
    before(:each) do
      record.instance_variable_set(:@mods, {})
      record.instance_variable_set(:@loaded, false)
      record['tester'] = 'red'
    end

    it "returns '' if hash value is '' " do
      record['tester'] = ''
      record.instance_variable_set(:@loaded, true)

      expect(record['tester']).to eql('')
    end

    it "returns nil if hash value is nil " do
      record['tester'] = nil
      record.instance_variable_set(:@loaded, true)

      expect(record['tester']).to eql(nil)
    end

    it "raises an Rfm::ParameterError if a key is used that does not exist" do
      record.instance_variable_set(:@loaded, true)
      record.instance_variable_set(:@layout, layout) # will allow this test to pass

      ex = rescue_from { record['tester2'] }
      expect(ex.class).to eql(Rfm::ParameterError)
      expect(ex.message).to eql('tester2 does not exists as a field in the current Filemaker layout.')
    end

    it "returns value whether key is string or symbol" do
      record.instance_variable_set(:@loaded, true)

      expect(record.has_key?(:tester)).to be_falsey
      expect(record[:tester]).to eql('red')
    end

    it "returns value regardless of key case" do
      record.instance_variable_set(:@loaded, true)

      expect(record['TESTER']).to eq('red')
    end
  end #[]


  describe "#[]=" do
    before(:each) do
      record.instance_variable_set(:@mods, {})
      record.instance_variable_set(:@loaded, false)
      record['tester'] = 'red'
    end

    it "creates a new hash key => value upon instantiation of record" do
      expect(record.has_key?('tester')).to be_truthy
      expect(record['tester']).to eql('red')
    end

    it "creates a new hash key as downcase" do
      record['UPCASE'] = 'downcase'
      expect(record.key?('upcase')).to be_truthy
    end

    it "creates a new hash key => value in @mods when modifying an existing record key" do
      record.instance_variable_set(:@loaded, true)
      record['tester'] = 'green'

      expect(record.instance_variable_get(:@mods).has_key?('tester')).to be_truthy
      expect(record.instance_variable_get(:@mods)['tester']).to eql('green')
    end

    it "modifies the hash key => value in self whether key is string or symbol" do
      record.instance_variable_set(:@loaded, true)
      record[:tester] = 'green'

      expect(record.has_key?(:tester)).to be_falsey
      expect(record['tester']).to eql('green')
    end

    it "returns '' if hash value is '' " do
      record['tester'] = 'something'
      record.instance_variable_set(:@loaded, true)
      record['tester'] = ''
      expect(record['tester']).to eql('')
    end

    it "returns nil if hash value is nil " do
      record['tester'] = 'something'
      record.instance_variable_set(:@loaded, true)
      record['tester'] = nil
      expect(record['tester']).to eql(nil)
    end

    it "raises an Rfm::ParameterError if a value is set on a key that does not exist" do
      record.instance_variable_set(:@loaded, true)
      ex = rescue_from { record['tester2'] = 'error' }
      expect(ex.class).to eql(Rfm::ParameterError)
      expect(ex.message).to match(/You attempted.*Filemaker layout/)
    end
    
    it "accepts portal-write notation for portal fields" do
      layout.instance_variable_set(:@meta, Rfm::Metadata::LayoutMeta.new(layout).merge!({'field_controls' => {'fakerelationship::fakefield' => Rfm::Metadata::FieldControl.new({'name' => 'FakeRelationship::FakeField'})}}))
      record.layout = layout
      record.instance_variable_set(:@loaded, true)
      record['fakerelationship::fakefield.0'] = 'new portal record'
      expect(record['fakerelationship::fakefield.0']).to eq('new portal record')
      expect(record.instance_variable_get(:@mods)['fakerelationship::fakefield.0']).to eq('new portal record')
    end
  end #[]=


  describe "#respond_to?" do
    it "returns true if key is in hash" do
      record['red'] = 'stop'

      expect(record.respond_to?(:red)).to be_truthy
    end

    it "returns false if key is not in hash" do
      expect(record.respond_to?(:red)).to be_falsey
    end
  end

  describe "#method_missing" do
    before(:each) do
      record.instance_variable_set(:@mods, {})
      record['name'] = 'red'
    end

    describe "getter" do
      it "will match a method to key in the hash if there is one" do
        expect(record.name).to eql('red')
      end

      it "will raise NoMethodError if no key present that matches value" do
        ex = rescue_from { record.namee }
        expect(ex.class).to eql(NoMethodError)
        expect(ex.message).to match(/undefined method `namee'/)
      end
    end

    describe "setter" do
      it "acts as a setter if the key exists in the hash" do
        record.instance_variable_set(:@loaded, true)
        record.name = 'blue'

        expect(record.instance_variable_get(:@mods).has_key?('name')).to be_truthy
        expect(record.instance_variable_get(:@mods)['name']).to eql('blue')
      end

      it "will raise NoMethodError if no key present that matches value" do
        ex = rescue_from { record.namee = 'red' }
        expect(ex.class).to eql(NoMethodError)
        expect(ex.message).to match(/undefined method `namee='/)
      end
    end

  end

  describe "#save" do
    before(:each) do
      record['name'] = 'red'
      record.instance_variable_set(:@record_id, 1)
      record.instance_variable_set(:@loaded, true)
      record.instance_variable_set(:@layout, layout)
      record.instance_variable_set(:@mods, {})
      allow(layout).to receive(:edit){[record.dup.merge(record.instance_variable_get(:@mods))]}
    end

    context "when not modified" do
      let(:original) {record.dup}
      let(:result) {record.save}

      it("leaves self untouched"){is_expected.to eq(original)}
      it("returns {}"){expect(result).to eq({})}      
    end

    context "when modified" do
      before(:each) {record.name = 'green'}

      it "passes @mods and @mod_id to layout" do
        expect(layout).to receive(:edit).with(1, {'name'=>'green'})
        record.save
      end

      it "merges returned hash from Layout#edit" do
        record.instance_variable_get(:@mods)['name'] = 'blue'
        record.save
        expect(record['name']).to eql('blue')
      end

      it "clears @mods" do
        record.save
        expect(record.instance_variable_get(:@mods)).to eql({})
      end

      it "returns {}" do
        expect(record.save).to eql({})
      end
    end

  end #save

  describe "#save_if_not_modified" do
    before(:each) {
      record['name'] = 'red'
      record.instance_variable_set(:@record_id, 1)
      record.instance_variable_set(:@loaded, true)
      record.instance_variable_set(:@mod_id, 5)
      record.instance_variable_set(:@layout, layout)
      record.instance_variable_set(:@mods, {})
      allow(layout).to receive(:edit){[record.instance_variable_get(:@mods)]}
    }

    context "when local record not modified" do
      let(:original) {record.dup}
      let(:result) {record.save_if_not_modified}

      it("leaves self untouched"){is_expected.to eq(original)}
      it("returns {}"){expect(result).to eq({})}      
    end

    context "when local record modified" do
      before(:each) {record.name = 'green'}

      it "passes @mods and @mod_id to layout" do
        expect(layout).to receive(:edit).with(1, {'name'=>'green'}, {:modification_id => 5})
        record.save_if_not_modified
      end

      it "merges returned hash from Layout#edit" do
        record.instance_variable_get(:@mods)['name'] = 'blue'
        record.save_if_not_modified
        expect(record['name']).to eql('blue')
      end

      it "clears @mods" do
        record.save_if_not_modified
        expect(record.instance_variable_get(:@mods)).to eql({})
      end

      it "returns {}" do
        expect(record.save_if_not_modified).to eql({})
      end
    end

  end #save_if_not_modified


end #Rfm::Record
