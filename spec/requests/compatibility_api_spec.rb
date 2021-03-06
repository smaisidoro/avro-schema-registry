describe CompatibilityAPI do

  describe "POST /compatibility/subjects/:subject/versions/:version" do
    let(:version) { create(:schema_version) }
    let(:subject_name) { version.subject.name }
    let(:schema) do
      JSON.parse(version.schema.json).tap do |avro|
        avro['fields'] << { name: :new, type: :string, default: '' }
      end.to_json
    end
    let(:compatibility) { nil }

    it "tests compatibility of the schema with the version of the subject's schema" do
      allow(SchemaRegistry).to receive(:compatible?).with(compatibility,
                                                          version.schema.json,
                                                          schema).and_return(true)
      post("/compatibility/subjects/#{subject_name}/versions/#{version.version}", schema: schema)
      expect(response).to be_ok
      expect(response.body).to be_json_eql({ is_compatible: true }.to_json)
    end

    context "when compatibility is set for the subject" do
      let(:compatibility) { 'FORWARD' }

      before { version.subject.create_config!(compatibility: compatibility) }

      it "tests compatibility of the schema with the version of the subject's schema" do
        allow(SchemaRegistry).to receive(:compatible?).with(compatibility,
                                                            version.schema.json,
                                                            schema).and_return(true)
        post("/compatibility/subjects/#{subject_name}/versions/#{version.version}", schema: schema)
        expect(response).to be_ok
        expect(response.body).to be_json_eql({ is_compatible: true }.to_json)
      end
    end

    context "when the version is specified as latest" do
      let(:second_version) { create(:schema_version, subject: version.subject, version: 2) }

      it "tests compatibility of the schema with the latest version of the subject's schema" do
        allow(SchemaRegistry).to receive(:compatible?).with(compatibility,
                                                            second_version.schema.json,
                                                            schema).and_return(true)
        post("/compatibility/subjects/#{subject_name}/versions/latest", schema: schema)
        expect(response).to be_ok
        expect(response.body).to be_json_eql({ is_compatible: true }.to_json)
      end
    end

    it_behaves_like "a secure endpoint" do
      let(:action) do
        unauthorized_post("/compatibility/subjects/#{subject_name}/versions/#{version.version}",
                          schema: schema)
      end
    end

    context "when the schema is invalid" do
      let(:schema) do
        # invalid due to missing record name
        { type: :record, fields: [{ name: :i, type: :int }] }.to_json
      end

      it "returns an invalid schema error" do
        post("/compatibility/subjects/#{subject_name}/versions/latest", schema: schema)
        expect(status).to eq(422)
        expect(response.body).to be_json_eql(SchemaRegistry::Errors::INVALID_AVRO_SCHEMA.to_json)
      end
    end

    context "when the subject is not found" do
      it "returns a subject not found error" do
        post('/compatibility/subjects/example.not_found/versions/latest', schema: schema)
        expect(response).to be_not_found
        expect(response.body).to be_json_eql(SchemaRegistry::Errors::SUBJECT_NOT_FOUND.to_json)
      end
    end

    context "when the version is not found" do
      it "returns a version not found error" do
        post("/compatibility/subjects/#{subject_name}/versions/2", schema: schema)
        expect(response).to be_not_found
        expect(response.body).to be_json_eql(SchemaRegistry::Errors::VERSION_NOT_FOUND.to_json)
      end
    end
  end
end
