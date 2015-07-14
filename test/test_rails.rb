require_relative 'helper'
require 'sidekiq'
require 'sidekiq/web_helpers'

$HAS_AJ = true
begin
  require 'active_job'
rescue
  $NO_AJ = false
end

class TestRails < Sidekiq::Test

  describe 'ActiveJob' do
    it 'does not allow Sidekiq::Worker in AJ::Base classes' do
      ex = assert_raises ArgumentError do
        c = Class.new(ActiveJob::Base)
        c.include Sidekiq::Worker
      end
      assert_includes ex.message, "cannot include"
    end if $HAS_AJ
  end
end
