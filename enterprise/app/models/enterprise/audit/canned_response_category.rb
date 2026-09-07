module Enterprise::Audit::CannedResponseCategory
  extend ActiveSupport::Concern

  included do
    audited associated_with: :account
  end
end
