require 'spec_helper'

describe 'Rfm::Scope' do

  before(:all) do
    require 'rfm/utilities/scope'
    ScopedModel = Class.new(Rfm::Base){config :fictitious_layout}
  end
  
  # See spec for Layout#find for more examples that could be testing with scope here.  
  
  it "adds default empty SCOPE to Rfm::Base" do
    expect(Rfm::Base.const_defined?(:SCOPE)).to be_truthy
    expect(Rfm::Base::SCOPE.call).to eq(Proc.new{[]}.call)
  end
  
  it "descendant models inherit SCOPE constant" do
    expect(ScopedModel.const_defined?(:SCOPE) || ScopedModel.constants.include?("SCOPE")).to be_truthy
    expect(ScopedModel::SCOPE.call).to eq(Proc.new{[]}.call)  
  end
  
  it "descendant models extend scope methods" do
    expect(ScopedModel.respond_to?(:apply_scope)).to be_truthy
  end

  it "merges scope criteria into all non-omit requests of any query" do
    ScopedModel::SCOPE = Proc.new {|scope_args| {:companyid=>'12345'} }
    expect(ScopedModel.layout).to receive(:get_records) do |action, query, options|
      #puts query.to_yaml
      expect(action).to eq('-findquery')
      expect(['(q0,q2,q3);(q1,q2,q3);!(q4)', '(q0,q1,q3);(q0,q2,q3);!(q4)', '(q0,q1,q2);(q0,q1,q3);!(q4)'].include?(query['-query'])).to be_truthy
      #expect(query['-q3']).to eq(:companyid)
      #expect(query['-q3.value']).to eq('12345')
      expect(query.values.include?(:companyid)).to be_truthy
      expect(query.values.include?('12345')).to be_truthy
    end
    ScopedModel.find([{:memotext=>['one','two'], :memosubject=>'three'}, {:omit=>true, :memotext=>'test'}])
  end
  
  it "adds scope omits to end of request array" do
    ScopedModel::SCOPE = Proc.new {|scope_args| {:companyid=>'12345', :omit=>true} }
    expect(ScopedModel.layout).to receive(:get_records) do |action, query, options|
      #puts query.to_yaml
      expect(action).to eq('-findquery')
      expect(['(q0,q2);(q1,q2);!(q3)'].include?(query['-query'])).to be_truthy
      expect(query.values.include?(:companyid)).to be_truthy
      expect(query.values.include?(:memotext)).to be_truthy
      expect(query.values.include?(:memosubject)).to be_truthy
      expect(query.values.include?('12345')).to be_truthy
    end
    ScopedModel.find(:memotext=>['one','two'], :memosubject=>'three')  
  end

end
