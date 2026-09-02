# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"
require "tempfile"

describe Bunny::Session, "TLS client certificate" do
  let(:leaf) { File.read("spec/tls/client_certificate.pem") }
  let(:ca) { File.read("spec/tls/ca_certificate.pem") }

  def context_for(certificate)
    Tempfile.create(["client_certificate", ".pem"]) do |f|
      f.write(certificate)
      f.flush

      Bunny.new(tls: true, tls_cert: f.path, tls_key: "spec/tls/client_key.pem").transport.tls_context
    end
  end

  it "uses the certificate as is when the file holds a single one" do
    ctx = context_for(leaf)

    expect(ctx.cert.to_pem).to eq(leaf)
    expect(ctx.extra_chain_cert).to be_nil
  end

  # what cert-manager writes into tls.crt: the leaf, then the CAs that chain it to a root
  it "presents the rest of the bundle alongside the leaf" do
    ctx = context_for(leaf + ca)

    expect(ctx.cert.to_pem).to eq(leaf)
    expect(ctx.extra_chain_cert.map(&:to_pem)).to eq([ca])
  end

  it "still rejects a file that does not hold a certificate" do
    expect { context_for("not a certificate") }.to raise_error(OpenSSL::X509::CertificateError)
  end
end
