require 'spec_helper'
describe err_module = Rfm::Error do
  describe ".lookup" do

    it "should return a default system error if input code is 0" do
      error = err_module.getError(0)
      expect(error.message).to eql('SystemError occurred: (FileMaker Error #0)')
      expect(error.code).to eql(0)
    end

    it "should return a default system error if input code is 22" do
      error = err_module.getError(20)
      expect(error.message).to eql('SystemError occurred: (FileMaker Error #20)')
      expect(error.code).to eql(20)
    end

    it "should return a custom message as second argument" do
      error = err_module.getError(104, 'Custom Message Here.')
      expect(error.message).to match(/Custom Message Here/)
    end

    it "should return a script missing error" do
      error = err_module.getError(104)
      expect(error.message).to eql('ScriptMissingError occurred: (FileMaker Error #104)')
      expect(error.code).to eql(104)
    end  

    it "should return a range validation error" do
      error = err_module.getError(503)
      expect(error.message).to eql('RangeValidationError occurred: (FileMaker Error #503)')
      expect(error.code).to eql(503)
    end  

    it "should return unknown error if code not found" do
      error = err_module.getError(-1)
      expect(error.message).to eql('UnknownError occurred: (FileMaker Error #-1)')
      expect(error.code).to eql(-1)
      expect(error.class).to eql(err_module::UnknownError)
    end

  end

  describe ".find_by_code" do
    it "should return a constant representing the error class" do
      constant = err_module.find_by_code(503)
      expect(constant).to eql(err_module::RangeValidationError)
    end
  end

  describe ".build_message" do
    before(:each) do
      @message = err_module.build_message(503, 'This is a custom message')
    end

    it "should return a string with the code and message included" do
      expect(@message).to match(/This is a custom message/)
      expect(@message).to match(/503/)
    end

    it "should look like" do
      expect(@message).to eql('503 occurred: (FileMaker Error #This is a custom message)')
    end
  end

end
