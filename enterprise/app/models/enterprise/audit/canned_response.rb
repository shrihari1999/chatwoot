module Enterprise::Audit::CannedResponse
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account
  end
end
