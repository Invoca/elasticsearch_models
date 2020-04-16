# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::QueryString do
  describe ".term_for" do
    subject(:term) { ElasticsearchModels::Query::QueryString.term_for(condition) }
    let(:condition) { "filter text" }
    let(:expected_term) { '(*filter AND text*)' }

    shared_examples "nothing" do
      it "does not include q" do
        expect(term).to be_nil
      end
    end

    shared_examples "a search term" do
      it "is converted to an elasticsearch term" do
        expect(term).to eq(expected_term)
      end
    end

    context "when condition is a String" do
      it_behaves_like "a search term"

      context "condition is empty string" do
        let(:condition) { "" }
        it_behaves_like "nothing"
      end

      context "with extra spaces" do
        let(:condition) { "filter    text" }
        it_behaves_like "a search term"
      end

      context "escaping special characters" do
        let(:condition) { '~tex*t wi[t]h "s{pe\c}ia/l" #v@lue$!^ a+l|l o-ve:r' }
        let(:expected_term) { '(*\~tex\*t AND wi\[t\]h AND \"s\{pe\\\\c\}ia\/l\" AND #v@lue$\!\^ AND a\+l\|l AND o\-ve\:r*)' }
        it_behaves_like "a search term"
      end
    end

    context "when condition is a Hash" do
      let(:condition) { { some: { nested: { condition: "filter text" } } } }
      let(:expected_term) { 'some.nested.condition:(*filter AND text*)' }

      it_behaves_like "a search term"

      context "with many terms" do
        let(:condition) { { some: { nested: { condition: "filter text", part: "two" } } } }
        let(:expected_term) { 'some.nested.condition:(*filter AND text*) AND some.nested.part:(*two*)' }

        it_behaves_like "a search term"
      end

      context "value is an Array" do
        let(:condition) { { some: { nested: { condition: ["filter", "text"] } } } }
        let(:expected_term) { 'some.nested.condition:((*filter*) OR (*text*))' }

        it_behaves_like "a search term"
      end

      context "value is a Range" do
        let(:condition) { { some: { nested: { condition: (1..2) } } } }
        let(:expected_term) { "some.nested.condition:[1 TO 2]" }

        it_behaves_like "a search term"
      end
    end

    context "when condition is an Array" do
      let(:condition) { ["filter text", "some more filter text"] }
      let(:expected_term) { '((*filter AND text*) OR (*some AND more AND filter AND text*))' }

      it_behaves_like "a search term"
    end

    context "when condition is a Numeric" do
      let(:condition) { 1 }
      let(:expected_term) { 1 }

      it_behaves_like "a search term"
    end

    context "when condition is a Range" do
      context "that is inclusive" do
        let(:condition) { 1..3 }
        let(:expected_term) { "[1 TO 3]" }

        it_behaves_like "a search term"
      end

      context "that is exclusive" do
        let(:condition) { 1...3 }
        let(:expected_term) { "[1 TO 2]" }

        it_behaves_like "a search term"
      end

      context "values are integers" do
        it_behaves_like "a search term"
      end

      context "values are strings" do
        let(:condition) { 'a'..'z' }
        let(:expected_term) { "[a TO z]" }

        it_behaves_like "a search term"
      end

      context "values are time objects" do
        let(:condition) do
          time = Time.utc(2018, 12, 27, 20, 10).in_time_zone("Pacific Time (US & Canada)")
          min_time = time - 300
          max_time = time + 300
          min_time..max_time
        end
        let(:expected_term) { "[2018-12-27T20:05:00.000Z TO 2018-12-27T20:15:00.000Z]" }

        it_behaves_like "a search term"
      end

      context "values are date objects" do
        let(:condition) do
          date = Date.new(2019, 2, 1)
          min_date = date - 1
          max_date = date + 1
          min_date..max_date
        end
        let(:expected_term) { "[2019-01-31 TO 2019-02-02]" }

        it_behaves_like "a search term"
      end

      context "values are empty" do
        let(:condition) { 2..1 }

        it_behaves_like "nothing"
      end
    end

    context "condition is nil" do
      let(:condition) { nil }
      it_behaves_like "nothing"
    end

    context "when condition is something else" do
      let(:condition) do
        class Hi; end
        Hi.new
      end

      it "raises an argument error" do
        expect { term }.to raise_error(ArgumentError, "Hi is not a supported search condition type")
      end
    end
  end
end
