require_relative "test_helper"
require "network/box"

test_logger = Logger.new(STDOUT)
Yast2::ScrBox.logger = test_logger
Yast2::SysconfigBoxGroup.logger = test_logger

describe Module do
  class BoxAccessorTest
    box_accessor :foo

    def initialize
      @foo_box = Yast2::Box.new
    end
  end
  subject { BoxAccessorTest.new }

  describe ".box_accessor" do
    it "declares a Box accessor" do
      expect { subject.foo = 42 }.to_not raise_error
      expect(subject.foo).to eq 42
    end
  end
end

describe "Box" do
  let(:test_values) { [42, 4.3, true, false, nil, "str", :sym] }

  describe Yast2::Box do
    it "remembers what was put in" do
      test_values.each do |v|
        expect(subject.value = v).to eq v
        expect(subject.value).to eq v
      end
    end
  end

  describe Yast2::ReadCachingBox do
    let(:lower) { double("Box") }

    it "needs to fill the reading cache" do
      test_values.each do |v|
        subj = described_class.new(lower)
        expect(lower).to receive(:value).once.and_return(v)

        _ = subj.value
      end
    end

    it "caches reading before/without writing" do
      test_values.each do |v|
        subj = described_class.new(lower)
        expect(lower).to receive(:value).once.and_return(v)

        _ = subj.value
        _ = subj.value
      end
    end

    it "caches reading after writing" do
      test_values.each do |v|
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with(v).once
        expect(lower).to_not receive(:value)

        subj.value = v
        _ = subj.value
        _ = subj.value
      end
    end
  end

  describe Yast2::CachingBox do
    let(:lower) { double("Box") }

    it "caches writing the same value" do
      test_values.each do |v|
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with(v).once

        subj.value = v
        subj.value = v
      end
    end

    it "does not cache writing a single value" do
      test_values.each do |v|
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with(v).once

        subj.value = v
      end
    end

    it "does not cache writing different values" do
      test_values.each_cons(2) do |a, b|
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with(a).once
        expect(lower).to receive(:value=).with(b).once

        subj.value = a
        subj.value = b
      end
    end
  end

  describe Yast2::ScrBox do
    let(:paths) { [".my.path", path(".your.path")] }

    describe "#value" do
      it "uses SCR.Read" do
        paths.each do |p|
          test_values.each do |v|
            subj = described_class.new(path: p)
            expect(Yast::SCR)
              .to receive(:Read).with(Yast::Path).and_return(v)
            expect(subj.value).to eq v
          end
        end
      end
    end

    describe "#value=" do
      it "uses SCR.Write" do
        paths.each do |p|
          test_values.each do |v|
            subj = described_class.new(path: p)
            expect(Yast::SCR)
              .to receive(:Write).with(Yast::Path, v).and_return(true)
            expect(subj.value = v).to eq v
          end
        end
      end
    end
  end

  describe Yast2::BooleanBox do
    describe "#read" do
      it "reads 'yes' as true" do
        lower = double(value: "yes")
        subj = described_class.new(lower)
        expect(subj.value).to eq true
      end

      it "reads 'no' as false" do
        lower = double(value: "no")
        subj = described_class.new(lower)
        expect(subj.value).to eq false
      end

      it "reads nil as the constructor-specified value" do
        lower = double(value: nil)
        subj = described_class.new(lower, for_nil: 42)
        expect(subj.value).to eq 42
      end

      it "reads another value as the constructor-specified value" do
        lower = double(value: 5)
        subj = described_class.new(lower, for_other: 4.2)
        expect(subj.value).to eq 4.2
      end
    end

    describe "#write" do
      it "writes true as 'yes'" do
        lower = double("Box")
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with("yes").and_return("yes")
        expect(subj.value = true).to eq true
      end

      it "writes false as 'no'" do
        lower = double("Box")
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with("no").and_return("no")
        expect(subj.value = false).to eq false
      end

      it "writes nil as nil" do
        lower = double("Box")
        subj = described_class.new(lower)
        expect(lower).to receive(:value=).with(nil).and_return(nil)
        expect(subj.value = nil).to eq nil
      end

      it "raises ArgumentError for writing another value" do
        lower = double("Box")
        subj = described_class.new(lower)
        expect { subj.value = 5 }.to raise_error(ArgumentError)
      end
    end
  end

  describe Yast2::StagingBox do
    let(:production) { double("Box") }

    describe "#value" do
      it "uses production" do
        subj = described_class.new(production)
        expect(production).to receive(:value).and_return(42)
        expect(subj.value).to eq 42
      end
    end

    describe "#value=" do
      it "does not use production" do
        subj = described_class.new(production)
        expect(production).to_not receive(:value=)
        expect(subj.value = 42).to eq 42
      end
    end

    describe "#commit" do
      it "returns false when called alone" do
        subj = described_class.new(production)
        expect(subj.commit).to eq false
      end

      context "when called after value=existing_value" do
        it "reads production and returns false" do
          subj = described_class.new(production)
          expect(production).to receive(:value).and_return(42)
          expect(production).to_not receive(:value=)

          subj.value = 42
          expect(subj.commit).to eq false
        end
      end

      context "when called after value=different_value" do
        it "reads, writes production and returns true" do
          subj = described_class.new(production)
          expect(production).to receive(:value).and_return(2)
          expect(production).to receive(:value=).with(42).and_return(42)

          subj.value = 42
          expect(subj.commit).to eq true
        end
      end
    end
  end

  describe Yast2::SysconfigBoxGroup do
    subject do
      described_class.new(path: ".foo")
    end

    describe "#reset" do
      it "forwards to members" do
        b1 = Yast2::StagingBox.new(double)
        b2 = Yast2::StagingBox.new(double)
        subject << b1
        subject << b2
        expect(b1).to receive(:reset)
        expect(b2).to receive(:reset)
        subject.reset
      end
    end

    describe "#commit" do
      it "does not flush if no members exist" do
        expect(Yast::SCR)
          .to_not receive(:Write).with(Yast::Path, nil)
        expect(subject.commit).to eq(false)
      end

      it "does not flush if no members need it" do
        b1 = Yast2::StagingBox.new(double)
        b2 = Yast2::StagingBox.new(double)
        subject << b1
        subject << b2
        expect(b1).to receive(:commit).and_return(false)
        expect(b2).to receive(:commit).and_return(false)
        expect(Yast::SCR)
          .to_not receive(:Write).with(Yast::Path, nil)
        expect(subject.commit).to eq(false)
      end

      it "flushes if a member needs it" do
        b1 = Yast2::StagingBox.new(double)
        b2 = Yast2::StagingBox.new(double)
        subject << b1
        subject << b2
        expect(b1).to receive(:commit).and_return(true)
        expect(b2).to receive(:commit).and_return(false)
        expect(Yast::SCR)
          .to receive(:Write).with(Yast::Path, nil).and_return(true)
        expect(subject.commit).to eq(true)
      end
    end
  end
end
