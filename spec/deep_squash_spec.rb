# frozen_string_literal: true

RSpec.describe ElasticsearchModels::DeepSquash do
  include ElasticsearchModels::DeepSquash

  it "returns Trueclass as is" do
    expect(deep_squash(true)).to be(true)
  end

  it "returns Falseclass as is" do
    expect(deep_squash(false)).to be(false)
  end

  it "returns nil for empty string" do
    expect(deep_squash("    ")).to be_nil
  end

  context "hash" do
    it "returns nil for empty hash" do
      expect(deep_squash({})).to be_nil
    end

    it "returns nil for hash with nil values" do
      deep_squash_value = { a: nil, b: nil }
      expect(deep_squash(deep_squash_value)).to be_nil
    end

    it "recursively calls deep_squash on each value within the hash then compacts the hash and checks for presence" do
      deep_squash_value = { a: nil, b: nil, c: { d: nil, e: 5, g: [1, nil, {}, []], f: [] } }
      expected_response = { c: { e: 5, g: [1] } }
      expect(deep_squash(deep_squash_value)).to eq(expected_response)
    end
  end

  context "array" do
    it "returns nil for empty array" do
      expect(deep_squash([])).to be_nil
    end

    it "returns nil for array with nil values" do
      expect(deep_squash([nil, nil])).to be_nil
    end

    it "returns nil for array with values that will be compacted" do
      expect(deep_squash([[], {}, nil, "  "])).to be_nil
    end

    it "recursively calls deep_squash on each item within the array then compacts the array and checks for presence" do
      deep_squash_value = ["  ", [[1], nil], nil, 1, { a: nil, b: nil, c: { d: nil, e: 5, g: [1, nil], f: [] } }]
      expected_response = [[[1]], 1, { c: { e: 5, g: [1] } }]
      expect(deep_squash(deep_squash_value)).to eq(expected_response)
    end
  end
end
