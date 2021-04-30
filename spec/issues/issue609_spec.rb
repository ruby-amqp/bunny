# frozen_string_literal: true

require 'spec_helper'

describe Bunny::Session, 'TLS certificate store' do
  subject { described_class.new tls: true, tls_ca_certificates: [certificate], logger: logger }

  let(:logger) { Logger.new(io).tap { |l| l.level = :debug } }
  let(:io) { StringIO.new }

  context 'when a Windows path given' do
    let(:certificate) { 'C:/some/path/cacert.pem' }

    # skipping actual work with file by Windows path as this spec runs in Linux
    before do
      allow(File).to receive(:readable?).with(certificate).and_return(true)
      allow_any_instance_of(OpenSSL::X509::Store).to receive(:add_file)
    end

    it 'uses the certificate by path' do
      subject

      expect(log_content).to include('Using CA certificates at C:/some/path/cacert.pem')
    end
  end

  context 'when a POSIX path given' do
    let(:certificate) { './spec/tls/ca_certificate.pem' }

    it 'uses the certificate by path' do
      subject

      expect(log_content).to include('Using CA certificates at ./spec/tls/ca_certificate.pem')
    end
  end

  context 'when an inline certificate given' do
    let(:certificate) do
      <<~CERT
        -----BEGIN CERTIFICATE-----
        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
        eYEXqywYlmGZite4N3qb3qQnyGw=
        -----END CERTIFICATE-----
      CERT
    end

    it 'uses the inline certificate' do
      subject

      expect(log_content).to include('Using 1 inline CA certificates')
    end
  end

  def log_content
    io.tap(&:rewind).read
  end
end
