require 'helper'
require 'sidekiq/logging'

class TestFetcher < Sidekiq::Test
  describe Sidekiq::Logging do
    describe "#with_context" do
      def context
        Sidekiq::Logging.logger.formatter.context
      end

      it "has no context by default" do
        context.must_equal ""
      end

      it "can add a context" do
        Sidekiq::Logging.with_context "xx" do
          context.must_equal " xx"
        end
        context.must_equal ""
      end

      it "can use multiple contexts" do
        Sidekiq::Logging.with_context "xx" do
          context.must_equal " xx"
          Sidekiq::Logging.with_context "yy" do
            context.must_equal " yy"
          end
          context.must_equal " xx"
        end
        context.must_equal ""
      end
    end
  end
end
