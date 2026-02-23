require 'rails_helper'

RSpec.describe CannedResponseScope, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:canned_response) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:team).optional }
    it { is_expected.to belong_to(:inbox).optional }
  end

  describe 'factory' do
    it 'has a valid base factory' do
      expect(build(:canned_response_scope)).to be_valid
    end

    it 'has a valid user_scope trait' do
      expect(build(:canned_response_scope, :user_scope)).to be_valid
    end

    it 'has a valid team_scope trait' do
      expect(build(:canned_response_scope, :team_scope)).to be_valid
    end

    it 'has a valid inbox_scope trait' do
      expect(build(:canned_response_scope, :inbox_scope)).to be_valid
    end
  end
end
