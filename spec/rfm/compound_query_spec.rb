require 'spec_helper'
describe 'Rfm::CompoundQuery' do

  it "handles nil values for query parameters" do
    raw_query = [{:a => nil, :b => 2}]
    key_map_string = Rfm::CompoundQuery.new(raw_query).key_map_string
    expect(key_map_string).to eq('(q0,q1)')
  end

end
