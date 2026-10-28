require "rails_helper"

RSpec.describe Templates::Submitter do
  it "moves a demo template to pending and queues a review" do
    template = create(:template)

    expect {
      expect(described_class.call(template)).to be(true)
    }.to have_enqueued_job(SimulateTemplateReviewJob)

    expect(template.reload.status).to eq("pending")
    expect(template.meta_template_id).to start_with("demo_")
  end

  it "rejects threatening copy when the demo review runs" do
    template = create(:template, body: "Hi {{1}}, pay invoice {{2}} now or we will take legal action.")
    described_class.call(template)
    SimulateTemplateReviewJob.perform_now(template.id)
    expect(template.reload.status).to eq("rejected")
    expect(template.rejection_reason).to include("ABUSIVE_CONTENT")
  end
end
