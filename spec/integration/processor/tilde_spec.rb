describe "tilde operator" do
  let(:post) { double("post") }
  let(:presenter) { IntegrationTest::Presenter.new(double("view_context"), post: post) }

  it "{{~ ... }} removes trailing whitespaces and newlines from the previous :TEXT" do
    template = Curlybars.compile("before \r\t\n{{~'curlybars'}}\n\t\r after")

    expect(eval(template)).to resemble("beforecurlybars\n\t\r after")
  end

  it "{{ ... ~}} removes trailing whitespaces and newlines from the next :TEXT" do
    template = Curlybars.compile("before \r\t\n{{'curlybars'~}}\n\t\r after")
    expect(eval(template)).to resemble("before \r\t\ncurlybarsafter")
  end

  it "{{~ ... ~}} does not remove trailing whitespaces and newlines from the next :TEXT" do
    template = Curlybars.compile("before \r\t\n{{~'curlybars'~}}\n\t\r after")
    expect(eval(template)).to resemble("beforecurlybarsafter")
  end
end
