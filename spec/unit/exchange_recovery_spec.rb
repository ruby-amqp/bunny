require_relative '../../lib/bunny/channel'
require_relative '../../lib/bunny/exchange'

module Bunny
  describe Exchange do
    context "recovery" do
      it "recovers exchange bindings, unless already unbound" do
        ch = instance_double(Bunny::Channel,
                             exchange_declare: nil,
                             register_exchange: nil)
        src1 = Exchange.new(ch, "direct", "src1")
        src2 = Exchange.new(ch, "direct", "src2")
        src3 = Exchange.new(ch, "direct", "src3")
        dst = Exchange.new(ch, "direct", "dst")

        original_binds_count = 5
        expected_rebinds_count = 3
        expected_total_binds = original_binds_count + expected_rebinds_count
        allow(ch).to receive(:exchange_bind).exactly(expected_total_binds).times

        dst.bind(src1, routing_key: "abc")
        dst.bind(src2, routing_key: "def")
        dst.bind(src2, routing_key: "ghi")
        dst.bind(src3, routing_key: "jkl")
        dst.bind(src3, routing_key: "jkl", arguments: {"key" => "value"})

        allow(ch).to receive(:exchange_unbind).twice
        dst.unbind(src2, routing_key: "def")
        dst.unbind(src3, routing_key: "jkl", arguments: {"key" => "value"})

        expect(ch).to receive(:exchange_bind).with(src1, dst, routing_key: "abc")
        expect(ch).to receive(:exchange_bind).with(src2, dst, routing_key: "ghi")
        expect(ch).to receive(:exchange_bind).with(src3, dst, routing_key: "jkl")

        dst.recover_from_network_failure
      end
    end
  end
end
