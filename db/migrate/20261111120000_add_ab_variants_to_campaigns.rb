class AddAbVariantsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :variant_template, foreign_key: { to_table: :templates }
    add_column :campaign_recipients, :variant, :string
  end
end
